#!/bin/bash

set -e

cd "$(git rev-parse --show-toplevel)"

PGPASSWORD="$(sops -d terraform/secrets.enc.yaml | yq e '.homeAssistant.postgresql.password')"
PGUSER="$(sops -d terraform/secrets.enc.yaml | yq e '.homeAssistant.postgresql.username')"
PGDATABASE="$(sops -d terraform/secrets.enc.yaml | yq e '.homeAssistant.postgresql.database')"

cd backup/$1

kubectl cp -n home-assistant postgresql/dump.sql home-assistant-postgresql-0:/tmp/dump.sql
kubectl exec -n home-assistant home-assistant-postgresql-0 -- sh -c "PGPASSWORD=$PGPASSWORD PGUSER=$PGUSER PGDATABASE=$PGDATABASE psql < /tmp/dump.sql"
kubectl exec -n home-assistant home-assistant-postgresql-0 -- rm /tmp/dump.sql
kubectl rollout restart statefulset -n home-assistant home-assistant-postgresql

kubectl exec -n home-assistant home-assistant-zigbee2mqtt-0 -c copy-conf -- rm -rf /app/data/*
kubectl cp -n home-assistant -c copy-conf zigbee2mqtt/app/data home-assistant-zigbee2mqtt-0:/app/
kubectl rollout restart statefulset -n home-assistant home-assistant-zigbee2mqtt

kubectl exec -n home-assistant home-assistant-0 -- rm -rf /config/.storage/*
kubectl cp -n home-assistant home-assistant/.storage home-assistant-0:/config/
kubectl rollout restart statefulset -n home-assistant home-assistant
