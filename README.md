# Chatwoot — Plataforma de Soporte al Cliente para PyMes

Fork del proyecto [Chatwoot](https://github.com/chatwoot/chatwoot) optimizado para pequeños negocios que buscan centralizar sus interacciones en redes sociales, email y chat en un solo lugar.

Este repositorio sigue el modelo **single-tenant por cliente** sobre una base `multi-tenant-ready`, permitiendo personalizar branding, permisos y flujos de trabajo por cuenta sin contaminación cruzada.

---

## ¿Qué es este proyecto?

Chatwoot es una plataforma open-source de soporte al cliente. Este fork la adapta específicamente para **PyMes y agencias digitales** que necesitan:

- Centralizar conversaciones de WhatsApp, Instagram, Facebook Messenger, email y web chat.
- Asignación automática (round-robin) de conversaciones a agentes.
- Control de permisos granular: los agentes solo ven sus conversaciones, mientras los administradores tienen visibilidad total.
- Branding blanco totalmente personalizable por cliente.
- Despliegue sencillo vía Docker y Dokploy.

---

## Arquitectura Multi-tenant (Single-tenant por Cliente)

Cada cliente tiene su propia rama y su propia imagen Docker. No se comparten datos ni configuraciones entre clientes.

```
upstream/chatwoot  →  origin/develop  →  client/<nombre-cliente>
```

### Flujo de ramas

| Rama | Propósito |
|------|-----------|
| `develop` | Base sincronizada con upstream. Acumula mejoras comunes. |
| `client/<nombre>` | Personalización de branding, colores y permisos para un cliente específico. |

### Sincronizar con upstream

```bash
git checkout develop
git fetch upstream
git merge upstream/develop --no-edit
git push origin develop
```

### Crear nuevo cliente

```bash
git checkout develop
git checkout -b client/acme-corp
# Editar branding (ver Fase 2)
git add . && git commit -m "chore: setup branding for acme-corp"
git push origin client/acme-corp
```

---

## Desarrollo Local

### Requisitos

- Docker + Docker Compose
- Git

### Levantar el entorno

```bash
# Primera vez o reset completo
./setup.sh

# Inicio rápido (usa imágenes existentes, conserva datos)
./setup.sh --skip-build

# Reset total (DESTRUYE la base de datos)
./setup.sh --reset
```

### Acceso

- **Aplicación:** http://localhost:3000
- **MailHog (emails de prueba):** http://localhost:8025

### Credenciales de prueba (seed)

Tras ejecutar `docker compose exec rails bundle exec rails db:seed`:

- **Email:** `john@acme.inc`
- **Password:** `Password1!`

---

## Personalización de Marca (Branding)

### 1. Nombre de instalación

Editar `config/installation_config.yml`:

```yaml
- name: INSTALLATION_NAME
  value: 'Nombre del Cliente'
```

El UI reemplaza automáticamente "Chatwoot" mediante `replaceInstallationName`.

### 2. Logos

| Archivo | Ubicación |
|---------|-----------|
| Logo claro | `public/brand-assets/logo.svg` |
| Logo oscuro | `public/brand-assets/logo_dark.svg` |
| Favicon | `public/brand-assets/logo_thumbnail.svg` |
| Widget chat | `app/javascript/widget/assets/images/logo.svg` |
| Captain (AI) | `public/assets/images/dashboard/captain/logo.svg` |

### 3. Colores

Editar `theme/colors.js` → `colors.woot` para cambiar la paleta principal. Para cambios amplios, modificar `tailwind.config.js`.

### 4. URLs y términos

```yaml
# config/installation_config.yml
- name: BRAND_URL
  value: 'https://www.cliente.com'
- name: BRAND_NAME
  value: 'Nombre Cliente'
- name: TERMS_URL
  value: 'https://www.cliente.com/terms'
- name: PRIVACY_URL
  value: 'https://www.cliente.com/privacy'
```

---

## Build y Registro

### Construir imagen

```bash
docker build -f docker/Dockerfile \
  --build-arg RAILS_ENV=production \
  -t <dockerhub-user>/chatwoot-<cliente>:<tag> .
```

### Push a Docker Hub

```bash
docker push <dockerhub-user>/chatwoot-<cliente>:<tag>
```

### Tags recomendados

| Tag | Uso |
|-----|-----|
| `v1.0.0` | Release inicial del cliente |
| `v1.1.0` | Post-merge con upstream |
| `latest` | Última estable (opcional) |

---

## Despliegue con Dokploy

1. Crear servicio → **Image-based deployment**
2. Image: `<dockerhub-user>/chatwoot-<cliente>:<tag>`
3. Port: `3000`
4. Variables de entorno mínimas:

```env
RAILS_ENV=production
SECRET_KEY_BASE=<generar con openssl rand -hex 64>
POSTGRES_HOST=<host>
POSTGRES_DATABASE=<db_cliente>
POSTGRES_USERNAME=<user>
POSTGRES_PASSWORD=<password>
REDIS_URL=redis://<host>:6379
INSTALLATION_NAME=<Nombre Cliente>
FRONTEND_URL=https://<dominio-cliente.com>
```

### Actualización desde upstream

```bash
# 1. Sincronizar develop
git checkout develop && git fetch upstream && git merge upstream/develop --no-edit && git push origin develop

# 2. Merge a rama del cliente
git checkout client/<nombre-cliente>
git merge develop --no-edit

# 3. Revisar branding intacto
# 4. Rebuild + docker push
# 5. Actualizar tag en Dokploy
```

---

## Funcionalidades Clave

### Omnichannel
- Web chat, email, Facebook, Instagram, Twitter, WhatsApp, Telegram, SMS.

### Gestión de Conversaciones
- **Asignación automática (round-robin)** según disponibilidad de agentes.
- **Vistas filtradas por permisos:** los agentes normales solo ven "Mías", los administradores ven "Sin asignar" y "Todos".
- **Acciones masivas:** solo administradores pueden reasignar agentes en bloque.
- **Coloración visual:** las tarjetas de conversación toman un tinte sutil del color de la primera etiqueta para mejorar la navegación.

### Colaboración
- Notas privadas, @mentions, etiquetas, respuestas enlatadas.
- Atajos de teclado y Command Bar.

### Inteligencia Artificial
- **Captain:** agente de IA integrado para automatizar respuestas y reducir carga operativa.

### Centro de Ayuda
- Portal de artículos y FAQs para autoservicio del cliente.

### Reportes
- Conversaciones, agentes, equipos, etiquetas, satisfacción (CSAT).

---

## Checklist: Nuevo Cliente de Inicio a Fin

```bash
# 1. Sincronizar develop
git checkout develop && git fetch upstream && git merge upstream/develop --no-edit

# 2. Crear rama del cliente
git checkout -b client/<nombre-cliente>

# 3. Personalizar branding (logos, colors.js, installation_config.yml)

# 4. Commit
git add . && git commit -m "chore: setup branding for <nombre-cliente>"

# 5. Build
docker build -f docker/Dockerfile --build-arg RAILS_ENV=production -t <user>/chatwoot-<cliente>:v1.0.0 .

# 6. Push image
docker push <user>/chatwoot-<cliente>:v1.0.0

# 7. Deploy en Dokploy (image-based, configurar env vars)
```

---

## Documentación y Comunidad

- Documentación oficial de Chatwoot: [chatwoot.com/help-center](https://www.chatwoot.com/help-center)
- Traducciones: [translate.chatwoot.com](https://translate.chatwoot.com)
- Discord original: [discord.gg/cJXdrwS](https://discord.gg/cJXdrwS)

---

## Licencia

Este fork mantiene la licencia **MIT** del proyecto original Chatwoot.

*Chatwoot* &copy; 2017-2026, Chatwoot Inc — Released under the MIT License.

Adaptaciones y personalización para PyMes por [Rysth Design](https://github.com/Rysth).
