# Evolution API - Configuración Docker

## Inicio rápido

1. Copia el archivo `.env.example` a `.env` y configura las variables según tus necesidades
2. Inicia los contenedores:

```bash
docker-compose up -d
```

3. Accede a Evolution API en: http://localhost:8080

## Detener los contenedores

```bash
docker-compose down
```

## Ver logs

```bash
docker-compose logs -f
```

## Crear una instancia

Después de iniciar los contenedores, necesitas crear una instancia de WhatsApp usando la API:

```bash
curl -X POST http://localhost:8080/instance/create \
  -H "Content-Type: application/json" \
  -d '{
    "instanceName": "mi-instancia",
    "token": "mi-token-secreto",
    "qrcode": true
  }'
```

## Documentación de la API

Consulta la documentación en: https://doc.evolution-api.com/

