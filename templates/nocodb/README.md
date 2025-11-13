# NocoDB - Configuración Docker

## Inicio rápido

1. Copia el archivo `.env.example` a `.env` y configura las variables según tus necesidades
2. Inicia los contenedores:

```bash
docker-compose up -d
```

3. Accede a NocoDB en: http://localhost:8080

## Detener los contenedores

```bash
docker-compose down
```

## Ver logs

```bash
docker-compose logs -f
```

## Backup de datos

Los datos se almacenan en volúmenes de Docker. Para hacer backup:

```bash
# Backup de NocoDB
docker run --rm -v nocodb_data:/data -v $(pwd):/backup ubuntu tar czf /backup/nocodb_backup.tar.gz /data

# Backup de PostgreSQL
docker run --rm -v nocodb_db_data:/data -v $(pwd):/backup ubuntu tar czf /backup/nocodb_db_backup.tar.gz /data
```

