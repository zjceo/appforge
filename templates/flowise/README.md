# Flowise - Configuración Docker

## Descripción

Flowise es una herramienta de código abierto para crear flujos de trabajo LLM personalizados de manera visual.

## Inicio rápido

1. Copia el archivo `.env.example` a `.env` y configura las variables según tus necesidades
2. Inicia el contenedor:

```bash
docker-compose up -d
```

3. Accede a Flowise en: http://localhost:3000

## Detener el contenedor

```bash
docker-compose down
```

## Ver logs

```bash
docker-compose logs -f
```

## Autenticación

Si configuraste `FLOWISE_USERNAME` y `FLOWISE_PASSWORD`, necesitarás autenticarte para acceder a la interfaz.

