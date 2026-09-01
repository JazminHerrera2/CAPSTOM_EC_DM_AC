# Guía de arranque local de TAG OK

Esta guía explica cómo preparar por primera vez y cómo iniciar diariamente el proyecto TAG OK en Windows. Incluye el panel web, Gateway, servicios, bases de datos, Supabase y la aplicación Android.

> Actualizada el 1 de septiembre de 2026 con autenticación real de Supabase y el frontend servido por Nginx.

> Seguridad: nunca suban a Git `.env`, `Producto/tag-ok-app/local.properties`, claves `sb_secret_`, `service_role`, tokens secretos de Mapbox ni contraseñas reales. La clave pública/`anon` de Supabase se usa en el cliente; la clave secreta solo puede vivir en Supabase Edge Functions o servicios backend seguros.

## 1. Inicio rápido

### Si el PC ya fue configurado

1. Abrir Docker Desktop y esperar a que el motor esté listo.
2. Abrir PowerShell en la raíz del repositorio.
3. Ejecutar:

```powershell
cd Producto
docker compose --env-file ..\.env up -d
```

4. Revisar los contenedores:

```powershell
docker compose --env-file ..\.env ps
```

5. Abrir:

- Login del panel: `http://localhost/login`
- Panel web: `http://localhost`
- Swagger: `http://localhost:8080/swagger-ui.html`

No hay que volver a importar calles ni pórticos cada día. Esos datos permanecen en los volúmenes de Docker.

### Si es la primera vez en ese PC

Seguir, en orden, las secciones 3 a 10:

1. Instalar requisitos.
2. Clonar el repositorio y comprobar los archivos.
3. Crear `.env`.
4. Preparar Supabase y un usuario administrador.
5. Construir los contenedores.
6. Importar la red vial una sola vez.
7. Cargar autopistas y pórticos una sola vez.
8. Validar el sistema.

## 2. Componentes y direcciones

| Componente | Tecnología | Acceso local |
|---|---|---|
| Panel administrativo | React + Vite + Nginx | `http://localhost` |
| Login del panel | Supabase Auth | `http://localhost/login` |
| API Gateway | Spring Boot / WebFlux | `http://localhost:8080` |
| Swagger | OpenAPI | `http://localhost:8080/swagger-ui.html` |
| Servicio de rutas | Spring Boot | Solo mediante el Gateway |
| Servicio de historial | Spring Boot | Solo mediante el Gateway |
| PostgreSQL + PostGIS + pgRouting | Base de rutas | `localhost:5431` desde Windows |
| MongoDB | Base de historial | `localhost:5678` desde Windows |
| Kafka | Broker de eventos | `localhost:29092` desde Windows |
| pgAdmin | Administración PostgreSQL | `http://localhost:1000` |
| Mongo Express | Administración MongoDB | `http://localhost:8002` |
| Aplicación móvil | Kotlin + Jetpack Compose | Emulador o teléfono Android |

El servicio web de Docker Compose se llama `frontend-tag`. No usar el nombre antiguo `frontend`.

## 3. Requisitos

Para levantar web y backend:

- Windows 10 u 11 de 64 bits.
- Virtualización habilitada en BIOS/UEFI.
- Docker Desktop con contenedores Linux.
- Git.
- Al menos 15 GB libres.

Para trabajar sin Docker también pueden ser útiles Java JDK 21 y Node.js 20 o superior, pero Docker ya compila el frontend y los servicios Java.

Para la aplicación móvil:

- Android Studio.
- Android SDK Platform 36.
- Android Emulator e imagen Google APIs x86_64 API 36.
- Tokens de Mapbox autorizados.

Comprobar las herramientas principales:

```powershell
docker --version
docker compose version
git --version
java -version
node --version
```

## 4. Clonar y comprobar el repositorio

La URL actual del repositorio es:

```text
https://github.com/JazminHerrera2/CAPSTOM_EC_DM_AC.git
```

Clonar desde PowerShell:

```powershell
cd C:\Users\TU_USUARIO\Documents\GitHub
git clone https://github.com/JazminHerrera2/CAPSTOM_EC_DM_AC.git
cd CAPSTOM_EC_DM_AC
```

Comprobar la rama que usa el equipo antes de hacer cambios:

