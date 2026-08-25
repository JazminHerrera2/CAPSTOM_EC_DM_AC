# Guía de arranque local de TAG OK

Esta guía explica cómo levantar en Windows el backend, las bases de datos, el panel web y la aplicación Android de TAG OK.

> Importante: nunca compartan ni suban a Git los archivos `.env` y `Producto/tag-ok-app/local.properties`. Contienen o pueden contener credenciales.

## 1. Arquitectura que se levanta

| Componente | Tecnología | Acceso local |
|---|---|---|
| Panel administrativo | React + Vite + Nginx | `http://localhost` |
| API Gateway | Spring Boot / WebFlux | `http://localhost:8080` |
| Swagger | OpenAPI | `http://localhost:8080/swagger-ui.html` |
| Servicio de rutas | Spring Boot | Solo mediante el Gateway |
| Servicio de historial | Spring Boot | Solo mediante el Gateway |
| PostgreSQL + PostGIS + pgRouting | Base de rutas | `localhost:5431` |
| MongoDB | Base de historial | `localhost:5678` |
| Kafka | Broker de eventos | `localhost:29092` desde el PC |
| pgAdmin | Administración PostgreSQL | `http://localhost:1000` |
| Mongo Express | Administración MongoDB | `http://localhost:8002` |
| Aplicación móvil | Kotlin + Jetpack Compose | Emulador Android |

El nombre del servicio web en Docker Compose es `frontend-tag`. Algunos documentos antiguos lo llaman `frontend`, pero ese nombre no existe en el archivo Compose actual.

## 2. Qué se hizo para levantar esta copia

Para dejar funcionando esta copia del proyecto se realizaron estas tareas:

1. Se revisó el `README.md` y la arquitectura del repositorio.
2. Se verificó que Java 21 y Node.js estuvieran instalados.
3. Se instaló Docker Desktop y se comprobó que pudiera ejecutar contenedores Linux.
4. Se creó el `.env` de la raíz con las conexiones internas de Docker.
5. Se detectó que la copia descargada no tenía metadata de Git y contenía archivos que eran solamente punteros de Git LFS.
6. Se reconstruyeron los archivos del frontend que faltaban: `package.json`, `package-lock.json` y los archivos `tsconfig`.
7. Se añadió un modo local para que el Gateway no dependa de Supabase durante el arranque.
8. Se añadió un usuario administrador local en el panel web cuando se abre desde `localhost`.
9. Se construyeron y levantaron las imágenes de frontend, Gateway, servicios, bases de datos y Kafka.
10. Se creó la tabla vial de pgRouting y se importó `Producto/sql/calles.sql`.
11. Se generó la topología vial. La importación dejó aproximadamente 50.749 aristas y 56.797 vértices.
12. Se validaron la web, Swagger y los endpoints de rutas.
13. Se instaló Android Studio, Android SDK API 36 y el emulador oficial.
14. Se creó el dispositivo virtual `TagOk_Pixel_7_API_36` y se validó su primer arranque.

El modo local es únicamente para desarrollo. En producción se debe reactivar la autenticación externa y configurar un proyecto Supabase válido.

## 3. Requisitos previos

Cada integrante necesita:

- Windows 10 u 11 de 64 bits.
- Virtualización habilitada en BIOS/UEFI.
- Docker Desktop.
- Git y Git LFS.
- Java JDK 21.
- Node.js 20 o superior.
- Android Studio si desarrollará o probará la aplicación móvil.
- Al menos 15 GB libres para imágenes Docker, Android SDK y emulador.

Comprobar versiones en PowerShell:

```powershell
docker --version
docker compose version
git --version
git lfs version
java -version
node --version
```

Para el arranque con Docker no es obligatorio instalar Maven ni ejecutar `npm install` en Windows: las imágenes Docker compilan los servicios.

## 4. Obtener correctamente el repositorio y Git LFS

La forma recomendada es clonar el repositorio real, no descargar un ZIP:

```powershell
git lfs install
git clone URL_DEL_REPOSITORIO
cd tag-ok-mvp-main
git lfs pull
```

Para comprobar si quedaron punteros de Git LFS sin descargar:

```powershell
rg -l "^version https://git-lfs.github.com/spec/v1$" Producto
```

Si el comando muestra archivos JSON de `Producto/porticos` o de `datos-calles`, todavía no contienen los datos reales. Ejecuten `git lfs pull` desde una clonación que tenga acceso al repositorio remoto.

