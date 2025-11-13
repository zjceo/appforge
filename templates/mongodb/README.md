# MongoDB - Configuración Docker

## Inicio rápido

1. Copia el archivo `.env.example` a `.env` y configura las variables según tus necesidades
2. **Importante**: Cambia las credenciales por defecto en producción
3. Inicia el contenedor:

```bash
docker-compose up -d
```

4. Conecta a MongoDB usando la URI de conexión:
   ```
   mongodb://admin:admin@localhost:27017/admin?authSource=admin
   ```

## Conectar con mongosh

```bash
docker-compose exec mongodb mongosh -u admin -p admin --authenticationDatabase admin
```

## Detener el contenedor

```bash
docker-compose down
```

## Ver logs

```bash
docker-compose logs -f
```

## Backup

```bash
docker-compose exec mongodb mongodump --uri="mongodb://admin:admin@localhost:27017/admin?authSource=admin" --out=/backup
```

## Restaurar

```bash
docker-compose exec mongodb mongorestore --uri="mongodb://admin:admin@localhost:27017/admin?authSource=admin" /backup
```

