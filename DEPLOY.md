# Plan de Despliegue a Producción — `client/rysth-design`

> **Fecha:** 2026-05-12  
> **Rama:** `client/rysth-design`  
> **Imagen Docker objetivo:** `rysthcraft/chatwoot:client-rysth-design`

---

## 1. Estado de las ramas

- `client/rysth-design` está lista para producción.
- `develop` tiene 3 commits adicionales (merge + mejoras en `setup.sh`) que **no afectan** el runtime de la app.
- El código funcional es idéntico en ambas ramas.

---

## 2. Riesgos identificados

| Riesgo | Severidad | Mitigación |
|---|---|---|
| Cambios en `db/schema.rb` y migración antigua sin nueva migración asociada | Medio | `rails db:chatwoot_prepare` se ejecuta automáticamente al iniciar el contenedor Rails. Monitorear logs post-deploy. |
| Nuevas migraciones de upstream (2026) no presentes en `v4.13.0` | Medio | Se ejecutarán automáticamente con `db:chatwoot_prepare`. Backup obligatorio previo. |
| Sidekiq desincronizado si no se actualiza la imagen en ambos servicios | Alto | Actualizar `image:` en `x-base-config` del compose (afecta Rails + Sidekiq). |

---

## 3. Backup obligatorio (Dokploy)

Antes de cualquier cambio:

```bash
# Terminal en el contenedor chatwoot-postgres de Dokploy
pg_dump -U $POSTGRES_USERNAME -d $POSTGRES_DATABASE > /tmp/chatwoot_backup_$(date +%Y%m%d_%H%M%S).sql
```

Descargar el archivo `.sql` a tu PC.

---

## 4. Build y push de la imagen (local)

```bash
# 1. Login en Docker Hub
docker login

# 2. Build desde la raíz del repo (rama client/rysth-design)
docker build -t rysthcraft/chatwoot:client-rysth-design -f docker/Dockerfile .

# 3. Push a Docker Hub
docker push rysthcraft/chatwoot:client-rysth-design
```

> **Tiempo estimado:** 10–20 minutos según conexión y CPU.

---

## 5. Actualizar `docker-compose.yml` en Dokploy

Reemplazar únicamente la línea de imagen en `x-base-config`:

```yaml
x-base-config: &base-config
  image: rysthcraft/chatwoot:client-rysth-design
  volumes:
    - chatwoot-storage:/app/storage
  environment:
    ... # resto sin cambios
```

**No modificar** `entrypoint`, `command`, volúmenes ni variables de entorno.

---

## 6. Desplegar en Dokploy

1. Hacer clic en **Deploy** (o **Reload**).
2. Revisar logs del contenedor `chatwoot-rails`:
   - Confirmar: `Database ready to accept connections.`
   - Confirmar que `rails db:chatwoot_prepare` ejecute migraciones sin errores.
3. Revisar logs de `chatwoot-sidekiq` para confirmar que también levanta con la nueva imagen.

---

## 7. Verificación post-despliegue

- [ ] App accesible en el dominio sin errores 500.
- [ ] Login funciona correctamente.
- [ ] Conversaciones cargan y envían mensajes.
- [ ] Sidekiq procesa jobs en segundo plano.
- [ ] No hay errores de `PendingMigrationError` en logs.

---

## 8. Rollback (en caso de emergencia)

1. Editar `docker-compose.yml` en Dokploy y revertir:
   ```yaml
   image: chatwoot/chatwoot:v4.13.0
   ```
2. Hacer clic en **Deploy**.
3. Si la BD quedó en un estado incompatible, restaurar desde el backup:
   ```bash
   psql -U $POSTGRES_USERNAME -d $POSTGRES_DATABASE < /tmp/chatwoot_backup_YYYYMMDD_HHMMSS.sql
   ```

---

## 9. Próximos pasos sugeridos

- Automatizar el build/push con GitHub Actions para evitar builds locales manuales.
- Crear tags semánticas (`rysthcraft/chatwoot:v1.0.0`) en lugar de usar nombres de rama.
- Monitorear métricas de Dokploy 24h post-despliegue.