```powershell
git branch --show-current
git status
```

Esta copia fue validada en la rama `dev`.

### Comprobar punteros Git LFS

En el estado actual del repositorio los JSON y archivos de configuración contienen sus datos reales; Git no informa objetos LFS registrados y la búsqueda de punteros devuelve cero resultados.

Después de clonar, comprobar igualmente:

```powershell
rg -l "^version https://git-lfs.github.com/spec/v1$" . --hidden -g "!.git/**"
```

El resultado esperado es que no aparezca ningún archivo. Si otra rama o una copia antigua muestra punteros, instalar Git LFS y ejecutar:

```powershell
git lfs install
git lfs pull
```

Un archivo de aproximadamente 130 bytes que comienza con `version https://git-lfs.github.com/spec/v1` no contiene el JSON o código real.

## 5. Crear y configurar `.env`

Desde la raíz del repositorio:

```powershell
Copy-Item .env.example .env
```

Completar `.env` con esta estructura. No copiar literalmente los placeholders:

```dotenv
SERVER_PORT=8080

SUPABASE_URL=https://ID_REAL_DEL_PROYECTO.supabase.co
SUPABASE_ANON_KEY=CLAVE_PUBLICA_O_ANON_REAL
SUPABASE_JWT_ISSUER_URI=https://ID_REAL_DEL_PROYECTO.supabase.co/auth/v1
AUTH_EXTERNAL_ENABLED=true

MONGODB_URI=mongodb://admin:admin@db-historial:27017/historial_db?authSource=admin

POSTGRES_DB=db_rutas
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin

KAFKA_BOOTSTRAP_SERVERS=kafka-tag:9092

GEMINI_API_KEY=
GEMINI_MODEL=gemini-2.5-flash
```

Reglas importantes:

- `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_JWT_ISSUER_URI` deben pertenecer al mismo proyecto.
- Obtener la URL desde Supabase en `Connect` o `Settings → Data API`.
- Para `SUPABASE_ANON_KEY` usar la clave pública/`anon` del cliente. Puede tener formato legado JWT (`eyJ...`) o el formato público nuevo (`sb_publishable_...`).
- Nunca poner `sb_secret_...` ni `service_role` en este `.env`, porque su clave pública se incorpora al frontend durante la compilación.
- `AUTH_EXTERNAL_ENABLED=true` activa la validación JWT externa del Gateway.
- `AUTH_EXTERNAL_ENABLED=false` es solo contingencia técnica; no crea un administrador local y el panel seguirá necesitando una sesión real.
- Dentro de Docker se usan `db-historial`, `db-rutas` y `kafka-tag`, no `localhost`.
- Gemini es opcional para el arranque básico.

Comprobar que Git ignora el archivo:

```powershell
git check-ignore .env
```

Debe devolver `.env`.

## 6. Preparar Supabase

El panel ya no usa `admin@local.dev`. Incluso en `localhost` exige un usuario real de Supabase.

### 6.1 Ver o crear usuarios

1. Abrir el proyecto correcto en Supabase.
2. Entrar a `Authentication → Users`.
3. Comprobar que exista el usuario que iniciará sesión.
4. Si no existe, usar `Add user` o enviar una invitación.
5. Confirmar el correo si el proveedor de email lo exige.

Los usuarios de Supabase Dashboard son integrantes del proyecto; no son necesariamente usuarios que puedan iniciar sesión en TAG OK. Las cuentas de la aplicación están en `Authentication → Users`.

### 6.2 Comprobar el superadministrador

En `SQL Editor`, listar usuarios y roles:

```sql
select
  id,
  email,
  raw_app_meta_data ->> 'role' as rol,
  created_at,
  last_sign_in_at
from auth.users
order by created_at;
```

Mostrar solamente administradores principales:

```sql
select
  id,
  email,
  raw_app_meta_data ->> 'role' as rol,
  last_sign_in_at
from auth.users
where raw_app_meta_data ->> 'role' in ('super_admin', 'admin');
```

El proyecto reconoce:

- `super_admin`: acceso completo.
- `admin`: nombre legado, tratado como `super_admin`.
- `admin_operacional`: concesionarios, pórticos, tarifas y carga masiva; no gestiona usuarios.

