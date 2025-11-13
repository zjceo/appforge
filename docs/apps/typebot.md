# Typebot

## Descripción

Typebot es una plataforma de código abierto para crear chatbots conversacionales sin código.

## Requisitos

- Puerto 3000 (por defecto)
- Base de datos PostgreSQL
- Redis

## Instalación

```bash
./install.sh
# Selecciona opción 4
```

## Configuración

Edita el archivo `.env` para configurar:

- `DATABASE_URL`: URL de conexión a PostgreSQL
- `NEXTAUTH_URL`: URL pública de la aplicación
- `NEXTAUTH_SECRET`: Secret para NextAuth
- `SMTP_HOST`: (Opcional) Servidor SMTP para emails
- `REDIS_URL`: URL de conexión a Redis

## Acceso

Una vez iniciado, accede a: http://localhost:3000

## Documentación oficial

https://docs.typebot.io/

