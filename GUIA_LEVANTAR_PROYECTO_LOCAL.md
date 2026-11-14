# Guía: cómo levantar TAG OK en local desde la terminal

Esta guía explica paso a paso cómo dejar corriendo el proyecto en tu máquina, tanto la app principal (`Producto/tag_ok`) como el panel de administración (`Producto/admin`), usando solo la terminal.

---

## 1. Requisitos previos

Instala esto antes de empezar:

- **Git** — para clonar/actualizar el repositorio.
- **Google Chrome** — para correr la app en modo web (la forma más rápida de probarla).
- **Flutter SDK 3.41.9 / Dart 3.11.5** — dos opciones:
  - **Opción A (recomendada si no tienes Flutter instalado):** el repo ya trae un SDK portable en `.tools/flutter` (no se sube a git, pregúntale al equipo cómo obtenerlo o instálalo tú mismo siguiendo la Opción B).
  - **Opción B:** instala Flutter globalmente siguiendo <https://docs.flutter.dev/get-started/install>, asegurándote de que la versión coincida (`flutter --version` debe mostrar `3.41.9`).
- (Opcional, solo si vas a correr en Windows Desktop) **Visual Studio** con la carga de trabajo "Desarrollo de escritorio con C++".

Verifica que Flutter esté disponible en la terminal:

```bash
flutter --version
```

Si usas el SDK portable del repo en vez de uno instalado globalmente, agrégalo al PATH de la sesión actual antes de cualquier comando `flutter`:

```bash
# Bash (Git Bash / WSL), parado en la raíz del repo
export PATH="$PWD/.tools/flutter/bin:$PATH"
export PUB_CACHE="$PWD/.tools/pub-cache"
```

```powershell
# PowerShell, parado en la raíz del repo
$env:PATH = "$PWD\.tools\flutter\bin;" + $env:PATH
$env:PUB_CACHE = "$PWD\.tools\pub-cache"
```

---

## 2. Clonar el repositorio

```bash
git clone https://github.com/JazminHerrera2/CAPSTOM_EC_DM_AC.git
cd CAPSTOM_EC_DM_AC
```

Si ya lo tienes clonado, solo actualiza:

```bash
git pull
```

---

## 3. Estructura relevante

```
CAPSTOM_EC_DM_AC/
├── Producto/
│   ├── tag_ok/     # App principal (Flutter, móvil/web)
│   └── admin/      # Panel de administración (Flutter web)
└── .tools/flutter/ # SDK de Flutter portable (no se versiona en git)
```

---

## 4. Crear los archivos `.env`

Los dos proyectos (`tag_ok` y `admin`) necesitan un archivo `.env` en su raíz con las credenciales de Firebase, Mapbox y Gemini. **Estos archivos no están en el repositorio** (están en `.gitignore` a propósito, porque contienen claves privadas) — pídeselos a algún integrante del equipo o pide acceso a los proyectos de Firebase/Mapbox/Gemini para generarlos tú.

Crea el archivo en `Producto/tag_ok/.env`:

```env
WEB_API_KEY=tu_web_api_key
WEB_APP_ID=tu_web_app_id
ANDROID_API_KEY=tu_android_api_key
ANDROID_APP_ID=tu_android_app_id
IOS_API_KEY=tu_ios_api_key
IOS_APP_ID=tu_ios_app_id
MESSAGING_SENDER_ID=tu_messaging_sender_id
PROJECT_ID=tu_project_id
STORAGE_BUCKET=tu_storage_bucket
IOS_BUNDLE_ID=tu_ios_bundle_id
MAPBOX_ACCESS_TOKEN=tu_mapbox_access_token
SUPABASE_URL=https://tu_proyecto.supabase.co
```

> ℹ️ En `tag_ok` el `.env` **no se empaqueta como archivo**: se lee al compilar
> con `--dart-define-from-file=.env` (ver `lib/entorno.dart`). Por eso **todos
> los comandos `flutter run` y `flutter build` de `tag_ok` llevan
> `--dart-define-from-file=.env`**. Si lo olvidas, la app abre la pantalla
> "No se pudo iniciar TAG OK" indicando la variable que falta.
>
> ⚠️ **No pongas claves secretas en el `.env`** (OpenAI, Gemini, etc.). Las
> variables que la app usa quedan escritas dentro de la app compilada, así que
> solo pueden ser datos públicos. La IA funciona a través de la Edge Function
> `ia-extraccion` de Supabase, que guarda la clave de OpenAI como secreto del
> servidor:
>
> ```bash
> cd Producto/tag_ok
> npx supabase login
> npx supabase link --project-ref <id del proyecto>
> npx supabase secrets set OPENAI_API_KEY=<clave de OpenAI>
> npx supabase functions deploy ia-extraccion
> ```

