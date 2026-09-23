# infra-vidasalud

Infraestructura como código del caso **VidaSalud** · DSY1107 Desarrollo Cloud Native I.

No contiene código de aplicación: solo los archivos que describen cómo se despliega cada
grupo de servicios. Sigue la sección 7 del caso, que pide un `compose.yml` por cada
instancia EC2.

```
infra/
├─ apps/     → ec2-apps   · BFF + microservicios de dominio
├─ mq/       → ec2-mq     · RabbitMQ en clúster
└─ kafka/    → ec2-kafka  · Zookeeper + Kafka + Kafka UI
```

## apps/ — el stack de aplicación

Levanta tres contenedores en una red privada de Docker:

| Servicio | Puerto | Expuesto al exterior |
|---|---|---|
| `bff` | 8080 | **Sí**, es el único punto de entrada |
| `appointments` | 8081 | No |
| `catalog` | 8082 | No |

Que appointments y catalog no publiquen puerto es intencional: obliga a que todo el
tráfico pase por el BFF, que es quien valida el JWT. Además exigen la cabecera
`X-Internal-Key`, así que tampoco sirve alcanzarlos desde dentro de la red sin la clave.

### Uso

Los repositorios de código se clonan aparte:

```bash
git clone https://github.com/Diego-ptb/ms-vidasalud-bff.git
git clone https://github.com/Diego-ptb/ms-vidasalud-appointments.git
git clone https://github.com/Diego-ptb/ms-vidasalud-catalog.git
git clone https://github.com/Diego-ptb/infra-vidasalud.git
```

Luego:

```bash
cd infra-vidasalud/apps
cp .env.example .env
nano .env                  # completa credenciales y REPOS_PATH
docker compose up -d --build
```

`REPOS_PATH` indica dónde están los repos de código:

| Dónde | Valor |
|---|---|
| Tu PC, con los repos hermanos de `infra/` | déjalo sin definir (usa `../..`) |
| EC2, con los repos en el home | `REPOS_PATH=/home/ec2-user` |

### Verificar

```bash
docker compose ps
curl http://localhost:8080/actuator/health          # {"status":"UP"}
curl -o /dev/null -w "%{http_code}\n" \
     http://localhost:8080/api/me                   # 401, sin token
```

## mq/ — RabbitMQ

Clúster de 2 nodos con Management UI en el puerto 15672. `definitions.json` carga la
topología del caso al arrancar: 3 colas de trabajo (`q.cmd.email`, `q.cmd.admission`,
`q.cmd.record`), sus 3 DLQ, y los exchanges `cmd.direct`, `cmd.topic` y `cmd.dead.dlx`.

Para unir el segundo nodo al clúster, tras levantar:

```bash
docker exec rabbit2 rabbitmqctl stop_app
docker exec rabbit2 rabbitmqctl join_cluster rabbit@rabbit1
docker exec rabbit2 rabbitmqctl start_app
```

## kafka/ — Kafka

3 Zookeeper + 3 brokers + Kafka UI en el puerto 8090. Tras levantar:

```bash
./crear-topicos.sh
```

Crea `appointments.events` y `audit.timeline` con las particiones, réplicas y políticas de
retención que especifica el caso, más el tópico `.DLT` para mensajes fallidos.

> `mq/` y `kafka/` quedan listos para la siguiente etapa del caso. En la EP1 ningún
> servicio los consume todavía.

## Credenciales

Nunca se versionan. Cada carpeta usa un `.env` ignorado por git; `apps/.env.example` es la
plantilla con placeholders.

## Despliegue en AWS

El paso a paso completo —EC2, Security Groups, API Gateway con JWT Authorizer y CORS— está
en la guía `docs/DESPLIEGUE-AWS.md` del workspace.
