# Evolution API

## Descripción

Evolution API es una API REST para WhatsApp que permite integrar funcionalidades de WhatsApp en aplicaciones.

## Requisitos

- Puerto 8080 (por defecto)
- Base de datos MongoDB
- Redis (opcional pero recomendado)

## Instalación

```bash
./install.sh
# Selecciona opción 3
```

## Configuración

Edita el archivo `.env` para configurar:

- `SERVER_URL`: URL del servidor
- `DATABASE_ENABLED`: Habilitar base de datos
- `DATABASE_CONNECTION_URI`: URI de conexión a MongoDB
- `REDIS_ENABLED`: Habilitar Redis
- `REDIS_URI`: URI de conexión a Redis

## Acceso

Una vez iniciado, accede a: http://localhost:8080

## Documentación oficial

https://doc.evolution-api.com/

