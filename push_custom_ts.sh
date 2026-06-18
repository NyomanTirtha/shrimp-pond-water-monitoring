#!/bin/bash
PROJECT="monitoring-air-tambak-udang"

NOW=$(node -e 'console.log(Date.now())')
MINUS_30=$(node -e "console.log($NOW - 30 * 60 * 1000)")

echo "1. Peringatan Dini Suhu (30 menit) - Timestamp 30 mins ago"
npx firebase-tools database:remove /notification_state/forecast_alerts -f --project $PROJECT > /dev/null 2>&1
cat <<EOF > /tmp/hist1.json
{
  "t1": { "ts": 1000, "temp": 29.0, "pH": 8.0, "turb": 50.0 },
  "t2": { "ts": 2000, "temp": 31.0, "pH": 8.0, "turb": 50.0 }
}
EOF
npx firebase-tools database:set /smart_buoy/history /tmp/hist1.json -f --project $PROJECT > /dev/null 2>&1
npx firebase-tools database:set /smart_buoy/live -d "{\"temp\":28.0,\"pH\":8.0,\"turb\":50.0,\"tsOverride\":$MINUS_30}" -f --project $PROJECT
sleep 7

echo "2. Peringatan Dini pH (30 menit) - Timestamp 30 mins ago"
npx firebase-tools database:remove /notification_state/forecast_alerts -f --project $PROJECT > /dev/null 2>&1
cat <<EOF > /tmp/hist2.json
{
  "t1": { "ts": 1000, "temp": 28.0, "pH": 7.8, "turb": 50.0 },
  "t2": { "ts": 2000, "temp": 28.0, "pH": 8.2, "turb": 50.0 }
}
EOF
npx firebase-tools database:set /smart_buoy/history /tmp/hist2.json -f --project $PROJECT > /dev/null 2>&1
npx firebase-tools database:set /smart_buoy/live -d "{\"temp\":28.0,\"pH\":8.0,\"turb\":50.0,\"tsOverride\":$MINUS_30}" -f --project $PROJECT
sleep 7

echo "3. Peringatan Dini Suhu (1 jam) - Timestamp NOW"
npx firebase-tools database:remove /notification_state/forecast_alerts -f --project $PROJECT > /dev/null 2>&1
cat <<EOF > /tmp/hist3.json
{
  "t1": { "ts": 1000, "temp": 30.0, "pH": 8.0, "turb": 50.0 },
  "t2": { "ts": 2000, "temp": 30.5, "pH": 8.0, "turb": 50.0 }
}
EOF
npx firebase-tools database:set /smart_buoy/history /tmp/hist3.json -f --project $PROJECT > /dev/null 2>&1
npx firebase-tools database:set /smart_buoy/live -d "{\"temp\":28.0,\"pH\":8.0,\"turb\":50.0,\"tsOverride\":$NOW}" -f --project $PROJECT
sleep 7

echo "4. Peringatan Dini pH (1 jam) - Timestamp NOW"
npx firebase-tools database:remove /notification_state/forecast_alerts -f --project $PROJECT > /dev/null 2>&1
cat <<EOF > /tmp/hist4.json
{
  "t1": { "ts": 1000, "temp": 28.0, "pH": 8.1, "turb": 50.0 },
  "t2": { "ts": 2000, "temp": 28.0, "pH": 8.2, "turb": 50.0 }
}
EOF
npx firebase-tools database:set /smart_buoy/history /tmp/hist4.json -f --project $PROJECT > /dev/null 2>&1
npx firebase-tools database:set /smart_buoy/live -d "{\"temp\":28.0,\"pH\":8.0,\"turb\":50.0,\"tsOverride\":$NOW}" -f --project $PROJECT
sleep 7

echo "Restoring state..."
npx firebase-tools database:remove /smart_buoy/history -f --project $PROJECT > /dev/null 2>&1
npx firebase-tools database:set /smart_buoy/live -d '{"temp":28.0,"pH":8.0,"turb":50.0}' -f --project $PROJECT

echo "Done pushing custom timestamp notifications."