### 6.3 Crear el primer `super_admin`

Solo si todavía no existe ninguno, reemplazar el correo y ejecutar una vez en `SQL Editor`:

```sql
update auth.users
set raw_app_meta_data =
  coalesce(raw_app_meta_data, '{}'::jsonb)
  || '{"role":"super_admin"}'::jsonb
where email = 'CORREO_REAL_DEL_ADMIN'
returning id, email, raw_app_meta_data ->> 'role' as rol;
```

La consulta debe devolver exactamente un usuario. Si devuelve cero, revisar el correo. Después cerrar sesión en TAG OK y volver a entrar para obtener un JWT actualizado con el rol nuevo.

### 6.4 Edge Functions para administrar usuarios

La página `http://localhost/usuarios` usa estas funciones remotas:

- `list-users`
- `update-user-role`
- `update-user-status`

Revisarlas en Supabase en `Edge Functions`. Si ya están desplegadas, no repetir este paso.

Si no existen, instalar Supabase CLI, iniciar sesión y enlazar el proyecto:

```powershell
cd Producto
supabase login
supabase link --project-ref ID_REAL_DEL_PROYECTO
```

Las funciones usan un secreto llamado `SERVICE_ROLE_KEY`. Configurarlo con la clave secreta del proyecto, sin guardarla en Git ni en el frontend:

```powershell
supabase secrets set SERVICE_ROLE_KEY="CLAVE_SECRETA_REAL" --project-ref ID_REAL_DEL_PROYECTO
```

Desplegar:

```powershell
supabase functions deploy list-users --project-ref ID_REAL_DEL_PROYECTO
supabase functions deploy update-user-role --project-ref ID_REAL_DEL_PROYECTO
supabase functions deploy update-user-status --project-ref ID_REAL_DEL_PROYECTO
```

Solo un `super_admin` puede listar usuarios, modificar roles o activar/desactivar cuentas desde el panel.

## 7. Construir y levantar Docker

1. Abrir Docker Desktop.
2. Esperar hasta que indique que el motor está funcionando.
3. Desde la raíz del repositorio ejecutar:

```powershell
cd Producto
docker compose --env-file ..\.env up -d --build
```

La primera compilación puede tardar varios minutos.

Revisar:

```powershell
docker compose --env-file ..\.env ps
```

Deben aparecer ejecutándose:

- `db-rutas`
- `db-historial`
- `zookeeper-tag`
- `kafka-tag`
- `routes-service`
- `history-service`
- `gateway-service`
- `frontend-tag`

`kafka-setup-tag` es una tarea de inicialización; es normal que termine con `Exited (0)`.

Después de cambiar `.env`, autenticación, frontend o Dockerfile, reconstruir los servicios afectados:

```powershell
docker compose --env-file ..\.env up -d --build gateway-service frontend-tag
```

El frontend recibe `SUPABASE_URL` y `SUPABASE_ANON_KEY` como variables Vite durante la compilación. Reiniciar sin `--build` no aplica cambios de esas dos variables al JavaScript ya compilado.

## 8. Importar la red vial una sola vez

Este paso solo se ejecuta al crear por primera vez el volumen `postgres_data`. Si `edge` ya contiene datos, no repetirlo.

Todos los comandos de esta sección se ejecutan desde `Producto`.

### 8.1 Comprobar si ya está cargada

```powershell
docker exec db-rutas psql -U admin -d db_rutas -c "SELECT COUNT(*) AS edges FROM edge;"
```

Si la tabla existe y el conteo es cercano a 50.749, saltar a la sección 9.

### 8.2 Crear estructura pgRouting

```powershell
docker cp osm-importer/src/main/resources/database-scripts/01_extensions.sql db-rutas:/tmp/01_extensions.sql
docker cp osm-importer/src/main/resources/database-scripts/02_edge_table.sql db-rutas:/tmp/02_edge_table.sql
docker cp osm-importer/src/main/resources/database-scripts/03_indexes.sql db-rutas:/tmp/03_indexes.sql

docker exec db-rutas psql -U admin -d db_rutas -f /tmp/01_extensions.sql
docker exec db-rutas psql -U admin -d db_rutas -f /tmp/02_edge_table.sql
docker exec db-rutas psql -U admin -d db_rutas -f /tmp/03_indexes.sql
```

