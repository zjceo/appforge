# n8n - Configuración Docker

## Inicio rápido

1. Copia el archivo `.env.example` a `.env` y configura las variables según tus necesidades
2. Inicia el contenedor:

```bash
docker-compose up -d
```

3. Accede a n8n en: http://localhost:5678

## Detener el contenedor

```bash
docker-compose down
```

## Ver logs

```bash
docker-compose logs -f
```

## Backup de datos

Los datos se almacenan en un volumen de Docker llamado `n8n_data`. Para hacer backup:

```bash
docker run --rm -v n8n_data:/data -v $(pwd):/backup ubuntu tar czf /backup/n8n_backup.tar.gz /data
```

## Restaurar backup

```bash
docker run --rm -v n8n_data:/data -v $(pwd):/backup ubuntu tar xzf /backup/n8n_backup.tar.gz -C /
```

