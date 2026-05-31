const admin = require("firebase-admin");
// firebase-functions v7: API 1st gen (functions.database.ref) ada di subpath /v1.
const functions = require("firebase-functions/v1");

admin.initializeApp();

const db = admin.database();
const COOL_DOWN_MS = 5 * 60 * 1000;
const THRESHOLDS = {
  temp: { min: 26.0, max: 32.0, decimals: 1, label: "Suhu", unit: "°C" },
  pH: { min: 7.5, max: 8.5, decimals: 2, label: "pH", unit: "" },
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
    });

    const now = Date.now();
    await maybeSendLiveAlerts(data, now);
    await maybeSendForecastAlerts(now);
  });

// ── Live: kumpulkan semua parameter bahaya → kirim 1 notif gabungan ──
async function maybeSendLiveAlerts(data, now) {
  const checks = [
    {
      value: data.temp,
      threshold: THRESHOLDS.temp,
      title: "Bahaya: Suhu Air Tidak Aman",
      body: (v, t) =>
        `Suhu saat ini ${v.toFixed(t.decimals)}${t.unit}, di luar batas aman 26-32°C.`,
    },
    {
      value: data.pH,
      threshold: THRESHOLDS.pH,
      title: "Bahaya: pH Air Tidak Aman",
      body: (v, t) =>
        `pH saat ini ${v.toFixed(t.decimals)}, di luar batas aman 7.5-8.5.`,
    },
  ];

  const breaches = [];
  for (const check of checks) {
    const value = Number(check.value);
    if (!Number.isFinite(value)) {
      console.log("[EWS] Skip invalid value", {
        label: check.threshold.label,
        rawValue: check.value,
      });
      continue;
    }
    if (value >= check.threshold.min && value <= check.threshold.max) continue;
    breaches.push({
      label: check.threshold.label,
      title: check.title,
      body: check.body(value, check.threshold),
    });
  }

  if (breaches.length === 0) {
    console.log("[EWS] Live: all parameters in safe range");
    return;
  }

  console.log("[EWS] Live danger detected", {
    params: breaches.map((b) => b.label),
  });

  const title =
    breaches.length === 1
      ? breaches[0].title
      : "Bahaya: Kualitas Air Tidak Aman";
  const body = breaches.map((b) => b.body).join("\n");
  const labels = breaches.map((b) => b.label);

  await sendWithCooldown("live_alerts", now, title, body, "danger", labels);
}

// ── Forecast: kumpulkan semua prediksi keluar batas → 1 notif gabungan ──
async function maybeSendForecastAlerts(now) {
  const historySnap = await db.ref("/smart_buoy/history").limitToLast(24).get();
  const history = historySnap.val() || {};
  const readings = Object.values(history)
    .filter((v) => v && v.ts)
    .sort((a, b) => a.ts - b.ts);
  if (readings.length < 2) return;

  const series = {
    temp: readings.map((r) => Number(r.temp)),
    pH: readings.map((r) => Number(r.pH)),
  };

  const breaches = [];
  for (const param of ["temp", "pH"]) {
    const breach = forecastBreach(series[param], THRESHOLDS[param]);
    if (breach) breaches.push(breach);
  }

  if (breaches.length === 0) {
    console.log("[EWS] Forecast: all parameters predicted safe");
    return;
  }

  console.log("[EWS] Forecast breach detected", {
    params: breaches.map((b) => b.label),
  });

  const title =
    breaches.length === 1
      ? `Peringatan Dini: ${breaches[0].label}`
      : "Peringatan Dini: Kualitas Air";
  const body = breaches.map((b) => b.body).join("\n");
  const labels = breaches.map((b) => b.label);

  await sendWithCooldown("forecast_alerts", now, title, body, "warning", labels);
}

// Kembalikan detail breach pertama dari hasil forecast, atau null jika aman.
function forecastBreach(series, threshold) {
  const forecast = desForecast(series, 0.5, 0.5, 6);
  for (let i = 0; i < forecast.length; i += 1) {
    const value = forecast[i];
    if (value >= threshold.min && value <= threshold.max) continue;
    const direction = value < threshold.min ? "turun ke" : "menyentuh";
    const minutes = (i + 1) * 10;
    return {
      label: threshold.label,
      body: `${threshold.label} diprediksi akan ${direction} ${value.toFixed(threshold.decimals)}${threshold.unit} dalam ${minutes} menit ke depan!`,
    };
  }
  return null;
}

async function sendWithCooldown(key, now, title, body, type, labels) {
  // Signature = kumpulan parameter yang bermasalah, agar perubahan kondisi
  // (mis. pH ikut bahaya) tetap memicu notif baru walau cooldown aktif.
  const signature = labels.slice().sort().join(",");
  const stateRef = db.ref(`/notification_state/${key}`);
  const snapshot = await stateRef.get();
  const lastSentAt = snapshot.child("lastSentAt").val() || 0;
  const lastSignature = snapshot.child("signature").val() || "";

  const cooldownActive = now - lastSentAt < COOL_DOWN_MS;
  if (cooldownActive && signature === lastSignature) {
    console.log("[EWS] Cooldown active, skip send", {
      key,
      remainingMs: COOL_DOWN_MS - (now - lastSentAt),
    });
    return;
  }
  if (cooldownActive && signature !== lastSignature) {
    console.log("[EWS] Cooldown active but breach set changed, sending", {
      key,
      lastSignature,
      signature,
    });
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

  await stateRef.set({ lastSentAt: now, signature });
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