No ejecutar `00_clean_tables.sql`, `Producto/sql/script.sql` ni otro script de limpieza sobre una base con información.

### 8.3 Importar calles

```powershell
docker cp sql/calles.sql db-rutas:/tmp/calles.sql
docker exec db-rutas psql -U admin -d db_rutas -f /tmp/calles.sql
```

`calles.sql` pesa aproximadamente 54 MB y puede tardar.

### 8.4 Crear topología

```powershell
docker cp sql/createTopology.sql db-rutas:/tmp/createTopology.sql
docker exec db-rutas psql -U admin -d db_rutas -f /tmp/createTopology.sql
```

Validar:

```powershell
docker exec db-rutas psql -U admin -d db_rutas -c "SELECT COUNT(*) AS edges FROM edge;"
docker exec db-rutas psql -U admin -d db_rutas -c "SELECT COUNT(*) AS vertices FROM edge_vertices_pgr;"
docker exec db-rutas psql -U admin -d db_rutas -c "SELECT COUNT(*) AS edges_sin_topologia FROM edge WHERE source IS NULL OR target IS NULL;"
```

Resultado de referencia utilizado durante la configuración:

- `edges`: 50.749
- `vertices`: 56.797
- `edges_sin_topologia`: 0

## 9. Cargar autopistas y pórticos una sola vez

Los archivos reales están en `Producto/porticos`.

1. Iniciar sesión en `http://localhost/login`.
2. Abrir `Carga masiva`.
3. Importar las concesionarias/autopistas desde los JSON correspondientes.
4. Importar pórticos si todavía no vienen incluidos en la operación utilizada.
5. Revisar `Concesionarios`, `Pórticos`, `Tarifas` y `Mapa`.

También existe el endpoint:

```text
POST http://localhost:8080/api/routes/v1/porticos/bulk
Content-Type: application/json
```

Comprobar la carga:

```powershell
curl.exe http://localhost:8080/api/routes/v1/autopistas
curl.exe http://localhost:8080/api/routes/v1/porticos
```

Si devuelven `[]`, los servicios funcionan pero los datos todavía no fueron cargados. En la configuración validada se observaron 5 autopistas y 105 pórticos.

## 10. Validación final

Ejecutar desde PowerShell:

```powershell
curl.exe -I http://localhost/
curl.exe -I http://localhost/login
curl.exe -I http://localhost:8080/swagger-ui.html
curl.exe http://localhost:8080/api/routes/v1/autopistas
curl.exe http://localhost:8080/api/routes/v1/porticos
```

Resultados esperados:

- `/` y `/login` responden `200`.
- El Gateway y Swagger están disponibles.
- La pantalla de login acepta un usuario de `Authentication → Users`.
- Después del login existe una sesión Supabase real.
- Un `super_admin` puede abrir `/usuarios`.
- Al recargar directamente `/login`, `/usuarios` u otra ruta React no aparece 404; esto lo resuelve `Producto/routes-ui/nginx.conf`.

Credenciales locales de pgAdmin:

```text
URL: http://localhost:1000
Correo: admin@admin.com
Contraseña: admin
```

Registrar PostgreSQL dentro de pgAdmin con:

```text
Host: db-rutas
Puerto: 5432
Base de datos: db_rutas
Usuario: admin
Contraseña: admin
```

Desde Windows se usa `localhost:5431`; desde otro contenedor, `db-rutas:5432`.

## 11. Aplicación Android

### 11.1 Emulador recomendado

Configuración probada:

- Android SDK Platform 36.
- Imagen Google APIs Intel x86_64 API 36.
- Dispositivo Pixel 7.
- AVD `TagOk_Pixel_7_API_36`.

Administrarlo desde `Tools → Device Manager` en Android Studio.

### 11.2 Abrir el proyecto correcto

Abrir:

```text
Producto/tag-ok-app
```

No abrir únicamente `Producto/tag-ok-app/app`, porque Gradle necesita la raíz.

### 11.3 Crear `local.properties`

Crear o editar `Producto/tag-ok-app/local.properties`:

