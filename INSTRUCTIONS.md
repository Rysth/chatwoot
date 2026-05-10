# ROADMAP: Chatwoot Multi-tenant (Single-tenant per Client)

> Fork de Chatwoot oficial | Rama base: `develop` | Build local con Docker | Registry: Docker Hub | Deploy: Dokploy

---

## Fase 1: Preparación y Sincronización

### 1.1 Sincronizar `develop` con upstream

```bash
git checkout develop
git fetch upstream
git merge upstream/develop --no-edit
# Resolver conflictos si los hay
git push origin develop
```

### 1.2 Crear rama del cliente

```bash
git checkout -b client/<nombre-cliente>
# Ejemplo: git checkout -b client/acme-corp
```

### 1.3 Verificar que no hay contaminación cruzada

```bash
git log --oneline -5 develop
```

---

## Fase 2: Personalización de Marca (Branding)

### 2.1 Nombre de la instalación

Editar `config/installation_config.yml`:

```yaml
- name: INSTALLATION_NAME
  value: 'Nombre del Cliente'
```

> Este valor se propaga automáticamente vía `useBranding.js` (`replaceInstallationName`) que reemplaza todas las ocurrencias de "Chatwoot" en el UI.

### 2.2 Logos principales (reemplazar archivos SVG)

| Archivo | Ubicación | Uso |
|---------|-----------|-----|
| `logo.svg` | `public/brand-assets/logo.svg` | Dashboard, login (modo claro) |
| `logo_dark.svg` | `public/brand-assets/logo_dark.svg` | Dashboard, login (modo oscuro) |
| `logo_thumbnail.svg` | `public/brand-assets/logo_thumbnail.svg` | Favicon (512x512) |

### 2.3 Logo del widget de chat

| Archivo | Ubicación |
|---------|-----------|
| `logo.svg` | `app/javascript/widget/assets/images/logo.svg` |
| `logo-thumbnail.svg` | `app/javascript/design-system/images/logo-thumbnail.svg` |

### 2.4 Logo de Captain (AI Assistant)

| Archivo | Ubicación |
|---------|-----------|
| `logo.svg` | `public/assets/images/dashboard/captain/logo.svg` |

### 2.5 Colores de marca

Editar `theme/colors.js` → objeto `colors.woot` para cambiar la paleta azul principal. Para cambios más amplios, modificar `tailwind.config.js` en la sección `colors`.

### 2.6 URLs de marca y términos

En `config/installation_config.yml`:

```yaml
- name: BRAND_URL
  value: 'https://www.cliente.com'
- name: WIDGET_BRAND_URL
  value: 'https://www.cliente.com'
- name: BRAND_NAME
  value: 'Nombre Cliente'
- name: TERMS_URL
  value: 'https://www.cliente.com/terms'
- name: PRIVACY_URL
  value: 'https://www.cliente.com/privacy'
```

### 2.7 i18n (opcional)

Si hay textos que `replaceInstallationName` no cubre, buscar en `app/javascript/shared/locales/en.json` y `config/locales/en.yml`.

---

## Fase 3: Ciclo de Build y Registro

### 3.1 Build local

```bash
docker build -f docker/Dockerfile \
  --build-arg RAILS_ENV=production \
  -t <dockerhub-user>/chatwoot-<cliente>:<tag> .
```

### 3.2 Push a Docker Hub

```bash
docker push <dockerhub-user>/chatwoot-<cliente>:<tag>
```

### 3.3 Tags recomendados

| Tag | Uso |
|-----|-----|
| `v1.0.0` | Release inicial |
| `v1.1.0` | After upstream sync |
| `latest` | Última estable (opcional) |

---

## Fase 4: Despliegue y Mantenimiento

### 4.1 Configuración en Dokploy

1. Crear nuevo servicio → **Image-based deployment**
2. Image: `<dockerhub-user>/chatwoot-<cliente>:<tag>`
3. Port: `3000`
4. Environment variables mínimas:
   ```
   RAILS_ENV=production
   SECRET_KEY_BASE=<generar>
   POSTGRES_HOST=<host>
   POSTGRES_DATABASE=<db_cliente>
   POSTGRES_USERNAME=<user>
   POSTGRES_PASSWORD=<password>
   REDIS_URL=redis://<host>:6379
   INSTALLATION_NAME=<Nombre Cliente>
   ```

### 4.2 Flujo de actualización desde upstream

```bash
# 1. Actualizar develop
git checkout develop && git fetch upstream && git merge upstream/develop --no-edit && git push origin develop

# 2. Merge a rama del cliente
git checkout client/<nombre-cliente>
git merge develop --no-edit

# 3. Resolver conflictos de branding si los hay
# 4. Verificar branding intacto
# 5. Commit + push de rama
# 6. Rebuild + docker push (Fase 3)
# 7. Actualizar tag en Dokploy
```

### 4.3 Checklist post-merge

- [ ] `config/installation_config.yml` mantiene valores del cliente
- [ ] `public/brand-assets/*.svg` son los logos del cliente
- [ ] `theme/colors.js` mantiene paleta del cliente
- [ ] `app/javascript/widget/assets/images/logo.svg` logo del widget
- [ ] Build local pasa sin errores
- [ ] Push a Docker Hub exitoso
- [ ] Dokploy actualizado con nuevo tag

---

## Resumen rápido: Nuevo cliente de inicio a fin

```bash
# 1. Sincronizar
git checkout develop && git fetch upstream && git merge upstream/develop --no-edit && git push origin develop

# 2. Crear rama
git checkout -b client/<nombre-cliente>

# 3. Branding (editar archivos de Fase 2)

# 4. Commit
git add . && git commit -m "chore: setup branding for <nombre-cliente>"

# 5. Build
docker build -f docker/Dockerfile --build-arg RAILS_ENV=production -t <user>/chatwoot-<cliente>:v1.0.0 .

# 6. Push image
docker push <user>/chatwoot-<cliente>:v1.0.0

# 7. Deploy en Dokploy (image-based, configurar env vars)
```
