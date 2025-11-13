# MinIO - Configuración Docker

## Descripción

MinIO es un servidor de almacenamiento de objetos compatible con S3.

## Inicio rápido

1. Copia el archivo `.env.example` a `.env` y configura las variables según tus necesidades
2. **Importante**: Cambia las credenciales por defecto en producción
3. Inicia el contenedor:

```bash
docker-compose up -d
```

4. Accede a:
   - **API**: http://localhost:9000
   - **Console**: http://localhost:9001

## Primer acceso

1. Accede a la consola web en http://localhost:9001
2. Inicia sesión con las credenciales configuradas en `.env`
3. Crea un bucket para empezar a almacenar archivos

## Detener el contenedor

```bash
docker-compose down
```

## Ver logs

```bash
docker-compose logs -f
```

## Cliente MinIO

Puedes usar el cliente de línea de comandos:

```bash
docker run --rm -it --network host minio/mc alias set local http://localhost:9000 minioadmin minioadmin
docker run --rm -it --network host minio/mc ls local
```