```properties
sdk.dir=C\:\\Users\\TU_USUARIO\\AppData\\Local\\Android\\Sdk
SDK_REGISTRY_TOKEN=TOKEN_SECRETO_MAPBOX_CON_DOWNLOADS_READ
MAPBOX_ACCESS_TOKEN=TOKEN_PUBLICO_MAPBOX
```

- `SDK_REGISTRY_TOKEN` normalmente comienza con `sk.` y permite descargar el SDK privado; necesita `DOWNLOADS:READ`.
- `MAPBOX_ACCESS_TOKEN` normalmente comienza con `pk.` y se usa dentro de la aplicación.
- No subir `local.properties`.

### 11.4 Configurar el Gateway

Editar:

```text
Producto/tag-ok-app/app/src/main/java/com/tagok/app/data/remote/ApiConfig.kt
```

Para el emulador Android oficial:

```kotlin
private const val GATEWAY_URL: String = "http://10.0.2.2:8080/api"
```

Para un teléfono físico en la misma red:

```kotlin
private const val GATEWAY_URL: String = "http://IP_LAN_DEL_PC:8080/api"
```

Obtener la IP con `ipconfig` y permitir el puerto 8080 en Firewall de Windows. La IP `192.168.1.10` que aparece actualmente en el código es un ejemplo y puede no corresponder al PC usado.

### 11.5 Ejecutar

1. Confirmar que Docker y `gateway-service` están funcionando.
2. Iniciar el AVD.
3. Esperar el arranque completo de Android.
4. Seleccionar el dispositivo en Android Studio.
5. Ejecutar `Run`.

El primer Gradle Sync puede tardar mientras descarga dependencias.

## 12. Inicio, detención y reconstrucción

Iniciar sin recompilar:

```powershell
cd Producto
docker compose --env-file ..\.env up -d
```

Detener conservando contenedores y datos:

```powershell
docker compose --env-file ..\.env stop
```

Volver a iniciar contenedores detenidos:

```powershell
docker compose --env-file ..\.env start
```

Eliminar contenedores y red conservando volúmenes:

```powershell
docker compose --env-file ..\.env down
```

Reconstruir todo después de cambios de código o configuración:

```powershell
docker compose --env-file ..\.env up -d --build
```

> No ejecutar `docker compose down -v` salvo que realmente se quiera borrar PostgreSQL, MongoDB y toda la red vial. Esa eliminación obliga a repetir las secciones 8 y 9.

## 13. Logs y solución de problemas

### Ver logs

```powershell
docker compose --env-file ..\.env logs --tail 200
docker compose --env-file ..\.env logs -f gateway-service
docker compose --env-file ..\.env logs -f routes-service
docker compose --env-file ..\.env logs -f history-service
docker compose --env-file ..\.env logs -f frontend-tag
```

### Docker no conecta

Mensajes frecuentes:

```text
failed to connect to docker API
dockerDesktopLinuxEngine
```

Abrir Docker Desktop y esperar a que el motor termine de iniciar. Confirmar con:

```powershell
docker info
```

### La web no abre

```powershell
docker compose --env-file ..\.env ps
docker compose --env-file ..\.env logs --tail 100 frontend-tag gateway-service
```

Revisar que el puerto 80 no esté ocupado por IIS, Apache u otro servidor.

### `/login` devuelve 404 al recargar

La imagen debe incluir `Producto/routes-ui/nginx.conf`. Reconstruir el frontend:

```powershell
docker compose --env-file ..\.env up -d --build --no-deps frontend-tag
```

### El login rechaza el correo o contraseña

- Confirmar que la cuenta exista en `Authentication → Users` del proyecto correcto.
- Confirmar que el email esté verificado.
- Verificar que `.env` apunte al mismo proyecto que el Dashboard.
- Después de cambiar `.env`, reconstruir `frontend-tag`.
- No intentar iniciar sesión con un integrante del Dashboard si no existe también como usuario de Auth.

### El usuario entra, pero no ve secciones administrativas

Comprobar `raw_app_meta_data.role` con las consultas de la sección 6. Después de asignar un rol, cerrar sesión y volver a entrar para renovar el JWT.

### `/usuarios` no carga o responde 401/403

