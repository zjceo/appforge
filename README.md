# 🚀 AppForge

Sistema automatizado de instalación y gestión de aplicaciones con Docker en VPS.

## ✨ Características

- 🔄 **Instalación con un solo comando**
- 🔐 **Credenciales automáticas** generadas por dominio
- 🌐 **SSL automático** con Let's Encrypt (Traefik)
- 📦 **10+ aplicaciones** listas para usar
- 🗄️ **Base de datos separada** por cada app
- 💾 **Sistema de backups** automático
- 📊 **Monitoreo en tiempo real**
- 🔄 **Actualizaciones fáciles**

## 🛠️ Stack de Aplicaciones

| Categoría | Apps |
|-----------|------|
| **Automatización** | N8N |
| **Bases de datos sin código** | NocoDB |
| **WhatsApp/Chatbots** | Evolution API, Typebot |
| **Soporte al cliente** | Chatwoot |
| **IA/LLMs** | Flowise |
| **Storage** | MinIO (S3 compatible) |
| **Bases de datos** | MongoDB, PostgreSQL, Redis |
| **Message Queue** | RabbitMQ |

## 📋 Requisitos

- VPS con Ubuntu 20.04+ / Debian 11+
- 2GB RAM mínimo (4GB recomendado)
- 20GB espacio en disco
- Dominio(s) apuntando al servidor

## 🚀 Instalación Rápida
```bash
# Clonar repositorio
git clone https://github.com/zjceo/appforge.git
cd appforge

# Dar permisos
chmod +x install.sh
chmod +x scripts/*.sh
chmod +x utils/*.sh

# Ejecutar como root
sudo ./install.sh
```

## 📖 Uso Básico

### Instalar una aplicación
```bash
sudo ./install.sh
# Selecciona la app → Ingresa dominio → ¡Listo!
```

### Ver aplicaciones instaladas
```bash
./utils/monitoring.sh
```

### Hacer backup
```bash
./scripts/backup.sh n8n-1
./scripts/backup.sh -a  # Todas las apps
```

### Actualizar apps
```bash
./scripts/update-all.sh n8n-1
./scripts/update-all.sh -a  # Todas
```

### Ver credenciales

Las credenciales se guardan automáticamente en `credentials.txt`
```bash
cat credentials.txt
```

## 🏗️ Arquitectura
```
                    ┌─────────────────┐
                    │   Traefik       │
                    │  (Reverse Proxy)│
                    │  SSL/Let's Encrypt
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
    ┌────▼────┐         ┌────▼────┐        ┌────▼────┐
    │  N8N    │         │Chatwoot │        │ NocoDB  │
    │ + DB    │         │ + DB    │        │ + DB    │
    └─────────┘         └─────────┘        └─────────┘
```

Cada app tiene:
- ✅ Contenedor(es) aislado(s)
- ✅ Base de datos propia
- ✅ SSL/HTTPS automático
- ✅ Credenciales únicas
- ✅ Volúmenes persistentes

## 📚 Documentación Completa

- [Guía de Instalación](docs/installation.md)
- [Solución de Problemas](docs/troubleshooting.md)
- [Apps individuales](docs/apps/)

## 🔧 Scripts Disponibles

### Gestión
```bash
./scripts/backup.sh <app>      # Hacer backup
./scripts/restore.sh <app>     # Restaurar
./scripts/update-all.sh <app>  # Actualizar
./scripts/remove-app.sh <app>  # Eliminar
```

### Monitoreo
```bash
./utils/monitoring.sh          # Estado general
./utils/monitoring.sh -w       # Modo watch
./utils/ssl-renew.sh -c        # Ver certificados SSL
```

## 🤝 Contribuir

Pull requests son bienvenidos. Para cambios mayores:

1. Fork el proyecto
2. Crea tu branch (`git checkout -b feature/AmazingFeature`)
3. Commit cambios (`git commit -m 'Add AmazingFeature'`)
4. Push al branch (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📄 Licencia

MIT License - ver [LICENSE](LICENSE) para más detalles

## 🆘 Soporte

- 📖 [Documentación](docs/)
- 🐛 [Issues](https://github.com/zjceo/appforge/issues)
- 💬 [Discussions](https://github.com/zjceo/appforge/discussions)

## ⭐ Roadmap

- [ ] Panel web de administración
- [ ] Integración con Telegram para notificaciones
- [ ] Backups automáticos programados
- [ ] Más aplicaciones (Metabase, Grafana, etc.)
- [ ] Cluster multi-servidor