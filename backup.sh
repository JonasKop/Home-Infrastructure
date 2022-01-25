#!/bin/bash

set -e


PGPASSWORD="$(sops -d secrets.enc.yaml | yq eval-all '. as $item ireduce ({}; . * $item )' values.yaml - | yq e '.homeAssistant.postgresql.password')"
PGUSER="$(sops -d secrets.enc.yaml | yq eval-all '. as $item ireduce ({}; . * $item )' values.yaml - | yq e '.homeAssistant.postgresql.username')"
PGDATABASE="$(sops -d secrets.enc.yaml | yq eval-all '. as $item ireduce ({}; . * $item )' values.yaml - | yq e '.homeAssistant.postgresql.database')"
time=$(date -u +"%Y-%m-%d_%H:%M:%S")

mkdir -p backup/$time
cd backup/$time

mkdir -p home-assistant zigbee2mqtt postgresql

kubectl cp -n home-assistant home-assistant-0:/config/.storage home-assistant/.storage
kubectl cp -n home-assistant home-assistant-zigbee2mqtt-0:/app/data zigbee2mqtt/app/data

kubectl exec -n home-assistant home-assistant-postgresql-0 -- sh -c "PGPASSWORD=$PGPASSWORD PGUSER=$PGUSER PGDATABASE=$PGDATABASE pg_dump > /tmp/dump.sql"
kubectl cp -n home-assistant home-assistant-postgresql-0:/tmp/dump.sql postgresql/dump.sql
kubectl exec -n home-assistant home-assistant-postgresql-0 -- rm /tmp/dump.sql
