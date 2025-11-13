# Typebot - Configuración Docker

## Inicio rápido

1. Copia el archivo `.env.example` a `.env` y configura las variables según tus necesidades
2. Inicia los contenedores:

```bash
docker-compose up -d
```

3. Accede a Typebot Builder en: http://localhost:3000
4. Accede a Typebot Viewer en: http://localhost:3001

## Detener los contenedores

```bash
docker-compose down
```

## Ver logs

```bash
docker-compose logs -f
```

## Primer inicio

Al iniciar por primera vez, deberás crear una cuenta de administrador en el Builder.

## Nota importante

- **Builder**: Interfaz para crear y editar chatbots (puerto 3000)
- **Viewer**: Interfaz pública para que los usuarios interactúen con los chatbots (puerto 3001)

