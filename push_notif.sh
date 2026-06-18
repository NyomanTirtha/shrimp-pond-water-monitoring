#!/bin/bash
PROJECT="monitoring-air-tambak-udang"

echo "1. Trigger High Temp"
npx firebase-tools database:remove /notification_state/live_alerts -f --project $PROJECT > /dev/null 2>&1
npx firebase-tools database:set /smart_buoy/live -d '{"temp":35.0,"pH":8.0,"turb":50.0}' -f --project $PROJECT
sleep 5

echo "2. Trigger High pH"
npx firebase-tools database:remove /notification_state/live_alerts -f --project $PROJECT > /dev/null 2>&1
npx firebase-tools database:set /smart_buoy/live -d '{"temp":28.0,"pH":9.5,"turb":50.0}' -f --project $PROJECT
sleep 5

echo "3. Trigger Low Temp"
npx firebase-tools database:remove /notification_state/live_alerts -f --project $PROJECT > /dev/null 2>&1
npx firebase-tools database:set /smart_buoy/live -d '{"temp":20.0,"pH":8.0,"turb":50.0}' -f --project $PROJECT
sleep 5

echo "4. Trigger Low pH"
npx firebase-tools database:remove /notification_state/live_alerts -f --project $PROJECT > /dev/null 2>&1
npx firebase-tools database:set /smart_buoy/live -d '{"temp":28.0,"pH":6.5,"turb":50.0}' -f --project $PROJECT
sleep 5

echo "Restoring safe state..."
npx firebase-tools database:remove /notification_state/live_alerts -f --project $PROJECT > /dev/null 2>&1
npx firebase-tools database:set /smart_buoy/live -d '{"temp":28.0,"pH":8.0,"turb":50.0}' -f --project $PROJECT

echo "Done pushing 4 notifications."
