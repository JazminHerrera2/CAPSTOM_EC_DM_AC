# Informe técnico de arquitectura y operación de TAG OK

**Proyecto:** CAPSTOM_EC_DM_AC — TAG OK  
**Fecha de revisión:** 10 de septiembre de 2026  
**Versión del informe:** 1.0  
**Código revisado:** rama `main`, commit `ed20764`, más la configuración local disponible.  
**Entorno:** Windows, Docker Desktop, navegador web y emulador Android.  
**Alcance:** arquitectura implementada, frontend web, aplicación móvil, backend, persistencia, accesos, configuración, operación y alternativas de migración.

**Complemento de diseño:** [Boleta, esquema de Vehículos, Beneficios y pantallas Android](COMPLEMENTO_DISENO_VEHICULOS_BOLETA_TAG_OK.md). Detalla los contratos de extracción y las piezas reutilizables para Mi Vehículo, Mantenciones y Registro Inteligente.

Este documento describe la copia del proyecto revisada y los servicios locales consultados. Distingue entre lo comprobado en ejecución, lo definido en código y las propuestas de mejora. No constituye una certificación de seguridad ni una validación funcional completa del producto.

Las credenciales incluidas corresponden a servicios locales de desarrollo. No se reproducen contraseñas personales, tokens de sesión, claves privadas de Supabase, tokens secretos de Mapbox ni claves de Gemini. Las cuentas y políticas efectivamente desplegadas en el proyecto remoto de Supabase no se auditaron mediante acceso administrativo.

## Índice

