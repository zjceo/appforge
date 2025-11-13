# NocoDB

## Descripción

NocoDB es una alternativa de código abierto a Airtable que convierte cualquier base de datos MySQL, PostgreSQL, SQL Server, SQLite o MariaDB en una hoja de cálculo inteligente.

## Requisitos

- Puerto 8080 (por defecto)
- Base de datos MySQL/PostgreSQL (incluida en el template)

## Instalación

```bash
./install.sh
# Selecciona opción 2
```

## Configuración

Edita el archivo `.env` para configurar:

- `NC_DB`: URL de conexión a la base de datos
- `NC_AUTH_JWT_SECRET`: Secret para JWT tokens
- `NC_SENTRY_DSN`: (Opcional) DSN de Sentry para monitoreo

## Acceso

Una vez iniciado, accede a: http://localhost:8080

## Documentación oficial

https://docs.nocodb.com/