En esta copia los 50 JSON que habían llegado como punteros fueron recuperados desde el repositorio oficial `https://github.com/diegoiarm/tag-ok-mvp`. Aun así, una clonación nueva debe ejecutar `git lfs pull`; de lo contrario, volverá a recibir solamente los punteros.

## 5. Crear el archivo `.env`

Desde la raíz del proyecto:

```powershell
Copy-Item .env.example .env
```

Editar `.env` y dejar, como mínimo, esta configuración local:

```dotenv
SERVER_PORT=8080

# En modo local pueden ser placeholders válidos.
# Para autenticación real deben usar los valores del proyecto Supabase.
SUPABASE_URL=https://TU_PROYECTO.supabase.co
SUPABASE_ANON_KEY=TU_SUPABASE_ANON_KEY
SUPABASE_JWT_ISSUER_URI=https://TU_PROYECTO.supabase.co/auth/v1
AUTH_EXTERNAL_ENABLED=false

MONGODB_URI=mongodb://admin:admin@db-historial:27017/historial_db?authSource=admin

POSTGRES_DB=db_rutas
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin

# Nombre DNS interno de Docker, no localhost.
KAFKA_BOOTSTRAP_SERVERS=kafka-tag:9092

# Gemini es opcional para el arranque básico.
GEMINI_API_KEY=
GEMINI_MODEL=gemini-2.5-flash
```

Reglas importantes:

- No subir `.env` a Git.
- Dentro de Docker se usan los nombres `db-historial`, `db-rutas` y `kafka-tag`, no `localhost`.
- `AUTH_EXTERNAL_ENABLED=false` evita que el Gateway dependa de Supabase en desarrollo local.
- Para probar autenticación real, configurar Supabase y cambiar `AUTH_EXTERNAL_ENABLED=true`.

## 6. Abrir Docker Desktop

Abrir Docker Desktop y esperar hasta que indique que el motor está en ejecución.

Comprobarlo con:

```powershell
docker info
```

Si aparece un error relacionado con `dockerDesktopLinuxEngine` o con una tubería `npipe`, Docker Desktop todavía no está abierto o el motor no terminó de iniciar.

## 7. Construir y levantar el proyecto

Desde la raíz:

```powershell
cd Producto
docker compose --env-file ..\.env up -d --build
```

La primera ejecución puede tardar varios minutos porque descarga imágenes y dependencias.

Comprobar el estado:

```powershell
docker compose --env-file ..\.env ps
```

Los contenedores principales deben aparecer como `Up` o `Running`:

- `db-rutas`
- `db-historial`
- `zookeeper-tag`
- `kafka-tag`
- `routes-service`
- `history-service`
- `gateway-service`
- `frontend-tag`

`kafka-setup-tag` es una tarea de inicialización. Es normal que termine con estado `Exited (0)`.

Para levantar solo lo necesario para la web y sus dependencias:

```powershell
docker compose --env-file ..\.env up -d --build frontend-tag
```

## 8. Importar la red vial una sola vez

Este paso solo se realiza al crear por primera vez el volumen de PostgreSQL. Si la tabla `edge` ya tiene datos, no repetirlo.

Todos estos comandos se ejecutan desde `Producto`.

### 8.1 Copiar y ejecutar la estructura de pgRouting

```powershell
docker cp osm-importer/src/main/resources/database-scripts/01_extensions.sql db-rutas:/tmp/01_extensions.sql
docker cp osm-importer/src/main/resources/database-scripts/02_edge_table.sql db-rutas:/tmp/02_edge_table.sql
docker cp osm-importer/src/main/resources/database-scripts/03_indexes.sql db-rutas:/tmp/03_indexes.sql

docker exec db-rutas psql -U admin -d db_rutas -f /tmp/01_extensions.sql
docker exec db-rutas psql -U admin -d db_rutas -f /tmp/02_edge_table.sql
docker exec db-rutas psql -U admin -d db_rutas -f /tmp/03_indexes.sql
```

No usar `00_clean_tables.sql` ni `Producto/sql/script.sql` sobre una base con información: pueden eliminar o entrar en conflicto con tablas ya administradas por Hibernate.

### 8.2 Importar las calles

```powershell
docker cp sql/calles.sql db-rutas:/tmp/calles.sql
docker exec db-rutas psql -U admin -d db_rutas -f /tmp/calles.sql
```

El archivo tiene aproximadamente 54 MB y la importación puede tardar.

### 8.3 Crear la topología

```powershell
docker cp sql/createTopology.sql db-rutas:/tmp/createTopology.sql
docker exec db-rutas psql -U admin -d db_rutas -f /tmp/createTopology.sql
```

