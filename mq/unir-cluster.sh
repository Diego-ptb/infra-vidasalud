#!/usr/bin/env bash
#
# Une rabbit2 al cluster de rabbit1.
#
# Uso:  ./unir-cluster.sh
#
# Se ejecuta una sola vez, despues del primer "docker compose up -d". El
# cluster queda guardado en el volumen de cada nodo, asi que sobrevive a los
# reinicios y no hay que repetirlo.
#
# Se hace con un script y no dentro del compose a proposito: unirse a un
# cluster exige que el otro nodo ya este arrancado, y un "depends_on" garantiza
# el orden de arranque del contenedor, no que Erlang este listo para aceptar
# una conexion.

set -euo pipefail

NODO1="${NODO1:-rabbit1}"
NODO2="${NODO2:-rabbit2}"

echo "Esperando a que $NODO1 este listo..."
for intento in $(seq 1 30); do
    if docker exec "$NODO1" rabbitmq-diagnostics -q ping >/dev/null 2>&1; then
        echo "  $NODO1 responde."
        break
    fi
    if [ "$intento" -eq 30 ]; then
        echo "ERROR: $NODO1 no respondio tras 30 intentos." >&2
        exit 1
    fi
    sleep 2
done

echo "Esperando a que $NODO2 este listo..."
for intento in $(seq 1 30); do
    if docker exec "$NODO2" rabbitmq-diagnostics -q ping >/dev/null 2>&1; then
        echo "  $NODO2 responde."
        break
    fi
    if [ "$intento" -eq 30 ]; then
        echo "ERROR: $NODO2 no respondio tras 30 intentos." >&2
        exit 1
    fi
    sleep 2
done

# Si rabbit2 ya es parte del cluster no hay nada que hacer: volver a unirlo
# borraria su estado con "reset".
if docker exec "$NODO1" rabbitmqctl cluster_status | grep -q "rabbit@$NODO2"; then
    echo
    echo "$NODO2 ya es parte del cluster. No se toca nada."
else
    echo
    echo "Uniendo $NODO2 al cluster de $NODO1..."
    docker exec "$NODO2" rabbitmqctl stop_app
    docker exec "$NODO2" rabbitmqctl reset
    docker exec "$NODO2" rabbitmqctl join_cluster "rabbit@$NODO1"
    docker exec "$NODO2" rabbitmqctl start_app
    docker exec "$NODO2" rabbitmqctl await_startup
    echo "Listo."
fi

echo
echo "===================== Estado del cluster ====================="
docker exec "$NODO1" rabbitmqctl cluster_status
