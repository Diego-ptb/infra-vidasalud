# Cluster RabbitMQ de VidaSalud

Dos nodos (`rabbit1` y `rabbit2`) definidos en [`../apps/compose.yml`](../apps/compose.yml),
junto al resto del sistema. Un solo `docker compose up -d` levanta broker y
microservicios.

## Archivos

| Archivo | Para qué |
|---|---|
| `rabbitmq.conf` | Le dice al broker que cargue `definitions.json` al arrancar |
| `definitions.json` | Usuario `admin`, permisos y la política de alta disponibilidad |
| `unir-cluster.sh` | Une `rabbit2` al clúster de `rabbit1` |

## Por qué las colas no están en definitions.json

La topología (colas, exchanges, bindings) la declaran los microservicios como
beans `@Bean Queue` / `@Bean Exchange` / `@Bean Binding`. Spring AMQP las crea
al conectarse, y la operación es idempotente: el primer servicio que arranca
las crea, el resto las encuentra hechas.

Definirlas también aquí sería duplicar la verdad. Peor: si un solo argumento no
coincidiera (un `x-dead-letter-routing-key`, por ejemplo), RabbitMQ responde
`PRECONDITION_FAILED` y el microservicio no arranca. Quien manda sobre la
topología es el código; este archivo solo prepara el broker para recibirla.

## Levantar el clúster

```bash
cd infra/apps
docker compose up -d
./../mq/unir-cluster.sh
```

El script espera a que `rabbit1` esté listo, une `rabbit2` y muestra el estado.
Hay que ejecutarlo una sola vez: el clúster queda guardado en el volumen de
cada nodo y sobrevive a los reinicios.

## Comprobar que está formado

```bash
docker exec rabbit1 rabbitmqctl cluster_status
```

Tienen que aparecer los dos nodos en `Running Nodes`.

## Consolas web

| Nodo | URL | Usuario |
|---|---|---|
| rabbit1 | http://localhost:15672 | admin / admin |
| rabbit2 | http://localhost:15673 | admin / admin |

En la nube, cambia `localhost` por la IP pública de la EC2. Abre esos puertos
en el Security Group **solo** mientras dure la demostración: la consola de
administración no debería quedar expuesta a internet.

## Las tres colas y sus DLQ

| Cola | Exchange | Routing key | Consumidor |
|---|---|---|---|
| `q.notificaciones.email` | `vidasalud.atenciones.topic` (topic) | `atencion.confirmada`, `atencion.cancelada` | ms-vidasalud-notifications |
| `q.admision.ticket` | `vidasalud.atenciones.topic` (topic) | `atencion.#` | ms-vidasalud-appointments |
| `q.catalogo.cupo` | `vidasalud.comandos.direct` (direct) | `cupo.tomar` | ms-vidasalud-catalog |

Cada una tiene su DLQ con el mismo nombre más `.dlq`, ligada a
`vidasalud.dlx`.