Validar cantidades:

```powershell
docker exec db-rutas psql -U admin -d db_rutas -c "SELECT COUNT(*) AS edges FROM edge;"
docker exec db-rutas psql -U admin -d db_rutas -c "SELECT COUNT(*) AS vertices FROM edge_vertices_pgr;"
docker exec db-rutas psql -U admin -d db_rutas -c "SELECT COUNT(*) AS edges_sin_topologia FROM edge WHERE source IS NULL OR target IS NULL;"
```

Con el dump utilizado durante la configuración se obtuvieron:

- `edges`: 50.749
- `vertices`: 56.797
- `edges_sin_topologia`: 0

## 9. Cargar autopistas y pórticos

Los JSON reales están en `Producto/porticos`. En una clonación nueva se deben recuperar mediante Git LFS antes de continuar.

Después pueden cargarlos desde el panel administrativo o mediante el endpoint masivo:

```text
POST http://localhost:8080/api/routes/v1/porticos/bulk
Content-Type: application/json
```

Si `GET /api/routes/v1/porticos` devuelve `[]`, el backend está funcionando, pero aún no se cargaron pórticos.

## 10. Validar que todo funciona

Desde PowerShell:

```powershell
curl.exe -I http://localhost/
curl.exe -I http://localhost:8080/swagger-ui.html
curl.exe http://localhost:8080/api/routes/v1/porticos
curl.exe http://localhost:8080/api/routes/v1/autopistas
```

Direcciones útiles:

- Panel web: `http://localhost`
- Swagger: `http://localhost:8080/swagger-ui.html`
- Gateway: `http://localhost:8080`
- pgAdmin: `http://localhost:1000`
- Mongo Express: `http://localhost:8002`

Credenciales locales de pgAdmin:

```text
Correo: admin@admin.com
Contraseña: admin
```

Al registrar PostgreSQL dentro de pgAdmin se debe usar:

```text
Host: db-rutas
Puerto: 5432
Base de datos: db_rutas
Usuario: admin
Contraseña: admin
```

Desde una aplicación instalada directamente en Windows se usaría `localhost:5431`; desde otro contenedor se usa `db-rutas:5432`.

## 11. Ejecutar la aplicación Android

### 11.1 Emulador recomendado

La configuración probada es:

- Android Studio.
- Android SDK Platform 36.
- Android Emulator.
- Imagen `Google APIs Intel x86_64`, API 36.
- Dispositivo Pixel 7.
- AVD `TagOk_Pixel_7_API_36`.

En Android Studio se puede revisar desde `Tools > Device Manager`.

### 11.2 Abrir el proyecto

En Android Studio seleccionar:

```text
Producto/tag-ok-app
```

No abrir solamente la carpeta `app`; Android Studio necesita la raíz `tag-ok-app` que contiene Gradle.

### 11.3 Configurar `local.properties`

Crear o editar `Producto/tag-ok-app/local.properties`:

```properties
sdk.dir=C\:\\Users\\TU_USUARIO\\AppData\\Local\\Android\\Sdk
SDK_REGISTRY_TOKEN=REEMPLAZAR_CON_TOKEN_SECRETO_DE_DESCARGAS
MAPBOX_ACCESS_TOKEN=REEMPLAZAR_CON_TOKEN_PUBLICO
```

- `SDK_REGISTRY_TOKEN` permite a Gradle descargar las dependencias privadas de Mapbox y debe tener permiso `DOWNLOADS:READ`.
- `MAPBOX_ACCESS_TOKEN` es el token público que usa el mapa dentro de la aplicación.
- No compartir ni subir este archivo.

### 11.4 Configurar la URL del backend

Editar:

```text
Producto/tag-ok-app/app/src/main/java/com/tagok/app/data/remote/ApiConfig.kt
```

Para el emulador oficial Android:

```kotlin
private const val GATEWAY_URL: String = "http://10.0.2.2:8080/api"
```

`10.0.2.2` es el alias del `localhost` del PC anfitrión desde el emulador.

Para un teléfono físico conectado a la misma red Wi-Fi:

```kotlin
private const val GATEWAY_URL: String = "http://IP_LOCAL_DEL_PC:8080/api"
```

En ese caso hay que permitir el puerto 8080 en el Firewall de Windows y reemplazar `IP_LOCAL_DEL_PC` por la IP real obtenida con `ipconfig`.

La copia actual contiene `192.168.1.10`, que es solo un ejemplo y debe cambiarse si no coincide con el PC utilizado.

### 11.5 Ejecutar

