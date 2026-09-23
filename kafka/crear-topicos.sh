#!/usr/bin/env bash
# Crea los topicos de la topologia del caso VidaSalud.
set -e
B=kafka1:29092

docker exec kafka1 kafka-topics --bootstrap-server $B --create --if-not-exists \
  --topic appointments.events --partitions 3 --replication-factor 3 \
  --config cleanup.policy=delete --config retention.ms=604800000

docker exec kafka1 kafka-topics --bootstrap-server $B --create --if-not-exists \
  --topic audit.timeline --partitions 3 --replication-factor 3 \
  --config cleanup.policy=compact,delete --config retention.ms=2592000000

docker exec kafka1 kafka-topics --bootstrap-server $B --create --if-not-exists \
  --topic appointments.events.DLT --partitions 3 --replication-factor 3 \
  --config cleanup.policy=delete --config retention.ms=1209600000

docker exec kafka1 kafka-topics --bootstrap-server $B --list
