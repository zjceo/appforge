# Chatwoot - Configuración Docker

## Inicio rápido

1. Copia el archivo `.env.example` a `.env` y configura las variables según tus necesidades
2. **Importante**: Genera un `SECRET_KEY_BASE`:

```bash
docker run --rm chatwoot/chatwoot:latest bundle exec rails secret
```

Copia el resultado y actualízalo en el archivo `.env`.

3. Inicia los contenedores:

```bash
docker-compose up -d
```

4. Ejecuta las migraciones de la base de datos:

```bash
docker-compose exec rails bundle exec rails db:chatwoot_prepare
```

5. Accede a Chatwoot en: http://localhost:3000

## Crear un usuario administrador

```bash
docker-compose exec rails bundle exec rails runner "user = User.find_by(email: 'admin@example.com') || User.new(email: 'admin@example.com', name: 'Admin', password: 'password123', password_confirmation: 'password123'); user.save!; AccountUser.create!(account_id: Account.first.id, user_id: user.id, role: :administrator)"
```

## Detener los contenedores

```bash
docker-compose down
```

## Ver logs

```bash
docker-compose logs -f
```

