#!/bin/bash
PROJECT="monitoring-air-tambak-udang"

echo "1. Peringatan Dini Suhu (30 menit)"
npx firebase-tools database:remove /notification_state/forecast_alerts -f --project $PROJECT > /dev/null 2>&1
# v0=29.0, v1=31.0 -> trend=2.0. 30m = 31+3*2=37 (Danger)
cat <<EOF > /tmp/hist1.json
{
  "t1": { "ts": 1000, "temp": 29.0, "pH": 8.0, "turb": 50.0 },
  "t2": { "ts": 2000, "temp": 31.0, "pH": 8.0, "turb": 50.0 }
}
EOF
npx firebase-tools database:set /smart_buoy/history /tmp/hist1.json -f --project $PROJECT > /dev/null 2>&1
# Trigger cloud function
npx firebase-tools database:set /smart_buoy/live -d '{"temp":28.0,"pH":8.0,"turb":50.0}' -f --project $PROJECT
sleep 7

echo "2. Peringatan Dini pH (30 menit)"
npx firebase-tools database:remove /notification_state/forecast_alerts -f --project $PROJECT > /dev/null 2>&1
# v0=7.8, v1=8.2 -> trend=0.4. 30m = 8.2+3*0.4=9.4 (Danger)
cat <<EOF > /tmp/hist2.json
{
  "t1": { "ts": 1000, "temp": 28.0, "pH": 7.8, "turb": 50.0 },
  "t2": { "ts": 2000, "temp": 28.0, "pH": 8.2, "turb": 50.0 }
}
EOF
npx firebase-tools database:set /smart_buoy/history /tmp/hist2.json -f --project $PROJECT > /dev/null 2>&1
npx firebase-tools database:set /smart_buoy/live -d '{"temp":28.0,"pH":8.0,"turb":50.0}' -f --project $PROJECT
sleep 7

echo "3. Peringatan Dini Suhu (1 jam)"
npx firebase-tools database:remove /notification_state/forecast_alerts -f --project $PROJECT > /dev/null 2>&1
# v0=30.0, v1=30.5 -> trend=0.5. 30m = 32.0 (Safe). 60m = 33.5 (Danger)
cat <<EOF > /tmp/hist3.json
{
  "t1": { "ts": 1000, "temp": 30.0, "pH": 8.0, "turb": 50.0 },
  "t2": { "ts": 2000, "temp": 30.5, "pH": 8.0, "turb": 50.0 }
}
EOF
npx firebase-tools database:set /smart_buoy/history /tmp/hist3.json -f --project $PROJECT > /dev/null 2>&1
npx firebase-tools database:set /smart_buoy/live -d '{"temp":28.0,"pH":8.0,"turb":50.0}' -f --project $PROJECT
sleep 7

echo "4. Peringatan Dini pH (1 jam)"
npx firebase-tools database:remove /notification_state/forecast_alerts -f --project $PROJECT > /dev/null 2>&1
# v0=8.1, v1=8.2 -> trend=0.1. 30m = 8.5 (Safe). 60m = 8.8 (Danger)
cat <<EOF > /tmp/hist4.json
{
  "t1": { "ts": 1000, "temp": 28.0, "pH": 8.1, "turb": 50.0 },
  "t2": { "ts": 2000, "temp": 28.0, "pH": 8.2, "turb": 50.0 }
}
EOF
npx firebase-tools database:set /smart_buoy/history /tmp/hist4.json -f --project $PROJECT > /dev/null 2>&1
npx firebase-tools database:set /smart_buoy/live -d '{"temp":28.0,"pH":8.0,"turb":50.0}' -f --project $PROJECT
sleep 7

echo "Restoring state..."
npx firebase-tools database:remove /smart_buoy/history -f --project $PROJECT > /dev/null 2>&1
npx firebase-tools database:set /smart_buoy/live -d '{"temp":28.0,"pH":8.0,"turb":50.0}' -f --project $PROJECT

echo "Done pushing forecast notifications."
