# infra-vidasalud

Infraestructura como código del caso **VidaSalud** · DSY1107 Desarrollo Cloud Native I.

No contiene código de aplicación: solo los archivos que describen cómo se despliega el
sistema.

```
infra/
├─ apps/     → compose del stack completo: RabbitMQ en clúster + BFF + microservicios
├─ mq/       → configuración del broker (definiciones, política HA, script de clúster)
└─ kafka/    → alternativa de mensajería, no usada en esta entrega
```

## apps/ — el stack completo

Un solo `docker compose up -d --build` levanta siete contenedores en una red privada:

| Servicio | Puerto | Expuesto al exterior | Rol |
|---|---|---|---|
| `rabbit1` | 5672 / 15672 | Solo para la demo | Nodo 1 del clúster |
| `rabbit2` | 5673 / 15673 | Solo para la demo | Nodo 2 del clúster |
| `bff` | 8080 | **Sí**, único punto de entrada | Valida el JWT y enruta |
| `appointments` | 8081 | No | Atenciones + consumidor de `q.admision.ticket` |
| `catalog` | 8082 | No | Prestaciones + consumidor de `q.catalogo.cupo` |
| `notifications` | 8091 | No | Consumidor de `q.notificaciones.email` |
| `rabbit-admin` | 8090 | No | API REST de administración del broker |

Que los microservicios no publiquen puerto es intencional: obliga a que todo el tráfico
pase por el BFF, que es quien valida el JWT. Además exigen la cabecera
`X-Internal-Key`, así que tampoco sirve alcanzarlos desde dentro de la red sin la clave.

### Uso

Los repositorios de código se clonan aparte:

```bash
git clone https://github.com/Diego-ptb/ms-vidasalud-bff.git
git clone https://github.com/Diego-ptb/ms-vidasalud-appointments.git
git clone https://github.com/Diego-ptb/ms-vidasalud-catalog.git
git clone https://github.com/Diego-ptb/ms-vidasalud-notifications.git
git clone https://github.com/Diego-ptb/ms-vidasalud-rabbit-admin.git
git clone https://github.com/Diego-ptb/infra-vidasalud.git
```

Luego:

```bash
cd infra-vidasalud/apps
cp .env.example .env
nano .env                    # completa credenciales y REPOS_PATH
docker compose up -d --build
../mq/unir-cluster.sh        # una sola vez: une rabbit2 al clúster
```

`REPOS_PATH` indica dónde están los repos de código:

| Dónde | Valor |
|---|---|
| Tu PC, con los repos hermanos de `infra/` | déjalo sin definir (usa `../..`) |
| EC2, con los repos en el home | `REPOS_PATH=/home/ec2-user` |

### Memoria

Siete contenedores, cinco de ellos JVM, no caben en una `t2.micro` de 1 GB. Usa al
menos **t3.small (2 GB)**; con 4 GB (`t3.medium`) va holgado. Si la instancia es
pequeña, limita cada JVM añadiendo al servicio:

```yaml
    environment:
      JAVA_TOOL_OPTIONS: -XX:MaxRAMPercentage=50
```

### Verificar

```bash
docker compose ps
curl http://localhost:8080/actuator/health          # {"status":"UP"}
curl -o /dev/null -w "%{http_code}\n" \
     http://localhost:8080/api/me                   # 401, sin token
docker exec rabbit1 rabbitmqctl cluster_status      # dos nodos en Running Nodes
```

## mq/ — configuración del broker

Los nodos se definen en `apps/compose.yml`; esta carpeta tiene lo que montan:

| Archivo | Para qué |
|---|---|
| `rabbitmq.conf` | Carga `definitions.json` al arrancar |
| `definitions.json` | Usuario `admin`, permisos y la política de alta disponibilidad |
| `unir-cluster.sh` | Une `rabbit2` al clúster de `rabbit1` |
| `LEEME.md` | Topología de colas y cómo comprobar el clúster |

Las colas, exchanges y bindings **no** están en `definitions.json`: los declaran los
microservicios como beans de Spring AMQP. El detalle del por qué está en
[`mq/LEEME.md`](mq/LEEME.md).

## kafka/ — no se usa

Quedó de una exploración previa. La mensajería del sistema es RabbitMQ; esta carpeta no
la levanta ningún compose y ningún servicio se conecta a ella.

## Credenciales

Nunca se versionan. `apps/.env` está ignorado por git; `apps/.env.example` es la
plantilla con placeholders.

## Despliegue en AWS

El paso a paso completo —EC2, Security Groups, API Gateway con JWT Authorizer y CORS—
está en la guía `docs/DESPLIEGUE-AWS.md` del workspace.
