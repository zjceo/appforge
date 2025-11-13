# Chatwoot

## Descripción

Chatwoot es una plataforma de atención al cliente de código abierto que te permite conversar con tus clientes desde un solo lugar.

## Requisitos

- Puerto 3000 (por defecto)
- Base de datos PostgreSQL
- Redis

## Instalación

```bash
./install.sh
# Selecciona opción 5
```

## Configuración

Edita el archivo `.env` para configurar:

- `POSTGRES_HOST`: Host de PostgreSQL
- `POSTGRES_DATABASE`: Nombre de la base de datos
- `POSTGRES_USERNAME`: Usuario de PostgreSQL
- `POSTGRES_PASSWORD`: Contraseña de PostgreSQL
- `SECRET_KEY_BASE`: Secret key para Rails
- `FRONTEND_URL`: URL pública del frontend
- `REDIS_URL`: URL de conexión a Redis

## Acceso

Una vez iniciado, accede a: http://localhost:3000

## Documentación oficial

https://www.chatwoot.com/docs

