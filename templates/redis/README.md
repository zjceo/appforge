# Redis - Configuración Docker

## Inicio rápido

1. Copia el archivo `.env.example` a `.env` y configura las variables según tus necesidades
2. Inicia el contenedor:

```bash
docker-compose up -d
```

3. Conecta a Redis usando la URI de conexión:
   ```
   redis://localhost:6379
   ```
   O si configuraste una contraseña:
   ```
   redis://:password@localhost:6379
   ```

## Conectar con redis-cli

```bash
# Sin contraseña
docker-compose exec redis redis-cli

# Con contraseña
docker-compose exec redis redis-cli -a password
```

## Detener el contenedor

```bash
docker-compose down
```

## Ver logs

```bash
docker-compose logs -f
```

## Comandos útiles

```bash
# Ver todas las claves
KEYS *

# Obtener el valor de una clave
GET key_name

# Establecer un valor
SET key_name value

# Eliminar una clave
DEL key_name

# Ver información del servidor
INFO
```