Repite lo mismo en `Producto/admin/.env` (misma estructura de variables).

> Puedes copiar la plantilla de ejemplo que trae el repo y solo reemplazar los valores:
> ```bash
> cp Producto/tag_ok/env_ejemplo.txt Producto/tag_ok/.env
> cp Producto/admin/env_ejemplo.txt Producto/admin/.env
> # luego edita ambos archivos .env y reemplaza cada TU_... por el valor real
> ```

Si no tienes las claves reales todavía, igual puedes instalar dependencias y compilar, pero la app fallará al conectarse a Firebase/Mapbox/Supabase (archivos e IA) en tiempo de ejecución.

---

## 5. Instalar dependencias

Para la app principal:

```bash
cd Producto/tag_ok
flutter pub get
cd ../..
```

Para el panel de administración:

```bash
cd Producto/admin
flutter pub get
cd ../..
```

---

## 6. Levantar la app principal (`tag_ok`)

**En Chrome (recomendado, más rápido):**

```bash
cd Producto/tag_ok
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8090 --dart-define-from-file=.env
```

Luego abre en el navegador: `http://127.0.0.1:8090/`

Si no tienes Chrome, usa `-d edge`. Si el navegador no llega a conectarse,
`flutter run -d web-server --web-port 8090 --dart-define-from-file=.env` y abre
la dirección que muestra la terminal.

**Publicar en producción (Firebase Hosting):**

```bash
cd Producto/tag_ok
flutter build web --release --pwa-strategy=none --dart-define-from-file=.env
firebase deploy --only hosting --project tag-ok-v2
```

Si el build quedó raro, antes de compilar: `flutter clean` y `flutter pub get`.

Los clientes ven la versión nueva con solo abrir el link, sin Ctrl+Shift+R ni
incógnito: `firebase.json` manda `Cache-Control: no-cache` (el navegador
revalida con Hosting en cada visita) y `--pwa-strategy=none` desactiva el
service worker de Flutter, que guardaba una copia propia de la app. Un cliente
que ya tenía la versión antigua puede necesitar recargar **una sola vez**; de
ahí en adelante se actualiza solo.

**En Windows Desktop:**

```bash
cd Producto/tag_ok
flutter run -d windows --dart-define-from-file=.env
```

**APK de Android:**

```bash
cd Producto/tag_ok
flutter build apk --release --dart-define-from-file=.env
```

---

## 7. Levantar el panel de administración (`admin`)

**En Chrome:**

```bash
cd Producto/admin
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8091
```

Luego abre en el navegador: `http://127.0.0.1:8091/`

**En Windows Desktop:**

```bash
cd Producto/admin
flutter run -d windows
```

---

## 8. Cómo aplicar cambios mientras la app está corriendo (Hot Reload)

`flutter run` deja una terminal interactiva abierta. **Guardar un archivo no recompila solo** — hay que darle el comando en esa misma terminal:

| Tecla | Acción |
| :---: | --- |
| `r` | Hot reload (aplica los cambios de código manteniendo el estado) |
| `R` | Hot restart (reinicia la app desde cero) |
| `q` | Detener la app y cerrar |

Si vas a editar código, deja esa terminal visible y presiona `r` cada vez que guardes un cambio.

---

## 9. Alternativa: instalador automático (`setup.bat`)

Si estás en Windows y quieres que un script haga los pasos 5, 6 y 7 por ti con un menú interactivo:

```bash
cd Producto
setup.bat
```

Este script:
1. Crea archivos `.env` vacíos si no existen (edítalos después con tus claves reales, ver paso 4).
2. Corre `flutter pub get` en `tag_ok` y `admin`.
3. Muestra un menú para elegir qué app levantar (Windows o Chrome).

---

## 10. Problemas comunes

**"Failed to bind web development server" / puerto en uso**
Ya hay un proceso usando ese puerto (por ejemplo, de una sesión anterior que no cerró bien). Ciérralo antes de reintentar:

```powershell
# PowerShell — reemplaza 8090 por el puerto que esté fallando
Get-NetTCPConnection -LocalPort 8090 -State Listen | Select-Object -ExpandProperty OwningProcess | ForEach-Object { Stop-Process -Id $_ -Force }
```

**"Building with plugins requires symlink support" / pide activar Developer Mode**
En Windows, ejecuta:

```powershell
start ms-settings:developers
```

y activa el "Modo de programador". Solo hace falta una vez por máquina.

**La página carga en blanco**
Haz un recargado forzado (`Ctrl+Shift+R`) para descartar caché del navegador. Si sigue en blanco, revisa la terminal donde corre `flutter run` — ahí aparece cualquier error de compilación.

**No tengo las claves del `.env`**
Pídelas a un integrante del equipo o revisa dónde las tengan guardadas (Firebase Console, Mapbox, Google AI Studio para Gemini).