- El usuario debe tener `app_metadata.role = super_admin` o el rol legado `admin`.
- Confirmar que las tres Edge Functions estén desplegadas.
- Confirmar que exista el secreto remoto `SERVICE_ROLE_KEY`.
- Revisar logs en Supabase `Edge Functions → Logs`.
- Cerrar sesión y volver a entrar después de modificar roles.

### El panel abre, pero pórticos, autopistas o tarifas aparecen vacíos

```powershell
docker compose --env-file ..\.env ps
docker compose --env-file ..\.env logs --tail 150 gateway-service routes-service
curl.exe http://localhost:8080/api/routes/v1/autopistas
curl.exe http://localhost:8080/api/routes/v1/porticos
```

Si la API devuelve `[]`, realizar la carga de la sección 9. Si muestra error de tabla o ruteo, revisar la sección 8.

### El Gateway falla al conectar con Supabase

- Revisar las tres variables Supabase del `.env`.
- Confirmar que `AUTH_EXTERNAL_ENABLED=true`.
- Verificar Internet y que el proyecto Supabase no esté pausado.
- Reconstruir:

```powershell
docker compose --env-file ..\.env up -d --build gateway-service frontend-tag
```

### Android no conecta

- Emulador oficial: usar `10.0.2.2`, no `localhost`.
- Teléfono físico: usar la IP LAN del PC.
- Confirmar que `http://localhost:8080/swagger-ui.html` abra en el PC.
- Permitir el puerto 8080 en el Firewall para un teléfono físico.

### Gradle no descarga Mapbox

Confirmar `SDK_REGISTRY_TOKEN` con permiso `DOWNLOADS:READ`. El token público `pk.` no reemplaza al token secreto de descarga.

### Aparece contenido Git LFS en lugar del archivo

Buscar punteros:

```powershell
rg -l "^version https://git-lfs.github.com/spec/v1$" . --hidden -g "!.git/**"
```

Si aparecen archivos y la rama realmente usa LFS:

```powershell
git lfs install
git lfs pull
```

## 14. Archivos locales y cambios actuales

Archivos importantes:

- `.env`: credenciales y conexiones locales; ignorado por Git.
- `Producto/docker-compose.yml`: pasa Supabase al Gateway y al build de Vite.
- `Producto/routes-ui/src/app/lib/supabase.ts`: crea el cliente usando variables Vite.
- `Producto/routes-ui/src/app/context/AuthContext.tsx`: usa exclusivamente sesiones reales.
- `Producto/routes-ui/nginx.conf`: fallback de rutas React.
- `Producto/routes-ui/dockerfile`: compila variables públicas e instala la configuración Nginx.
- `Producto/tag-ok-app/local.properties`: SDK y tokens Mapbox; ignorado por Git.
- `Producto/tag-ok-app/app/src/main/java/com/tagok/app/data/remote/ApiConfig.kt`: URL local del Gateway para Android.

Antes de compartir cambios:

```powershell
git status
git diff --check
git diff
```

No ejecutar `git add .` sin revisar que no haya credenciales. Agregar solo los archivos esperados, crear un commit descriptivo y subir a la rama acordada por el equipo.

## 15. Checklist

### Primera configuración

```text
[ ] Clonar el repositorio y confirmar la rama
[ ] Confirmar cero punteros Git LFS
[ ] Crear .env sin claves secretas
[ ] Configurar Supabase real y AUTH_EXTERNAL_ENABLED=true
[ ] Crear/verificar usuario de Authentication
[ ] Confirmar o crear el primer super_admin
[ ] Confirmar las tres Edge Functions
[ ] Abrir Docker Desktop
[ ] Ejecutar docker compose up -d --build
[ ] Importar calles/topología solo si edge está vacía
[ ] Cargar autopistas y pórticos solo si las APIs están vacías
[ ] Abrir http://localhost/login
[ ] Probar panel, Swagger y APIs
[ ] Configurar Android si corresponde
```

### Uso diario

```text
[ ] Abrir Docker Desktop
[ ] cd Producto
[ ] docker compose --env-file ..\.env up -d
[ ] docker compose --env-file ..\.env ps
[ ] Abrir http://localhost/login
[ ] No volver a importar datos si los volúmenes ya existen
```

Con esto quedan disponibles el panel web, autenticación real de Supabase, Gateway, servicios, bases de datos y la infraestructura local de TAG OK.