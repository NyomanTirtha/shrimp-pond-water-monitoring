const admin = require("firebase-admin");
const functions = require("firebase-functions");

admin.initializeApp();

const db = admin.database();
const COOL_DOWN_MS = 5 * 60 * 1000;
const THRESHOLDS = {
  temp: { min: 26.0, max: 32.0, decimals: 1, label: "Suhu", unit: "°C" },
  pH: { min: 7.5, max: 8.5, decimals: 2, label: "pH", unit: "" },
  turb: { min: 30.0, max: 100.0, decimals: 1, label: "Kekeruhan", unit: " NTU" },
};

exports.onSmartBuoyLiveUpdate = functions.database
  .ref("/smart_buoy/live")
  .onWrite(async (change) => {
    const data = change.after.val();
    if (!data) {
      console.log("[EWS] Skip: /smart_buoy/live is empty");
      return;
    }

    console.log("[EWS] Live update received", {
      temp: data.temp,
      pH: data.pH,
      turb: data.turb,
    });

    const now = Date.now();
    await maybeSendLiveAlerts(data, now);
    await maybeSendForecastAlerts(now);
  });

async function maybeSendLiveAlerts(data, now) {
  await maybeSend(
    "live_temperature",
    data.temp,
    THRESHOLDS.temp,
    now,
    (value, t) => ({
      title: "Bahaya: Suhu Air Tidak Aman",
      body: `Suhu saat ini ${value.toFixed(t.decimals)}${t.unit}, di luar batas aman 26-32°C.`,
      type: "danger",
    })
  );

  await maybeSend(
    "live_ph",
    data.pH,
    THRESHOLDS.pH,
    now,
    (value, t) => ({
      title: "Bahaya: pH Air Tidak Aman",
      body: `pH saat ini ${value.toFixed(t.decimals)}, di luar batas aman 7.5-8.5.`,
      type: "danger",
    })
  );

  await maybeSend(
    "live_turbidity",
    data.turb,
    THRESHOLDS.turb,
    now,
    (value, t) => ({
      title: "Bahaya: Kekeruhan Tinggi",
      body: `Kekeruhan saat ini ${value.toFixed(t.decimals)}${t.unit}, melebihi batas aman 30 NTU.`,
      type: "danger",
    })
  );
}

async function maybeSendForecastAlerts(now) {
  const historySnap = await db.ref("/smart_buoy/history").limitToLast(24).get();
  const history = historySnap.val() || {};
  const readings = Object.values(history)
    .filter((v) => v && v.ts)
    .sort((a, b) => a.ts - b.ts);
  if (readings.length < 2) return;

  await maybeSendForecast("forecast_temperature", readings.map((r) => Number(r.temp)), THRESHOLDS.temp, now);
  await maybeSendForecast("forecast_ph", readings.map((r) => Number(r.pH)), THRESHOLDS.pH, now);
  await maybeSendForecast("forecast_turbidity", readings.map((r) => Number(r.turb)), THRESHOLDS.turb, now);
}

async function maybeSendForecast(key, series, threshold, now) {
  const forecast = desForecast(series, 0.5, 0.5, 6);
  for (let i = 0; i < forecast.length; i += 1) {
    const value = forecast[i];
    if (value >= threshold.min && value <= threshold.max) continue;
    const direction = value < threshold.min ? "turun ke" : "menyentuh";
    const minutes = (i + 1) * 10;
    const body = `Peringatan Dini: ${threshold.label} diprediksi akan ${direction} ${value.toFixed(threshold.decimals)}${threshold.unit} dalam ${minutes} menit ke depan!`;
    await sendWithCooldown(key, now, "Peringatan Dini: " + threshold.label, body, "warning");
    return;
  }
}

async function maybeSend(key, rawValue, threshold, now, builder) {
  const value = Number(rawValue);
  if (!Number.isFinite(value)) {
    console.log("[EWS] Skip invalid value", { key, rawValue });
    return;
  }
  if (value >= threshold.min && value <= threshold.max) {
    console.log("[EWS] Safe range, no alert", {
      key,
      value,
      min: threshold.min,
      max: threshold.max,
    });
    return;
  }

  console.log("[EWS] Danger detected", {
    key,
    value,
    min: threshold.min,
    max: threshold.max,
  });

  const msg = builder(value, threshold);
  await sendWithCooldown(key, now, msg.title, msg.body, msg.type);
}

async function sendWithCooldown(key, now, title, body, type) {
  const stateRef = db.ref(`/notification_state/${key}`);
  const snapshot = await stateRef.get();
  const lastSentAt = snapshot.child("lastSentAt").val() || 0;
  if (now - lastSentAt < COOL_DOWN_MS) {
    console.log("[EWS] Cooldown active, skip send", {
      key,
      remainingMs: COOL_DOWN_MS - (now - lastSentAt),
    });
    return;
  }

  const tokensSnap = await db.ref("/devices").get();
  const tokensRaw = tokensSnap.val() || {};
  const tokens = Object.values(tokensRaw)
    .map((d) => d && d.fcmToken)
    .filter((t) => typeof t === "string" && t.length > 0);
  if (tokens.length === 0) {
    console.log("[EWS] No registered device tokens, skip send", { key });
    return;
  }

  console.log("[EWS] Sending notification", {
    key,
    type,
    tokenCount: tokens.length,
    title,
  });

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: {
      type,
      key,
      timestamp: String(now),
    },
    android: { priority: "high" },
  });

  console.log("[EWS] Send result", {
    key,
    successCount: response.successCount,
    failureCount: response.failureCount,
  });

  if (response.failureCount > 0) {
    const errors = response.responses
      .filter((r) => !r.success)
      .map((r) => (r.error ? r.error.message : "Unknown FCM error"));
    console.log("[EWS] Failed token responses", { key, errors });
  }

  await stateRef.set({ lastSentAt: now });
}

function desForecast(values, alpha, beta, periods) {
  let level = values[0];
  let trend = values[1] - values[0];
  for (let i = 1; i < values.length; i += 1) {
    const value = values[i];
    const prevLevel = level;
    level = alpha * value + (1 - alpha) * (level + trend);
    trend = beta * (level - prevLevel) + (1 - beta) * trend;
  }
  return Array.from({ length: periods }, (_, i) => level + (i + 1) * trend);
}
