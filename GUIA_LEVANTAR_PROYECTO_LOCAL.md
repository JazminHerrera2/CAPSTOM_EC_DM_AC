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
GEMINI_API_KEY=tu_gemini_api_key
```

Repite lo mismo en `Producto/admin/.env` (misma estructura de variables).

> Puedes copiar la plantilla de ejemplo que trae el repo y solo reemplazar los valores:
> ```bash
> cp Producto/tag_ok/env_ejemplo.txt Producto/tag_ok/.env
> cp Producto/admin/env_ejemplo.txt Producto/admin/.env
> # luego edita ambos archivos .env y reemplaza cada TU_... por el valor real
> ```

Si no tienes las claves reales todavía, igual puedes instalar dependencias y compilar, pero la app fallará al conectarse a Firebase/Mapbox/Gemini en tiempo de ejecución.

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
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8090
```

Luego abre en el navegador: `http://127.0.0.1:8090/`

**En Windows Desktop:**

```bash
cd Producto/tag_ok
flutter run -d windows
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
