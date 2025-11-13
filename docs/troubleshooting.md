# Solución de Problemas

## Problemas Comunes

### Docker no está instalado

**Solución:** Instala Docker siguiendo la documentación oficial:
- Linux: https://docs.docker.com/engine/install/
- macOS: https://docs.docker.com/desktop/install/mac-install/
- Windows: https://docs.docker.com/desktop/install/windows-install/

### Puerto ya en uso

**Error:** `port is already allocated`

**Solución:** 
1. Identifica qué aplicación está usando el puerto:
   ```bash
   sudo lsof -i :PUERTO
   ```
2. Cambia el puerto en el archivo `docker-compose.yml` o `.env`
3. Detén el servicio que está usando el puerto si es necesario

### Error de permisos

**Error:** `Permission denied`

**Solución:**
```bash
sudo chmod +x install.sh
sudo chmod +x scripts/*.sh
sudo chmod +x utils/*.sh
```

### Contenedor no inicia

**Solución:**
1. Verifica los logs:
   ```bash
   docker-compose logs -f
   ```
2. Verifica la configuración del archivo `.env`
3. Verifica que todos los servicios dependientes estén corriendo
4. Revisa los recursos del sistema (memoria, CPU, disco)

### Problemas de conectividad con la base de datos

**Solución:**
1. Verifica que el contenedor de la base de datos esté corriendo:
   ```bash
   docker-compose ps
   ```
2. Verifica las credenciales en el archivo `.env`
3. Verifica la URL de conexión
4. Espera unos segundos después de iniciar la base de datos para que esté lista

### Problemas con volúmenes

**Error:** `Volume not found` o problemas de persistencia

**Solución:**
1. Verifica que los volúmenes estén creados:
   ```bash
   docker volume ls
   ```
2. Crea los volúmenes manualmente si es necesario:
   ```bash
   docker volume create nombre-volumen
   ```

## Logs y Debugging

### Ver logs de una aplicación

```bash
cd [nombre-aplicacion]
docker-compose logs -f
```

### Ver logs de un servicio específico

```bash
docker-compose logs -f nombre-servicio
```

### Inspeccionar un contenedor

```bash
docker-compose exec nombre-servicio sh
```

### Reiniciar una aplicación

```bash
docker-compose restart
```

### Recrear contenedores

```bash
docker-compose up -d --force-recreate
```

## Obtener Ayuda

Si continúas teniendo problemas:

1. Revisa la documentación específica de la aplicación en `docs/apps/`
2. Consulta la documentación oficial de la aplicación
3. Revisa los issues en el repositorio del proyecto
4. Verifica la compatibilidad de versiones de Docker y Docker Compose

