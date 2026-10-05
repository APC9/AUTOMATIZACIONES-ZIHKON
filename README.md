Para activar el Queue Mode (Modo Cola) de n8n en Docker Compose, necesitas pasar de una arquitectura de un solo contenedor a una arquitectura distribuida con 3 componentes principales:

Redis: Funciona como el gestor de la cola de tareas.

n8n Main (Editor/Webhook): Procesa los webhooks, guarda las ejecuciones en la base de datos Postgres y delega los trabajos pesados a Redis.

n8n Worker(s): Contenedores secundarios que leen los trabajos de Redis y los ejecutan en segundo plano.

Ejemplo de docker-compose.yml en Queue Mode
Puedes adaptar tu archivo docker-compose.yml utilizando esta estructura base:

YAML
version: '3.8'

services:
  # 1. Base de datos Postgres (existente)
  postgres:
    image: postgres:16-alpine
    restart: always
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-n8n}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-n8n_password}
      POSTGRES_DB: ${POSTGRES_DB:-n8n}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-n8n}"]
      interval: 5s
      timeout: 5s
      retries: 5

  # 2. Redis para la cola de tareas
  redis:
    image: redis:7-alpine
    restart: always
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5

  # 3. Instancia Principal de n8n (Editor / Webhook Principal)
  n8n-main:
    image: docker.n8n.io/n8nio/n8n:latest
    restart: always
    ports:
      - "5678:5678"
    environment:
      - EXECUTIONS_MODE=queue
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB:-n8n}
      - DB_POSTGRESDB_USER=${POSTGRES_USER:-n8n}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD:-n8n_password}
      - QUEUE_BULL_REDIS_HOST=redis
      - QUEUE_BULL_REDIS_PORT=6379
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY:-tu_clave_secreta_aqui}
      - N8N_HOST=tu-dominio.com
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://tu-dominio.com/
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    volumes:
      - n8n_data:/home/node/.n8n

  # 4. Worker de n8n (Ejecuta las tareas)
  n8n-worker:
    image: docker.n8n.io/n8nio/n8n:latest
    restart: always
    command: worker
    environment:
      - EXECUTIONS_MODE=queue
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB:-n8n}
      - DB_POSTGRESDB_USER=${POSTGRES_USER:-n8n}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD:-n8n_password}
      - QUEUE_BULL_REDIS_HOST=redis
      - QUEUE_BULL_REDIS_PORT=6379
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY:-tu_clave_secreta_aqui}
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  postgres_data:
  redis_data:
  n8n_data:
Variables clave a añadir en las variables de entorno (.env)
Asegúrate de que tanto la instancia principal como el worker compartan estas variables:

EXECUTIONS_MODE=queue: Activa el modo cola en n8n.

QUEUE_BULL_REDIS_HOST=redis: Nombre del servicio de Redis en Docker Compose.

QUEUE_BULL_REDIS_PORT=6379: Puerto por defecto de Redis.

N8N_ENCRYPTION_KEY: La clave de cifrado debe ser exactamente la misma en el contenedor n8n-main y en los n8n-worker.

Pasos para desplegarlo
Edita tu archivo docker-compose.yml añadiendo el servicio redis, ajustando EXECUTIONS_MODE=queue y creando el servicio n8n-worker con la propiedad command: worker.

Reinicia los contenedores levantando los nuevos servicios:

Bash
docker compose down
docker compose up -d
Si deseas escalar la capacidad de procesamiento de ejecuciones simultáneas, puedes aumentar el número de workers con un solo comando:

Bash
docker compose up -d --scale n8n-worker=2