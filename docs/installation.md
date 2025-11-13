# Guía de Instalación

## Requisitos Previos

- Docker (versión 20.10 o superior)
- Docker Compose (versión 2.0 o superior)
- Sistema operativo: Linux, macOS o Windows con WSL2

## Instalación

1. Clona o descarga este repositorio
2. Ejecuta el script de instalación:

```bash
chmod +x install.sh
./install.sh
```

3. Sigue las instrucciones en pantalla para seleccionar la aplicación que deseas instalar
4. Configura las variables de entorno en el archivo `.env` generado
5. Inicia la aplicación:

```bash
cd [nombre-aplicacion]
docker-compose up -d
```

## Verificación

Para verificar que la aplicación está funcionando correctamente:

```bash
docker-compose ps
docker-compose logs -f
```

## Actualización

Para actualizar una aplicación:

```bash
./scripts/update-all.sh [nombre-aplicacion]
```

## Desinstalación

Para eliminar una aplicación:

```bash
./scripts/remove-app.sh [nombre-aplicacion]
```

