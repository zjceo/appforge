# RabbitMQ - Configuración Docker

## Inicio rápido

1. Copia el archivo `.env.example` a `.env` y configura las variables según tus necesidades
2. **Importante**: Cambia las credenciales por defecto en producción
3. Inicia el contenedor:

```bash
docker-compose up -d
```

4. Accede a:
   - **Consola web**: http://localhost:15672
   - **AMQP**: amqp://admin:admin@localhost:5672/

## Primer acceso

1. Accede a la consola web en http://localhost:15672
2. Inicia sesión con las credenciales configuradas en `.env`
3. Desde la consola puedes gestionar colas, exchanges, conexiones, etc.

## Detener el contenedor

```bash
docker-compose down
```

## Ver logs

```bash
docker-compose logs -f
```

## Uso con aplicaciones

Para conectar una aplicación a RabbitMQ, usa la URI de conexión:
```
amqp://admin:admin@localhost:5672/
```

O con el protocolo AMQP:
```
amqp://admin:admin@localhost:5672/vhost_name
```