1. [Descripción de la plataforma](#1-descripción-de-la-plataforma)
2. [Arquitectura general](#2-arquitectura-general)
3. [Inventario tecnológico](#3-inventario-tecnológico)
4. [Frontend web](#4-frontend-web)
5. [Aplicación Android](#5-aplicación-android)
6. [Backend y APIs](#6-backend-y-apis)
7. [Bases de datos y distribución de la información](#7-bases-de-datos-y-distribución-de-la-información)
8. [Flujos principales](#8-flujos-principales)
9. [Direcciones y credenciales](#9-direcciones-y-credenciales)
10. [Cómo consultar tablas y colecciones](#10-cómo-consultar-tablas-y-colecciones)
11. [Configuración por entorno](#11-configuración-por-entorno)
12. [Arranque, compilación y detención](#12-arranque-compilación-y-detención)
13. [Diagnóstico de problemas](#13-diagnóstico-de-problemas)
14. [Persistencia y respaldos](#14-persistencia-y-respaldos)
15. [Autenticación, autorización y hallazgos](#15-autenticación-autorización-y-hallazgos)
16. [Migración y centralización en Supabase](#16-migración-y-centralización-en-supabase)
17. [Validación realizada y pruebas pendientes](#17-validación-realizada-y-pruebas-pendientes)
18. [Referencias y archivos de consulta](#18-referencias-y-archivos-de-consulta)
19. [Glosario](#19-glosario)

## 1. Descripción de la plataforma

TAG OK permite planificar viajes y controlar gastos de peajes urbanos. Combina un panel web para administración con una aplicación Android orientada a conductores. El backend calcula rutas y tarifas, registra historial y conecta a los clientes con servicios de Supabase.

Las capacidades presentes en el código incluyen gestión de autopistas, pórticos y tarifas; cálculo de rutas; registro de vehículos; presupuestos y alertas; consulta de historial; reportes y auditoría; gestión de usuarios; y comparación de facturas mediante una integración con Gemini.

**El sistema utiliza Supabase, pero no almacena todos sus datos allí.** La implementación actual distribuye la información entre PostgreSQL local, MongoDB local y el PostgreSQL administrado por Supabase. Estos componentes ya existían en el repositorio: no se incorporaron durante el arranque realizado en esta sesión.

El despliegue revisado combina servicios locales con dependencias externas. Aunque las bases de rutas e historial estén encendidas, determinadas funciones requieren internet: inicio de sesión con Supabase, acceso a vehículos y presupuestos, cartografía y geocodificación, y extracción de facturas con Gemini.

## 2. Arquitectura general

La estructura corresponde a una aplicación distribuida por servicios, con un gateway HTTP y comunicación asíncrona para el historial. Docker Compose coordina los servicios locales; Supabase está alojado fuera de ese Compose.

```mermaid
flowchart LR
    WEB["Panel web React\nNginx: localhost:80"]
    APP["App Android\nKotlin y Compose"]
    GW["API Gateway\nlocalhost:8080"]
    ROUTES["routes-service\nRutas y tarifas"]
    HISTORY["history-service\nHistorial y boletas"]
    PG[("PostgreSQL local\ndb_rutas\nPostGIS y pgRouting")]
    MONGO[("MongoDB local\nhistorial_db")]
    KAFKA["Kafka\nportico-cruzado"]
    ZK["ZooKeeper"]
    AUTH["Supabase Auth"]
    REST["Supabase Data API\nVehículos, presupuestos, notificaciones"]
    EDGE["Supabase Edge Functions\nAdministración de usuarios"]
    GEMINI["Gemini\nExtracción de facturas"]
    IMPORT["osm-importer\nCarga inicial de red vial"]
    WEB --> GW
    APP --> GW
    WEB --> AUTH
    APP --> AUTH
    WEB --> EDGE
    GW --> AUTH
    GW --> REST
    GW --> ROUTES
    GW --> HISTORY
    ROUTES --> PG
    ROUTES --> KAFKA
    KAFKA --> HISTORY
    KAFKA --> ZK
    HISTORY --> MONGO
    HISTORY --> GEMINI
    IMPORT --> PG
```

La flecha del gateway hacia Auth representa su dependencia para descubrir la configuración y validar JWT. Las flechas de los clientes hacia Auth representan el inicio de sesión. El panel también llama directamente a Edge Functions: no todo su tráfico pasa por el gateway.

La cartografía queda fuera del diagrama para facilitar su lectura: la web carga teselas de OpenStreetMap con Leaflet; Android integra Mapbox y un cliente de geocodificación Nominatim.

### 2.1 Responsabilidades

| Componente | Responsabilidad | Ubicación |
|---|---|---|
| `routes-ui` | Interfaz de administración, navegación, mapas y consultas | Navegador; archivos servidos por Nginx |
| `tag-ok-app` | Experiencia del conductor, ubicación, planificación e historial | Emulador o dispositivo Android |
| `gateway-service` | Enrutamiento HTTP, integración JWT y acceso a Data API | Docker local, puerto 8080 |
| `routes-service` | Reglas de rutas y tarifas, catálogos, uso y auditoría | Docker local |
| `history-service` | Persistencia y consultas del historial, boletas y comparación | Docker local |
| `osm-importer` | Preparación del grafo vial a partir de archivos OSM | Herramienta de carga; no es un servicio del Compose actual |
| Supabase | Auth, tablas de negocio y funciones de usuarios | Proyecto remoto |
| Kafka y ZooKeeper | Transporte de eventos y coordinación del broker | Docker local |
| pgAdmin y Mongo Express | Herramientas para consultar y administrar bases | Docker local; accesibles por navegador |

pgAdmin y Mongo Express son interfaces de administración; no son bases de datos adicionales.

## 3. Inventario tecnológico

Las versiones de bibliotecas son las declaradas en los manifiestos; un rango como `^19.2.4` no significa que toda instalación futura resuelva exactamente esa versión.

| Capa | Tecnología o versión declarada/verificada |
|---|---|
| Web | React `^19.2.4`, TypeScript `~6.0.2`, Vite `^8.0.4` |
| Datos y navegación web | Axios `^1.15.0`, TanStack React Query `^5.99.1`, React Router `^7.14.2` |
| Diseño web | Tailwind CSS 4, componentes basados en Radix/shadcn, Lucide, Sonner |
| Mapas y reportes web | Leaflet `^1.9.4`, React Leaflet, Recharts, XLSX |
| Auth web | `@supabase/supabase-js` `^2.105.1` |
| Gateway | Java 21, Spring Boot 3.5.14, Spring Cloud 2025.0.2, Gateway WebFlux y Netty |
| Rutas e historial | Java 21, Spring Boot 3.5.13, Spring MVC y Tomcat |
| Persistencia Java | Spring Data JPA/Hibernate Spatial y Spring Data MongoDB |
| Documentación API | Springdoc OpenAPI 2.8.9 |
| PostgreSQL local | Imagen `pgrouting/pgrouting:15-3.3-3.4.1` |
| Extensiones locales verificadas | PostGIS 3.3.4 y pgRouting 3.4.1 |
| MongoDB | Imagen `mongo:7` |
| Mensajería | Imágenes Confluent Kafka y ZooKeeper `7.4.0` |
| Android | Kotlin 2.0.21, Android Gradle Plugin 8.12.0, Gradle 8.13 |
| Interfaz Android | Jetpack Compose, Material 3, Navigation Compose |
| API Android | Ktor 3.0.3, serialización Kotlin, Supabase Kotlin 3.1.4 |
| Mapas Android | Mapbox 11.9.0 y servicios de ubicación de Google |
| Plataforma Android | `compileSdk` 36, `targetSdk` 36 y `minSdk` 26 |
| Compilación Docker | Maven 3.9.9 con Temurin 21; frontend con imagen `node:20` |
| Servidor web | Imagen `nginx:alpine` |

Las imágenes sin versión fija, como `mongo-express`, `dpage/pgadmin4` o `nginx:alpine`, pueden cambiar al descargarlas nuevamente. Para reproducir un entorno con precisión conviene fijar versiones o digests.

## 4. Frontend web

### 4.1 Estructura y comunicación

El código se encuentra en `Producto/routes-ui`. `App.tsx` define las rutas; `AuthContext.tsx` mantiene la sesión; `RutaProtegida.tsx` controla la navegación según sesión y rol. La carpeta `api` encapsula peticiones y los hooks gestionan consultas y actualizaciones con React Query.

`src/api/axios.ts` utiliza la dirección fija `http://localhost:8080/api`. Antes de enviar peticiones obtiene la sesión de Supabase y agrega `Authorization: Bearer <token>`. Sin sesión, ese cliente lanza un error de autenticación.

La página de usuarios usa `src/hooks/useUsuarios.ts`, que llama directamente a tres Edge Functions. **Su URL de Supabase está escrita en ese archivo**, por lo que cambiar únicamente las variables Vite no cambia ese destino.

### 4.2 Pantallas y permisos del cliente

| Ruta | Función | Acceso definido en la web |
|---|---|---|
| `/login` | Inicio de sesión | Público |
| `/` | Inicio | Cualquier sesión activa |
| `/mapa` | Mapa y visualización de rutas | Cualquier sesión activa |
| `/usuarios` | Usuarios, estado y roles | `super_admin` o legado `admin` |
| `/autopistas` | Concesionarios/autopistas | Superadministrador y administrador operacional |
| `/porticos` | Mantenimiento de pórticos | Superadministrador y administrador operacional |
| `/tarifas` | Mantenimiento de tarifas | Superadministrador y administrador operacional |
| `/carga-masiva` | Importación de datos administrativos | Superadministrador y administrador operacional |
| `/reportes` | Reportes | `super_admin` o legado `admin` |
| `/auditoria` | Registros de auditoría | `super_admin` o legado `admin` |
| `/files` | Ruta antigua | Redirige a `/carga-masiva` |

Estos controles de navegación no sustituyen los controles de autorización en los endpoints del servidor; véase la sección 15.

### 4.3 Desarrollo y publicación local

`npm run dev` inicia Vite, normalmente en el puerto 5173. `npm run build` ejecuta TypeScript y genera `dist`; `npm run lint` ejecuta ESLint.

En Docker se compila la aplicación y se copian los archivos a Nginx. El servicio `frontend-tag` publica el puerto 80, de modo que el acceso habitual es `http://localhost`. Nginx devuelve `index.html` para las rutas de la SPA, permitiendo abrir directamente `/login` o `/usuarios`.

Las variables `VITE_SUPABASE_URL` y `VITE_SUPABASE_ANON_KEY` se incorporan durante la compilación. Reiniciar un contenedor existente no recompila el JavaScript ni actualiza estos valores.

## 5. Aplicación Android

El módulo `Producto/tag-ok-app` contiene una aplicación Android nativa con identificador `com.tagok.app`; no se identificó una aplicación iOS equivalente en esta revisión.

La organización incluye pantallas y ViewModels en `ui`, interfaces y clientes HTTP en `data/remote`, repositorios y mapeadores en `data`, reglas en `domain/services` y ensamblado de dependencias mediante `ServiceLocator` y módulos propios.

Las pantallas abarcan login, inicio, mapa, planificación, vehículos, presupuesto, notificaciones, perfil e historial. Los clientes Ktor consumen el gateway; Supabase Auth se utiliza directamente para autenticar al usuario.

### 5.1 Configuraciones que dependen del equipo

| Archivo | Configuración |
|---|---|
| `app/src/main/java/com/tagok/app/SupabaseClient.kt` | URL y clave pública del proyecto Supabase escritas en código |
| `app/src/main/java/com/tagok/app/data/remote/ApiConfig.kt` | Dirección base del gateway |
| `local.properties` | Ruta del SDK y tokens Mapbox; archivo local ignorado por Git |
| `settings.gradle.kts` | Lectura de `SDK_REGISTRY_TOKEN` para descargar dependencias Mapbox |
| `app/build.gradle.kts` | Lectura de `MAPBOX_ACCESS_TOKEN` e incorporación al APK |

La dirección presente en `ApiConfig.kt` durante la revisión es `http://192.168.1.3:8080/api`. Corresponde a la IP LAN del equipo utilizado en la sesión y puede cambiar al conectarse a otra red.

Para el emulador Android oficial puede configurarse `http://10.0.2.2:8080/api`, que permite acceder al equipo anfitrión. En un teléfono físico se utiliza la IP LAN alcanzable del equipo que ejecuta el backend. `localhost` dentro del teléfono identifica al propio teléfono.

El manifiesto permite HTTP sin cifrar mediante `usesCleartextTraffic=true`, coherente con el entorno local. Una publicación fuera del entorno de desarrollo requiere revisar el uso de HTTPS.

### 5.2 Mapas, ubicación y alertas

Mapbox se utiliza para el mapa móvil. `GeocodingRepository.kt` consulta Nominatim para buscar direcciones. Existen componentes de geolocalización y geofencing, cuyo funcionamiento depende de los permisos Android y de pruebas sobre el dispositivo objetivo.

`AlertaService.kt` compara los presupuestos almacenados en Supabase con el gasto mensual consultado al servicio de historial. Crea notificaciones cuando se alcanzan los umbrales configurados; `HomeViewModel` invoca esa revisión. No debe describirse este mecanismo como un servicio central de notificaciones push siempre activo: la lógica revisada se ejecuta desde la aplicación.

## 6. Backend y APIs

### 6.1 Gateway

`gateway-service` recibe solicitudes en `http://localhost:8080`. Su archivo `application.yml` define la siguiente distribución:

| Prefijo público | Destino | Transformación |
|---|---|---|
| `/api/routes/**` | `routes-service:8080` | Elimina `/api/routes` |
| `/api/history/**` | `history-service:8080` | Elimina `/api/history` |
| `/api/vehiculos/**` | Supabase | Elimina dos segmentos y agrega `/rest/v1` |
| `/api/presupuesto/**` | Supabase | Elimina dos segmentos y agrega `/rest/v1` |
| `/api/notificaciones/**` | Supabase | Elimina dos segmentos y agrega `/rest/v1` |
| `/routes/v3/api-docs` | Documentación de rutas | Reescribe a `/v3/api-docs` |
| `/history/v3/api-docs` | Documentación de historial | Reescribe a `/v3/api-docs` |

Ejemplos de las rutas efectivamente construidas por Android:

- `/api/vehiculos/vehiculos` termina en `/rest/v1/vehiculos`.
- `/api/presupuesto/presupuesto` termina en `/rest/v1/presupuesto`.
- `/api/notificaciones/notificacion` termina en `/rest/v1/notificacion`.

La repetición de nombres es consecuencia de la configuración actual. El gateway agrega la cabecera `apikey` para las rutas de Supabase y la sesión del usuario viaja mediante el token Bearer.

### 6.2 Servicio de rutas

`routes-service` mantiene catálogos, reglas tarifarias y el acceso al grafo vial. Usa JPA para entidades y consultas SQL espaciales para las rutas. `RouteRepository.java` ejecuta `pgr_dijkstra` y funciones PostGIS para construir resultados geográficos e identificar pórticos cercanos al recorrido.

El costo utilizado por el grafo vial y el monto monetario de los peajes son conceptos distintos. Los costos del grafo se preparan con información de distancia, velocidad y factores del tipo de vía; el cálculo de peajes aplica reglas tarifarias y categorías de vehículo. No debe asumirse que toda ruta devuelta representa el menor gasto TAG posible.

El enum actual `TipoCobro` utiliza `PORTICO` y `TRAMO`. Algunos ejemplos de documentación anterior mencionan otros nombres; para integrar una petición deben prevalecer los DTO y OpenAPI de esta versión.

| Método o grupo | Endpoint a través del gateway | Función |
|---|---|---|
| GET/POST | `/api/routes/v1/autopistas` | Listar y crear autopistas |
| POST | `/api/routes/v1/autopistas/import` | Importación de autopistas |
| PUT/DELETE | `/api/routes/v1/autopistas/{id}` | Actualizar o eliminar |
| GET/POST | `/api/routes/v1/porticos` | Listar y crear pórticos |
| GET | `/api/routes/v1/porticos/admin` | Vista administrativa |
| POST | `/api/routes/v1/porticos/bulk` | Carga masiva |
| PUT/PATCH/DELETE | Rutas específicas bajo `/api/routes/v1/porticos/{id}` | Edición, estado y eliminación |
| GET/PUT | `/api/routes/v1/porticos/{id}/tarifas` | Consultar o reemplazar tarifas del pórtico |
| GET | `/api/routes/v1/tramos` | Listar tramos |
| GET/PUT | `/api/routes/v1/tramos/{id}/tarifas` | Tarifas por tramo |
| POST | `/api/routes/v1/rutas` | Calcular ruta |
| POST | `/api/routes/v1/tarifas` | Calcular cruces y publicar el evento de historial |
| GET | `/api/routes/v1/uso/estadisticas` | Estadísticas de uso |
| GET | `/api/routes/v1/auditoria` | Consulta de auditoría |

Esta tabla resume contratos; no reemplaza la documentación de cuerpos y respuestas en Swagger. Un endpoint de cálculo de cruces puede producir efectos de escritura en el historial, por lo que no debe usarse como una comprobación inocua de disponibilidad.

### 6.3 Servicio de historial

`history-service` consume eventos de Kafka y almacena el historial en MongoDB. Expone resúmenes por año, mes y día, filtros por patente/autopista, estadísticas y generación de boletas.

| Método | Endpoint a través del gateway | Función |
|---|---|---|
| GET | `/api/history/v1/historial/years` | Años disponibles para el usuario |
| GET | `/api/history/v1/historial/resumen` | Resumen anual |
| GET | `/api/history/v1/historial/year/{año}` | Detalle del año |
| GET | `/api/history/v1/historial/year/{año}/month/{mes}` | Detalle mensual |
| GET | `/api/history/v1/historial/year/{año}/month/{mes}/day/{dia}` | Detalle diario |
| POST | Rutas de historial terminadas en `/filtrado` y `/resumen-filtrado` | Consultas filtradas |
| GET | `/api/history/v1/historial/patentes` y `/autopistas` | Opciones de filtrado |
| GET | `/api/history/v1/historial/admin/estadisticas` | Estadísticas globales |
| POST | `/api/history/v1/boleta/obtener` | Generar información de boleta |
| POST multipart | `/api/history/v1/boleta/comparar` | Comparar factura adjunta con el historial |

El código también contiene modelos y controladores de `historiales` y `rutas_guardadas`; no se deben confundir con colecciones ya pobladas. La colección encontrada en la base local es `historial_anual`.

### 6.4 Extracción de facturas

El adaptador `GeminiExtractorFactura` recibe la factura para extraer información que luego compara la lógica del backend. Requiere `GEMINI_API_KEY`. El modelo se selecciona mediante `GEMINI_MODEL`; el valor por defecto del código y Compose es `gemini-2.5-flash`, pero una variable local puede sustituirlo.

La configuración admite archivos de hasta 10 MB y peticiones multipart de hasta 12 MB, con un timeout del cliente de Gemini de 60 segundos. La falta de esta integración afecta a la comparación de facturas, no necesariamente a las consultas ordinarias del historial.

### 6.5 Kafka

El tópico `portico-cruzado` se inicializa con tres particiones y factor de replicación uno. `routes-service` publica usando el identificador del usuario como clave; `history-service` consume con el grupo `history-service`.

El servicio `kafka-setup-tag` es una tarea de inicialización. El estado `Exited (0)` significa que finalizó correctamente, no que el sistema esté averiado. El factor de replicación uno corresponde a un único broker y no ofrece redundancia ante su pérdida.

## 7. Bases de datos y distribución de la información

### 7.1 Supabase remoto

**Referencia del proyecto configurado:** `ibafvqmoqeabmziyzifk`.  
**API del proyecto:** `https://ibafvqmoqeabmziyzifk.supabase.co`.

El repositorio identifica estas entidades:

| Entidad | Campos y relación principal |
|---|---|
| `auth.users` | Cuenta, identificador de usuario y metadatos; los roles del panel se leen desde `app_metadata.role` |
| `public.vehiculos` | `id`, `user_id`, patente, tipo, número TAG, alias, indicador principal y fecha |
| `public.presupuesto` | `user_id`, vehículo opcional, monto mensual, umbrales y activación de alertas |
| `public.notificacion` | Usuario, vehículo opcional, tipo, título, cuerpo, umbral, porcentaje, período y estado de lectura |

`vehiculos`, `presupuesto` y `notificacion` referencian usuarios de Auth. La migración de alertas define políticas RLS para que cada usuario gestione sus propias notificaciones y un índice para evitar duplicados por usuario, ámbito, período, umbral y tipo.

**Limitación del inventario:** estas tablas se describen a partir del SQL y del código cliente, no de una inspección administrativa del esquema remoto actual. Deben comprobarse sus políticas y cualquier cambio aplicado directamente en Supabase.

`Producto/supabase/supabase-schema.sql` declara expresamente que es un esquema de referencia y no está destinado a ejecutarse sin revisión. No es una copia de seguridad ni un conjunto completo de migraciones para reconstruir la plataforma.

### 7.2 PostgreSQL local: `db_rutas`

El contenedor `db-rutas` almacena la red vial y las entidades del servicio de rutas. La inspección local encontró las siguientes 14 tablas:

| Tabla | Propósito |
|---|---|
| `autopista` | Catálogo de autopistas |
| `portico` | Pórticos, ubicación y relación con autopistas |
| `tramo` | Tramos de cobro |
| `calendario_tarifario` | Organización temporal de tarifas |
| `rango_horario` | Franjas horarias |
| `regla_temporal` | Condiciones temporales |
| `regla_tarifaria` | Reglas de cobro |
| `regla_tarifaria_vehiculos` | Asociación de reglas con categorías vehiculares |
| `valor_tarifa` | Valores de tarifa |
| `edge` | Segmentos de calle, costos y conectividad del grafo |
| `edge_vertices_pgr` | Vértices del grafo de ruteo |
| `evento_uso` | Eventos utilizados en estadísticas de uso |
| `registro_auditoria` | Registro de operaciones auditadas |
| `spatial_ref_sys` | Sistemas de referencia espacial de PostGIS |

Conteos observados el 10 de septiembre de 2026: **50.749 filas en `edge`, 105 pórticos y 5 autopistas**. Son una fotografía del entorno local, no una garantía de que otra instalación contenga esos datos.

### 7.3 MongoDB local: `historial_db`

MongoDB agrupa registros en colecciones de documentos. En la instalación consultada existe `historial_anual`, vinculada al modelo `HistorialAnualDocument`.

| Campo o estructura | Función |
|---|---|
| `_id` | Identificador formado con usuario y año |
| `usuarioId` | Identificador de la cuenta de Supabase |
| `año` | Año del historial |
| `cantidadCruces` | Total acumulado de cruces |
| `totalAño` | Monto acumulado |
| `meses` | Lista de resúmenes mensuales, con detalles diarios y cruces |

El documento agrupa información jerárquica por usuario y año. Esa elección explica la forma del almacenamiento, pero no obliga a utilizar MongoDB: el mismo dominio puede representarse con tablas relacionales y consultas agregadas.

### 7.4 Relación entre las bases

La vinculación del historial con la cuenta se realiza mediante el identificador de usuario. No existe una clave foránea de MongoDB hacia `auth.users` que haga cumplir esa relación automáticamente.

Crear de nuevo una cuenta con el mismo correo no garantiza conservar su identificador. Una migración debe preservar ese UUID o transformar todas sus referencias; de lo contrario, un usuario puede iniciar sesión y encontrar su historial vacío aunque los documentos antiguos sigan existiendo.

## 8. Flujos principales

### 8.1 Inicio de sesión

1. El usuario ingresa sus credenciales en web o Android.
2. El cliente consulta Supabase Auth y recibe una sesión si las credenciales son válidas.
3. La web obtiene el rol desde los metadatos y habilita las secciones correspondientes.
4. Las peticiones al gateway incorporan el token de acceso.
5. El gateway valida los tokens presentados cuando la validación externa está habilitada y dirige la solicitud.

Este flujo describe solicitudes autenticadas. La configuración actual no exige una sesión para absolutamente todos los endpoints, como se detalla en la sección 15.

### 8.2 Registro de cruces e historial

```mermaid
sequenceDiagram
    participant A as App Android
    participant G as Gateway
    participant R as routes-service
    participant P as PostgreSQL
    participant K as Kafka
    participant H as history-service
    participant M as MongoDB
    A->>G: Cruces y token de usuario
    G->>R: POST /v1/tarifas
    R->>P: Consultar pórticos y reglas
    P-->>R: Datos de cálculo
    R->>K: Publicar portico-cruzado
    R-->>G: Resultado del cálculo
    G-->>A: Tarifa calculada
    K->>H: Entregar evento
    H->>M: Actualizar historial del usuario/año
    A->>G: Consultar historial
    G->>H: Solicitud de resumen
    H->>M: Consultar documentos
    M-->>H: Historial
    H-->>G: Resumen
    G-->>A: Datos para mostrar
```

El guardado del historial es asíncrono: recibir la tarifa no demuestra por sí solo que MongoDB ya contenga el evento. Si Kafka o el consumidor fallan, puede existir un retraso o un registro pendiente. El publicador revisado registra errores de envío; no se identificó allí un mecanismo de outbox que garantice conjuntamente el cálculo y la entrega del evento.

### 8.3 Alertas de presupuesto

La app consulta presupuestos y vehículos de Supabase y gasto del historial en MongoDB a través de los servicios. Evalúa los umbrales, crea la notificación en Supabase y la presenta al usuario. Por ello, esta función depende de ambos almacenes y del mismo identificador de cuenta.

### 8.4 Administración de usuarios

La web llama a `list-users`, `update-user-role` o `update-user-status`. Estas funciones validan la sesión con Supabase Auth, comprueban que el usuario sea `super_admin` o `admin`, y utilizan una clave administrativa únicamente en el entorno de ejecución de la función.

## 9. Direcciones y credenciales

### 9.1 Accesos por navegador

| Plataforma | Dirección | Usuario | Contraseña o condición |
|---|---|---|---|
| Portal TAG OK | [localhost/login](http://localhost/login) | Cuenta de Supabase Auth | Contraseña personal; no hay una contraseña universal documentada |
| pgAdmin | [localhost:1000](http://localhost:1000) | `admin@admin.com` | `admin` |
| Mongo Express | [localhost:8002](http://localhost:8002) | `admin` | `pass`, verificado en los logs de la instancia local |
| Swagger | [localhost:8080/swagger-ui.html](http://localhost:8080/swagger-ui.html) | Sin cuenta separada | Las operaciones que requieren sesión utilizan Bearer según el endpoint |
| Supabase Dashboard | [Proyecto TAG OK](https://supabase.com/dashboard/project/ibafvqmoqeabmziyzifk) | Cuenta personal con acceso al proyecto | Acceso otorgado por la organización/equipo |

La cuenta `tag.ok.mvp@gmail.com` aparece como ejemplo de pruebas en los scripts. Su contraseña no se encontró y su rol administrativo no se confirmó. No debe presentarse como una credencial completa de acceso al portal.

La cuenta del Dashboard de Supabase y la cuenta de TAG OK son identidades de acceso diferentes: ser integrante del proyecto de Supabase no implica existir como usuario en `Authentication → Users`.

### 9.2 Conexiones directas a las bases

| Parámetro | PostgreSQL desde Windows | PostgreSQL desde pgAdmin en Docker | MongoDB desde Windows |
|---|---|---|---|
| Host | `localhost` | `db-rutas` | `localhost` |
| Puerto | `5431` | `5432` | `5678` |
| Base | `db_rutas` | `db_rutas` | `historial_db` |
| Usuario | `admin` | `admin` | `admin` |
| Contraseña | `admin` | `admin` | `admin` |
| Base de autenticación | No aplica | No aplica | `admin` |

URI local para MongoDB Compass u otro cliente compatible:

```text
mongodb://admin:admin@localhost:5678/historial_db?authSource=admin
```

Dentro de la red Docker, MongoDB se encuentra en `db-historial:27017`. La contraseña `pass` de Mongo Express protege la interfaz web; no es la contraseña del usuario de MongoDB.

### 9.3 Puertos internos y publicados

| Servicio | Desde Windows | Dentro de Docker |
|---|---|---|
| Frontend | `localhost:80` | `frontend-tag:80` |
| Gateway | `localhost:8080` | `gateway-service:8080` |
| Rutas | A través del gateway | `routes-service:8080` |
| Historial | A través del gateway | `history-service:8080` |
| PostgreSQL | `localhost:5431` | `db-rutas:5432` |
| MongoDB | `localhost:5678` | `db-historial:27017` |
| Kafka para clientes del host | `localhost:29092` | `kafka-tag:9092` |
| ZooKeeper | No publicado | `zookeeper-tag:2181` |

El puerto Kafka 9092 también está publicado, pero para clientes ejecutados en Windows debe utilizarse el listener 29092, que anuncia direcciones alcanzables desde el host.

## 10. Cómo consultar tablas y colecciones

### 10.1 PostgreSQL mediante pgAdmin

1. Abrir `http://localhost:1000` e ingresar con `admin@admin.com` y `admin`.
2. Si no existe una conexión, seleccionar **Add New Server** o **Servers → Register → Server**.
3. En **General**, asignar el nombre `TAG OK`.
4. En **Connection**, indicar host `db-rutas`, puerto `5432`, maintenance database `db_rutas`, usuario `admin` y contraseña `admin`.
5. Guardar y abrir **Servers → TAG OK → Databases → db_rutas → Schemas → public → Tables**.
6. Hacer clic derecho en una tabla y elegir **View/Edit Data → First 100 Rows**.

Para realizar consultas, abrir **Query Tool** sobre `db_rutas`:

```sql
SELECT * FROM public.autopista LIMIT 20;
SELECT * FROM public.portico LIMIT 20;
SELECT COUNT(*) AS segmentos FROM public.edge;
SELECT extname, extversion FROM pg_extension ORDER BY extname;
```

No utilizar `localhost:5431` como host y puerto de registro dentro del pgAdmin de Docker: esa combinación corresponde a un cliente instalado en Windows.

### 10.2 MongoDB mediante Mongo Express

1. Abrir `http://localhost:8002`.
2. En el diálogo del navegador, ingresar usuario `admin` y contraseña `pass`.
3. Seleccionar la base `historial_db`.
4. Abrir la colección `historial_anual`.
5. Examinar los documentos y expandir sus estructuras de meses, días y cruces.

La interfaz permite editar y borrar; consultar datos no requiere usar esas funciones. Una colección vacía o inexistente en otra instalación puede indicar que aún no se han registrado cruces.

### 10.3 Supabase

1. Ingresar al Dashboard con una cuenta autorizada para el proyecto.
2. Abrir **Table Editor** y consultar las tablas del esquema `public`.
3. Abrir **Authentication → Users** para consultar las cuentas de TAG OK.
4. Revisar **Edge Functions** para el despliegue de las funciones administrativas.

Para listar cuentas y roles desde SQL Editor con permisos administrativos:

```sql
SELECT
  id,
  email,
  raw_app_meta_data ->> 'role' AS rol
FROM auth.users
ORDER BY created_at;
```

Esta consulta es de lectura. La asignación de roles y el restablecimiento de contraseñas deben realizarse como operaciones administrativas explícitas, no como parte de una inspección rutinaria.

### 10.4 Consultas locales por terminal

Ejecutar desde PowerShell con Docker Desktop encendido:

```powershell
docker exec db-rutas psql -U admin -d db_rutas -c '\dt'
docker exec db-rutas psql -U admin -d db_rutas -c 'SELECT COUNT(*) FROM public.edge;'
docker exec db-historial mongosh --quiet --username admin --password admin --authenticationDatabase admin historial_db --eval 'db.getCollectionNames()'
docker exec db-historial mongosh --quiet --username admin --password admin --authenticationDatabase admin historial_db --eval 'db.historial_anual.countDocuments()'
```

## 11. Configuración por entorno

### 11.1 Variables de la raíz del repositorio

El archivo `.env` de la raíz alimenta Docker Compose cuando se pasa explícitamente con `--env-file`. No debe sobrescribirse si ya contiene la configuración del equipo.

| Variable | Consumidor y propósito |
|---|---|
| `SERVER_PORT` | Puerto del gateway; 8080 en este entorno |
| `SUPABASE_URL` | Destino del gateway y argumento de compilación web |
| `SUPABASE_ANON_KEY` | Clave pública para Data API y compilación web |
| `SUPABASE_JWT_ISSUER_URI` | Emisor esperado por la validación de sesiones |
| `AUTH_EXTERNAL_ENABLED` | Activa la validación JWT externa; usar la configuración real de Auth |
| `POSTGRES_DB` | `db_rutas` en la instalación local |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` | Credenciales utilizadas por `routes-service` |
| `MONGODB_URI` | Conexión de `history-service`, usando host interno `db-historial` |
| `KAFKA_BOOTSTRAP_SERVERS` | `kafka-tag:9092` para los servicios Docker |
| `GEMINI_API_KEY` | Secreto del adaptador de extracción de facturas |
| `GEMINI_MODEL` | Modelo solicitado por el adaptador |

En el Compose actual, las credenciales de inicialización de `db-rutas` y `db-historial` están fijadas a `admin`. Cambiar únicamente las variables de los clientes no cambia las credenciales de una base ya inicializada.

### 11.2 Configuración web y móvil

| Ubicación | Observación operativa |
|---|---|
| `routes-ui/src/app/lib/supabase.ts` | Lee las variables `VITE_SUPABASE_*` |
| `routes-ui/src/hooks/useUsuarios.ts` | URL fija de Edge Functions; revisar al cambiar de proyecto |
| `routes-ui/src/api/axios.ts` | API fija en `localhost:8080`; revisar para despliegues remotos |
| `tag-ok-app/.../SupabaseClient.kt` | URL y clave pública fijadas en código |
| `tag-ok-app/.../ApiConfig.kt` | IP/dirección del backend móvil |
| `tag-ok-app/local.properties` | `sdk.dir`, `MAPBOX_ACCESS_TOKEN` y `SDK_REGISTRY_TOKEN` |
| `gateway-service/.../application-local.yml` | Proyecto Supabase y destinos fijados para el perfil local |
| Entorno de Edge Functions | Secreto `SERVICE_ROLE_KEY`; no se coloca en web ni Android |

En este repositorio, modificar `.env` no actualiza todos los destinos. Se necesita revisar también las constantes indicadas.

### 11.3 Ejecución Java fuera de Docker

Los perfiles `local` utilizan `routes-service:8000` e `history-service:8003` sobre Windows; el gateway apunta entonces a `localhost:8000` y `localhost:8003`. Las bases y Kafka pueden seguir en Docker.

Los comandos Maven no cargan automáticamente el `.env` utilizado por Compose. Antes de ejecutar servicios Java por separado deben configurarse las variables del proceso y comprobarse los valores fijos del perfil local. La guía principal de este informe utiliza Docker para evitar mezclar ambos modos.

## 12. Arranque, compilación y detención

### 12.1 Requisitos

Para web y backend: Docker Desktop con motor Linux funcionando y virtualización disponible. Para Android: Android Studio, SDK 36, emulador o dispositivo, JDK compatible y tokens Mapbox configurados.

En la sesión se verificó la compilación Android con **JDK 21**. El intento con el JBR 25.0.2 instalado en Android Studio falló, por lo que no debe suponerse que cualquier JDK del IDE funciona con el Gradle actual.

### 12.2 Arranque cotidiano

Desde la raíz del repositorio:

```powershell
Set-Location Producto
docker compose --env-file ../.env up -d
docker compose --env-file ../.env ps -a
```

Abrir el portal en `http://localhost/login`. El nombre correcto del servicio web es `frontend-tag`.

`depends_on` establece el orden de inicio, pero el Compose actual no define comprobaciones de salud que esperen a que cada dependencia esté lista. Esto puede provocar fallos durante un arranque simultáneo. Docker permite esperar mediante `healthcheck` y `condition: service_healthy`; son mejoras propuestas, no una configuración ya incorporada. [Documentación de Docker](https://docs.docker.com/compose/how-tos/startup-order/).

### 12.3 Reconstruir tras cambios

Desde `Producto`, para reconstruir solamente la web:

```powershell
docker compose --env-file ../.env up -d --build --no-deps frontend-tag
```

Para reconstruir servicios Java modificados:

```powershell
docker compose --env-file ../.env up -d --build gateway-service routes-service history-service
```

Los Dockerfiles Java ejecutan `mvn clean package -DskipTests`: una imagen construida no demuestra que sus pruebas hayan pasado.

### 12.4 Desarrollo web con Vite

Desde la raíz, entrar a `Producto/routes-ui`, instalar las dependencias y ejecutar:

```powershell
npm install
npm run dev
```

El proceso Vite necesita `VITE_SUPABASE_URL` y `VITE_SUPABASE_ANON_KEY`, por ejemplo en un `.env.local` dentro de `routes-ui`. Los argumentos que utiliza Docker no configuran automáticamente este proceso. La URL habitual es `http://localhost:5173`; confirmar la dirección que imprima Vite.

### 12.5 Compilar e iniciar Android

Abrir `Producto/tag-ok-app` en Android Studio, seleccionar un JDK 21 compatible, revisar los archivos locales y ejecutar la app sobre un dispositivo disponible.

Alternativa por PowerShell, desde la raíz, adaptando las rutas si las herramientas están instaladas en otro lugar:

```powershell
Set-Location Producto/tag-ok-app
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-21'
.\gradlew.bat assembleDebug --console=plain
```

Si la compilación termina correctamente, el APK queda en `app/build/outputs/apk/debug/app-debug.apk`.

El emulador disponible en el equipo revisado se llama `TagOk_Pixel_7_API_36`. Para iniciarlo:

```powershell
Start-Process -FilePath "$env:LOCALAPPDATA/Android/Sdk/emulator/emulator.exe" -ArgumentList '-avd', 'TagOk_Pixel_7_API_36'
```

Comprobar que termine de arrancar antes de instalar. Desde `Producto/tag-ok-app`:

```powershell
$tagokAdb = "$env:LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
& $tagokAdb devices -l
& $tagokAdb -s emulator-5554 shell getprop sys.boot_completed
& $tagokAdb -s emulator-5554 install -r 'app/build/outputs/apk/debug/app-debug.apk'
& $tagokAdb -s emulator-5554 shell am start -n com.tagok.app/.MainActivity
```

El indicador de arranque debe devolver `1`. Sustituir `emulator-5554` si ADB muestra otro identificador. La opción `install -r` actualiza la aplicación conservando sus datos cuando la firma y la instalación existente son compatibles.

### 12.6 Datos iniciales y detención

No volver a importar calles en cada inicio. Los datos ya observados están persistidos en Docker. `osm-importer` contiene un script `00_clean_tables.sql` que elimina tablas del grafo antes de reconstruirlas; ejecutar ese flujo sobre datos existentes exige planificar el reemplazo.

Para detener el conjunto conservando contenedores y volúmenes, desde `Producto`:

```powershell
docker compose --env-file ../.env stop
```

No agregar `-v` a una operación de eliminación de Compose si se quieren conservar las bases. En el trabajo de preparación de este informe no se eliminaron ni migraron datos.

## 13. Diagnóstico de problemas

### 13.1 Comprobaciones básicas

Desde `Producto`:

```powershell
docker compose --env-file ../.env ps -a
docker compose --env-file ../.env logs --tail 80 gateway-service routes-service history-service kafka-tag
curl.exe -s -o NUL -w 'Web HTTP %{http_code}\n' --max-time 10 http://localhost/login
curl.exe -s -o NUL -w 'Rutas HTTP %{http_code}\n' --max-time 10 http://localhost:8080/api/routes/v1/porticos
curl.exe -s -o NUL -w 'Historial docs HTTP %{http_code}\n' --max-time 10 http://localhost:8080/history/v3/api-docs
```

### 13.2 Síntomas y acciones

| Síntoma | Causa a comprobar | Acción |
|---|---|---|
| Docker no responde | Motor apagado o sin terminar de iniciar | Abrir Docker Desktop y esperar su disponibilidad |
| La web abre, pero no carga datos | Gateway o servicios caídos | Revisar estado y logs; un HTTP 200 de Nginx no valida el backend |
| Gateway termina con `UnknownHostException` hacia Supabase | Resolución DNS o disponibilidad del proyecto externo | Consultar DNS y estado en Dashboard; no sustituir claves sin evidencia |
| Kafka falla al arrancar | ZooKeeper todavía no estaba listo | Esperar a ZooKeeper, iniciar Kafka y volver a ejecutar la inicialización |
| Historial no arranca | Kafka o MongoDB no disponibles | Verificar dependencias y luego reiniciar `history-service` |
| Mongo Express solicita contraseña | Autenticación de su interfaz | Usar `admin` / `pass`, no la contraseña directa de la base |
| pgAdmin no encuentra PostgreSQL | Host o puerto de otro entorno | Dentro de pgAdmin Docker usar `db-rutas:5432` |
| Login rechazado | Cuenta inexistente, contraseña incorrecta, correo sin confirmar o proyecto equivocado | Revisar Auth en Supabase |
| Login correcto, pero sin menú administrativo | Rol no reconocido | Consultar `app_metadata.role` y renovar la sesión tras un cambio |
| Usuarios devuelve 401/403/500 | Sesión, rol, función o secretos de Edge Functions | Revisar la función correspondiente y su URL fija en la web |
| Android no conecta al gateway | IP cambiada, red distinta o firewall | Revisar `ApiConfig.kt`, red y puerto 8080 |
| Android aparece `offline` o `device is still booting` | Arranque incompleto o snapshot bloqueado | Esperar; si persiste, usar Cold Boot desde el administrador de dispositivos |
| Gradle falla con referencia a `25.0.2` | JDK incompatible con la combinación actual | Seleccionar JDK 21, que fue validado |
| El mapa no carga | Token, conexión o servicio cartográfico | Revisar Mapbox/Nominatim/teselas según el cliente |
| Cálculo correcto, historial ausente | Entrega asíncrona fallida o consulta demasiado temprana | Revisar publicador, Kafka, consumidor y documentos del usuario |

Para comprobar el DNS del proyecto:

```powershell
Resolve-DnsName ibafvqmoqeabmziyzifk.supabase.co
```

Durante el arranque de esta sesión el dominio dejó de resolver y luego volvió a estar disponible. Se recuperó el gateway al reiniciarlo. No se confirmó administrativamente que la causa fuera una pausa del proyecto.

## 14. Persistencia y respaldos

### 14.1 Dónde permanecen los datos

| Almacén | Persistencia definida |
|---|---|
| PostgreSQL de rutas | Volumen Compose `postgres_data` montado en `/var/lib/postgresql/data` |
| MongoDB de historial | Volumen Compose `mongo_data` montado en `/data/db` |
| Supabase | Persistencia del proyecto remoto; independiente de Docker local |
| Kafka y ZooKeeper | Sin volúmenes de datos explícitos en el Compose revisado |
| pgAdmin | Declara `pgadmin_data` en `/var/lib/postgresql/data`; revisar el destino real de la configuración de pgAdmin antes de confiar en su persistencia |

No debe asumirse que mensajes, offsets o estado de coordinación sobreviven a una recreación de Kafka/ZooKeeper. Un reinicio y una recreación de contenedores son operaciones diferentes.

Un volumen persistente no es un respaldo: puede perderse con una eliminación, un fallo del almacenamiento o una operación errónea.

### 14.2 Procedimiento de respaldo propuesto

Los siguientes comandos son una guía y **no fueron ejecutados para generar este informe**. Guardan archivos fuera del repositorio y usan rutas intermedias en el contenedor para evitar redirecciones binarias problemáticas en PowerShell.

```powershell
$tagokBackupDir = Join-Path $env:USERPROFILE 'Documents/TAG_OK_Respaldos'
$tagokBackupStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
New-Item -ItemType Directory -Force -Path $tagokBackupDir

docker exec db-rutas pg_dump -U admin -d db_rutas -Fc -f /tmp/tagok-db-rutas.dump
# Continuar solo si pg_dump terminó con código 0.
docker cp db-rutas:/tmp/tagok-db-rutas.dump "$tagokBackupDir/db-rutas-$tagokBackupStamp.dump"

docker exec db-historial mongodump --username admin --password admin --authenticationDatabase admin --db historial_db --archive=/tmp/tagok-historial.archive --gzip
# Continuar solo si mongodump terminó con código 0.
docker cp db-historial:/tmp/tagok-historial.archive "$tagokBackupDir/historial-$tagokBackupStamp.archive.gz"
```

Comprobar códigos de salida y archivos resultantes; una restauración en un entorno separado es la prueba de que el respaldo es utilizable. Los respaldos pueden contener datos personales y no deben incorporarse a Git.

Respaldar Supabase exige considerar datos, cuentas Auth, políticas, funciones y configuración. Las Edge Functions y otros recursos requieren tratamiento adicional al respaldo SQL según el método elegido. [Guía oficial de migración](https://supabase.com/docs/guides/platform/migrating-within-supabase/dashboard-restore).

Para respaldos coordinados de las tres bases, planificar una ventana que reduzca escrituras y permita drenar los eventos pendientes. Copiar cada base en momentos distintos puede producir un conjunto inconsistente respecto de usuarios y cruces.

## 15. Autenticación, autorización y hallazgos

### 15.1 Roles implementados

`super_admin` tiene acceso a todas las secciones administrativas del cliente. `admin` es un nombre legado interpretado como superadministrador. `admin_operacional` puede gestionar concesionarios, pórticos, tarifas y carga masiva. Un usuario sin esos roles conserva acceso a las vistas generales que solo exigen sesión.

Las Edge Functions de usuarios comprueban sesión y rol en servidor. `update-user-role` incluye una protección para impedir que el administrador cambie su propio rol. Estas comprobaciones son distintas de las guardas de React.

### 15.2 Hallazgos que afectan operación y despliegue

| Hallazgo comprobado en configuración o código | Implicación | Mejora propuesta |
|---|---|---|
| Gateway con `.anyExchange().permitAll()` | No se exige autenticación globalmente; el GET de pórticos respondió sin token | Definir rutas públicas y protegidas y autorización por rol en servidor |
| Validación OAuth2 JWT configurada cuando se presenta token | `permitAll()` no significa que un token inválido sea aceptado | Mantener la validación y separar autenticación de autorización |
| `CurrentUserService` en rutas e historial decodifica el payload JWT | Los servicios dependen de que el gateway haya validado la firma | Evitar exposición directa y definir una frontera de confianza explícita |
| Rutas administrativas web protegidas en cliente, sin una política equivalente evidente para todos los endpoints Java | Ocultar botones no garantiza impedir operaciones directas | Auditar cada operación de administración y aplicar permisos en backend |
| CORS con orígenes, métodos y cabeceras amplios | Configuración permisiva de desarrollo | Restringir a los clientes publicados |
| Credenciales locales simples y puertos publicados sin limitarse a loopback | La accesibilidad desde otras máquinas depende de red y firewall | Configurar usuarios de servicio, credenciales propias y exposición necesaria |
| `ddl-auto=update` en rutas | El esquema puede cambiar al iniciar la aplicación | Introducir migraciones versionadas y verificables |
| URLs de Supabase y backend fijadas en varios archivos | Riesgo de mezclar entornos tras una migración | Centralizar configuración por ambiente |
| `supabase-schema.sql` es un archivo de referencia | No basta para reconstruir el entorno remoto | Exportar y versionar una definición completa de esquema/políticas |
| Compose sin comprobaciones de salud ni políticas de reinicio explícitas | Dependencias pueden fallar durante el arranque y quedar detenidas | Incorporar salud, reintentos y dependencias por disponibilidad |
| Publicador Kafka registra errores; el historial agrega cruces a documentos | Reintentos o errores requieren estudiar pérdida/duplicación y concurrencia | Diseñar idempotencia por evento y estrategia de entrega recuperable |
| Builds Java en Docker omiten pruebas | Compilar no demuestra corrección funcional | Ejecutar pruebas pertinentes en un flujo de integración |

`AUTH_EXTERNAL_ENABLED=false` no crea un usuario administrador local ni ofrece una sesión alternativa. En el código revisado el decodificador devuelve error para los tokens cuando ese modo está desactivado. No debe utilizarse como solución automática a una caída de Supabase.

Estos puntos describen el estado encontrado y propuestas de trabajo. No se modificaron permisos, lógica, credenciales ni configuración del producto para redactar el informe.

## 16. Migración y centralización en Supabase

### 16.1 Por qué existen varios almacenes

No se encontró una decisión formal de arquitectura que permita atribuir al equipo una razón histórica definitiva. La distribución del código sugiere una división por responsabilidades: Supabase para identidad y datos del conductor, PostgreSQL espacial para rutas y MongoDB para historial documental.

Esta separación permite evolucionar componentes de forma independiente, pero aumenta conexiones, respaldos, entornos y pruebas. No es un requisito intrínseco del negocio ni una garantía de mejor rendimiento.

### 16.2 Escenarios diferentes

| Escenario | Trabajo necesario |
|---|---|
| Otro proyecto de Supabase con la misma estructura | Migrar datos/Auth/configuración y actualizar todos los clientes |
| Supabase alojado en otra infraestructura | Lo anterior más operación de Auth, Data API, funciones, red y respaldo |
| Migrar MongoDB a Supabase | Transformar documentos y reescribir persistencia/consultas del historial |
| Migrar `db_rutas` a Supabase | Copiar grafo y catálogos, adaptar JDBC/esquemas/permisos y probar extensiones y rendimiento |
| Sustituir Supabase por una base PostgreSQL sin sus servicios | Reemplazar también Auth, Data API y Edge Functions o mantener servicios equivalentes |

Cambiar de base no elimina automáticamente los servicios Java ni Kafka. Una consolidación de almacenamiento y una simplificación de servicios son decisiones relacionadas, pero distintas.

### 16.3 Cambiar a otro proyecto Supabase

1. Inventariar el esquema real, datos, políticas RLS, funciones SQL, triggers, usuarios, roles y configuración Auth.
2. Generar respaldos y preparar un proyecto destino de prueba.
3. Migrar las cuentas preservando identificadores y metadatos. Supabase permite trasladar los hashes de contraseña junto con Auth mediante una migración adecuada. [Migración de usuarios Auth](https://supabase.com/docs/guides/troubleshooting/migrating-auth-users-between-projects).
4. Migrar tablas y datos relacionados; verificar las políticas de acceso.
5. Desplegar `list-users`, `update-user-role` y `update-user-status`; configurar sus secretos en destino.
6. Reproducir proveedores, URLs de retorno y demás ajustes Auth que realmente use el proyecto. Si existen objetos Storage, migrarlos aparte según el método elegido.
7. Actualizar `.env`, las constantes del frontend y Android, y el perfil local del gateway.
8. Reconstruir web y gateway y distribuir una nueva versión Android. Prever un nuevo inicio de sesión.
9. Probar cuentas con diferentes roles, vehículos, presupuestos, notificaciones e historial antes del cambio definitivo.
10. Mantener una estrategia de retorno al entorno anterior y un plan para las escrituras producidas durante el cambio.

No recrear usuarios únicamente por correo si se pretende conservar la asociación con el historial de MongoDB.

### 16.4 ¿Es posible dejar todo en Supabase?

Sí es una alternativa técnica, pero requiere una migración y validación, no solo cambiar cadenas de conexión. El historial puede representarse con tablas de eventos/cruces y consultas agregadas; también existen opciones con JSON, que deben evaluarse según consultas y mantenimiento.

Supabase documenta soporte para PostGIS y pgRouting. Por tanto, no hay base para afirmar que Supabase sea incompatible en general con el ruteo del proyecto. Aun así, el destino concreto debe verificarse: versiones de extensiones, disponibilidad de `pgr_dijkstra` y las funciones de topología utilizadas, esquemas, permisos, límites y tiempos de consulta. [pgRouting en Supabase](https://supabase.com/docs/guides/database/extensions/pgrouting).

Consulta de inventario que puede ejecutarse en el destino antes de diseñar la migración:

```sql
SELECT name, default_version, installed_version
FROM pg_available_extensions
WHERE name IN ('postgis', 'pgrouting');
```

### 16.5 Propuesta gradual para TAG OK

Primero, centralizar la configuración y reforzar los controles del backend. Después, migrar el historial a Supabase preservando usuarios, importes, fechas y filtros. Esta etapa elimina MongoDB si ya no queda ningún consumidor que lo necesite.

En una segunda etapa, probar el grafo vial en un entorno Supabase separado usando una copia de los datos locales. Comparar resultados y tiempos de rutas y tarifas, consumo de recursos y comportamiento concurrente. Si cumple los requisitos, planificar el traslado; si no, mantener PostgreSQL espacial separado.

También debe evaluarse si Kafka aporta una necesidad suficiente para el alcance del MVP. Eliminarlo exigiría rediseñar el registro de cruces y sus garantías de entrega; no se resuelve únicamente migrando MongoDB.

La centralización puede facilitar administración y respaldos, pero concentra fallos y aumenta la dependencia del entorno remoto. No se estiman costos ni ahorros concretos sin medir carga, almacenamiento y plan contratado.

## 17. Validación realizada y pruebas pendientes

### 17.1 Evidencia local

| Comprobación | Resultado |
|---|---|
| Inspección de Compose y código | Componentes y destinos identificados |
| Estado de contenedores consultado para el informe | Servicios principales en ejecución; inicializador Kafka terminado con código 0 |
| `http://localhost/login` | HTTP 200 |
| `http://localhost:8080/api/routes/v1/porticos` | HTTP 200 sin token |
| `http://localhost:8080/history/v3/api-docs` | HTTP 200 |
| PostgreSQL | 14 tablas en `public`; PostGIS 3.3.4 y pgRouting 3.4.1 |
| Conteos de datos | 50.749 segmentos, 105 pórticos, 5 autopistas |
| MongoDB | Colección `historial_anual` presente |
| App Android, durante el arranque de esta sesión | `assembleDebug` correcto con JDK 21; APK instalado y actividad abierta |
| Credenciales Mongo Express | `admin:pass` confirmado en los logs locales de la sesión |

Los resultados son de disponibilidad y estructura. Un HTTP 200 de la web o de OpenAPI no demuestra un inicio de sesión correcto ni la exactitud de los cálculos.

### 17.2 Límites de la revisión

No se inició sesión con una contraseña personal para validar todos los módulos, no se inspeccionó Supabase con privilegios administrativos y no se ejecutaron pruebas de carga, restauración ni migración. Tampoco se confirmó la entrega de nuevas notificaciones o la extracción real de una factura durante la preparación del informe.

El repositorio contiene pruebas Java y Android, incluyendo `ComparadorFacturasTest`; no se ejecutaron suites funcionales para un cambio exclusivamente documental. Las pruebas del servicio de rutas localizadas bajo `src/main/resources/test` requieren revisar su ubicación antes de asumir que Maven las descubre como pruebas estándar.

### 17.3 Pruebas de aceptación recomendadas

| Área | Caso a verificar |
|---|---|
| Identidad | Login/logout, sesión vencida y usuario bloqueado |
| Roles | Matriz de permisos probada tanto desde UI como desde endpoints |
| Aislamiento | Un usuario no puede consultar ni modificar datos de otro |
| Vehículos y presupuesto | Altas, cambios, eliminación y filtros por usuario |
| Rutas y tarifas | Resultados conocidos por categoría, horario y tipo de cobro |
| Eventos | Registro de cruces, reentrega del mismo evento y caída temporal de Kafka |
| Historial | Totales, fechas, filtros y correspondencia con el usuario |
| Notificaciones | Umbrales, ausencia de duplicados y estado de lectura |
| Android | Permisos, GPS, red física y recuperación al volver a conectar |
| Facturas | PDF/imagen válido, archivo inválido, límite de tamaño y error del proveedor |
| Operación | Arranque desde cero con respaldos, recuperación y retorno tras migración |

## 18. Referencias y archivos de consulta

### 18.1 Fuentes del repositorio

Los enlaces son relativos a este informe y apuntan a la evidencia técnica utilizada.

| Área | Archivos principales |
|---|---|
| Arquitectura y arranque | [README](README.md), [guía de arranque](GUIA_ARRANQUE_LOCAL.md), [Compose](Producto/docker-compose.yml) |
| Versiones backend | [Gateway POM](Producto/gateway-service/pom.xml), [rutas POM](Producto/routes-service/pom.xml), [historial POM](Producto/history-service/pom.xml) |
| Web | [package.json](Producto/routes-ui/package.json), [rutas](Producto/routes-ui/src/App.tsx), [roles](Producto/routes-ui/src/app/auth/roles.ts), [guardas](Producto/routes-ui/src/app/auth/RutaProtegida.tsx) |
| Conexiones web | [Axios](Producto/routes-ui/src/api/axios.ts), [cliente Supabase](Producto/routes-ui/src/app/lib/supabase.ts), [usuarios](Producto/routes-ui/src/hooks/useUsuarios.ts) |
| Publicación web | [Dockerfile](Producto/routes-ui/Dockerfile), [Nginx](Producto/routes-ui/nginx.conf) |
| Android | [versiones](Producto/tag-ok-app/gradle/libs.versions.toml), [build](Producto/tag-ok-app/app/build.gradle.kts), [configuración API](Producto/tag-ok-app/app/src/main/java/com/tagok/app/data/remote/ApiConfig.kt), [cliente Supabase](Producto/tag-ok-app/app/src/main/java/com/tagok/app/SupabaseClient.kt) |
| Alertas móviles | [AlertaService](Producto/tag-ok-app/app/src/main/java/com/tagok/app/domain/services/AlertaService.kt), [HomeViewModel](Producto/tag-ok-app/app/src/main/java/com/tagok/app/ui/home/HomeViewModel.kt) |
| Gateway | [rutas](Producto/gateway-service/src/main/resources/application.yml), [seguridad](Producto/gateway-service/src/main/java/com/tagok/gateway_service/security/SecurityConfig.java), [perfil local](Producto/gateway-service/src/main/resources/application-local.yml) |
| Ruteo | [RouteRepository](Producto/routes-service/src/main/java/com/tagok/routes_service/repository/RouteRepository.java), [TarifaService](Producto/routes-service/src/main/java/com/tagok/routes_service/service/application/TarifaService.java) |
| Historial | [modelo anual](Producto/history-service/src/main/java/com/tagok/history_service/document/HistorialAnualDocument.java), [servicio](Producto/history-service/src/main/java/com/tagok/history_service/service/HistorialService.java), [configuración](Producto/history-service/src/main/resources/application.properties) |
| Kafka | [broker](Producto/kafka/server.properties), [tópico](Producto/kafka/init-topics.sh), [publicador](Producto/routes-service/src/main/java/com/tagok/routes_service/events/publishers/KafkaHistorialCrucePublisher.java), [consumidor](Producto/history-service/src/main/java/com/tagok/history_service/event/consumer/HistorialCruceConsumer.java) |
| Supabase | [esquema de referencia](Producto/supabase/supabase-schema.sql), [migración de alertas](Producto/supabase/migrations/20260614_alertas_presupuesto.sql), [funciones](Producto/supabase/functions), [configuración CLI](Producto/supabase/config.toml) |
| Datos iniciales | [scripts OSM](Producto/osm-importer/src/main/resources/database-scripts), [SQL local](Producto/sql), [datos de pórticos](Producto/porticos) |

La documentación anterior puede contener ejemplos o nombres de una versión previa. Para puertos, enums y rutas, este informe utiliza prioritariamente la configuración y el código revisados. La guía antigua de entorno, por ejemplo, contiene una referencia a PostgreSQL en el puerto 5432 del host; el Compose actual publica **5431**.

### 18.2 Fuentes oficiales consultadas

- [Docker: orden de arranque y comprobaciones de salud](https://docs.docker.com/compose/how-tos/startup-order/).
- [Supabase: migración entre proyectos](https://supabase.com/docs/guides/platform/migrating-within-supabase).
- [Supabase: restauración de respaldo en otro proyecto](https://supabase.com/docs/guides/platform/migrating-within-supabase/dashboard-restore).
- [Supabase: migración de usuarios Auth](https://supabase.com/docs/guides/troubleshooting/migrating-auth-users-between-projects).
- [Supabase: extensión pgRouting](https://supabase.com/docs/guides/database/extensions/pgrouting).

Estas referencias sustentan posibilidades y procedimientos de las plataformas. No demuestran que un recurso, extensión o política esté habilitado en el proyecto remoto concreto.

## 19. Glosario

| Término | Significado en TAG OK |
|---|---|
| Frontend | Interfaz que utiliza la persona: navegador o app |
| Backend | Servicios que aplican reglas y atienden solicitudes |
| Gateway | Punto de entrada HTTP que dirige peticiones |
| API REST | Contratos HTTP para consultar y modificar recursos |
| SPA | Aplicación web cuya navegación se resuelve principalmente en el navegador |
| JWT | Token con información de sesión; decodificarlo no equivale a validar su firma |
| RLS | Políticas que restringen acceso a filas en PostgreSQL/Supabase |
| Edge Function | Función backend ejecutada en la infraestructura de Supabase |
| PostGIS | Extensión para geometrías y consultas geográficas |
| pgRouting | Extensión para algoritmos sobre redes, como rutas en un grafo |
| Colección | Agrupación de documentos en MongoDB |
| Broker/tópico | Servicio de mensajería y canal donde se publican eventos |
| Consistencia eventual | Un cambio puede tardar en aparecer en otro servicio |
| Idempotencia | Procesar nuevamente una operación sin duplicar su efecto |
| Volumen Docker | Almacenamiento separado del ciclo de vida normal del contenedor |
| Migración | Cambio controlado de estructura, datos o entorno, con validación y recuperación |