1. Verificar que Docker y `gateway-service` estén ejecutándose.
2. Iniciar `TagOk_Pixel_7_API_36` desde Device Manager.
3. Esperar a que Android termine de arrancar.
4. Seleccionar el AVD en la barra superior.
5. Pulsar `Run`.

El primer `Gradle Sync` descargará dependencias y puede tardar varios minutos.

## 12. Detener y volver a iniciar

Detener contenedores conservando las bases de datos:

```powershell
cd Producto
docker compose --env-file ..\.env stop
```

Volver a iniciarlos:

```powershell
docker compose --env-file ..\.env start
```

Detener y eliminar solamente contenedores y red, conservando los volúmenes:

```powershell
docker compose --env-file ..\.env down
```

> No usar `docker compose down -v` salvo que se quiera borrar definitivamente PostgreSQL, MongoDB y toda la carga vial. Después sería necesario repetir la importación.

## 13. Logs y solución de problemas

Ver todos los logs:

```powershell
docker compose --env-file ..\.env logs --tail 200
```

Seguir un servicio específico:

```powershell
docker compose --env-file ..\.env logs -f gateway-service
docker compose --env-file ..\.env logs -f routes-service
docker compose --env-file ..\.env logs -f history-service
docker compose --env-file ..\.env logs -f frontend-tag
```

### Docker no conecta

Síntoma:

```text
failed to connect to docker API
dockerDesktopLinuxEngine
```

Solución: abrir Docker Desktop y esperar a que el motor termine de iniciar.

### La web no abre

Comprobar:

```powershell
docker compose --env-file ..\.env ps
docker compose --env-file ..\.env logs --tail 100 frontend-tag gateway-service
```

Revisar también que el puerto 80 no esté ocupado por IIS, Apache u otro servidor.

### El Gateway falla intentando conectar a Supabase

En desarrollo local comprobar en `.env`:

```dotenv
AUTH_EXTERNAL_ENABLED=false
```

Después reconstruir el Gateway:

```powershell
docker compose --env-file ..\.env up -d --build gateway-service
```

### El frontend muestra login o no reconoce un usuario

El panel crea un usuario local `admin@local.dev` solamente cuando se abre desde `localhost` o `127.0.0.1`. Para otros dominios usa Supabase real.

### Android no conecta al backend

- En emulador usar `10.0.2.2`, no `localhost`.
- En dispositivo físico usar la IP LAN del PC.
- Confirmar que `http://localhost:8080/swagger-ui.html` abre en el PC.
- Confirmar que el Firewall permite conexiones al puerto 8080 si se usa un teléfono físico.

### Gradle no descarga Mapbox

Confirmar que `local.properties` contiene un `SDK_REGISTRY_TOKEN` secreto con permiso de descarga. El token público `pk.` no reemplaza al token secreto de descargas.

### No aparecen calles, autopistas o pórticos

- Calles: comprobar el conteo de `edge` y `edge_vertices_pgr`.
- Pórticos/autopistas: recuperar los JSON reales con Git LFS y cargarlos.
- Un archivo de aproximadamente 130 bytes que comienza con `version https://git-lfs.github.com/spec/v1` es un puntero, no el JSON real.

## 14. Archivos modificados o creados durante la configuración

Los cambios relevantes para el modo local están en:

- `.env`: configuración local, no se debe subir.
- `Producto/docker-compose.yml`: propaga `AUTH_EXTERNAL_ENABLED` al Gateway.
- `Producto/gateway-service/src/main/java/com/tagok/gateway_service/security/SecurityConfig.java`: evita descubrimiento remoto de JWT cuando la autenticación externa está desactivada.
- `Producto/routes-ui/src/app/context/AuthContext.tsx`: usuario administrador local para `localhost`.
- `Producto/routes-ui/package.json` y archivos `tsconfig`: restauración de configuración faltante del frontend.
- `Producto/tag-ok-app/local.properties`: ruta local del SDK y futuras claves Mapbox; no se debe subir.
- `GUIA_ARRANQUE_LOCAL.md`: este documento.

## 15. Checklist rápido para cada día

```text
[ ] Abrir Docker Desktop
[ ] cd Producto
[ ] docker compose --env-file ..\.env up -d
[ ] Revisar docker compose --env-file ..\.env ps
[ ] Abrir http://localhost
[ ] Si se probará Android, abrir el AVD y confirmar ApiConfig.kt
```

Con eso queda disponible el panel web, el Gateway y la infraestructura local. La carga de calles se conserva en el volumen de Docker y no debe repetirse en cada inicio.
