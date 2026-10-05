FROM n8nio/n8n:2.40.7

# Zona horaria del contenedor (opcional, ajusta a tu país)
ENV TZ=Europe/Madrid

# Si necesitas nodos comunitarios adicionales, descomenta e instala aquí, ej:
# USER root
# RUN npm install -g n8n-nodes-XXXXX
# USER node

EXPOSE 5678
