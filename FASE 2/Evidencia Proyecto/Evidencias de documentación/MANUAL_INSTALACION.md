# Manual de instalación — TAG OK

Este manual explica qué instalar en el computador y qué comandos ejecutar en la terminal para dejar funcionando el proyecto. Incluye la app principal (`Producto/tag_ok`) y el panel de administración (`Producto/admin`).

---

## 1. Programas necesarios

| Programa | Para qué sirve | Versión | Obligatorio |
| --- | --- | --- | :---: |
| **Git** | Descargar el repositorio | Cualquiera reciente | Sí |
| **Flutter SDK** (incluye Dart) | Compilar y ejecutar las apps | **3.41.9** (Dart 3.11.5) | Sí |
| **Google Chrome** | Probar la app en modo web | Reciente | Sí |
| **Node.js** (incluye `npm`) | Firebase CLI y Supabase CLI | 18 o superior (recomendado LTS) | Solo para desplegar |
| **Firebase CLI** | Publicar la web y las reglas de Firestore | Reciente | Solo para desplegar |
| **Android Studio** (SDK de Android + JDK) | Compilar el APK de Android | Reciente | Solo para el APK |
| **Visual Studio** con "Desarrollo de escritorio con C++" | Ejecutar como app de Windows | 2022 o superior | Opcional |

Enlaces de descarga:

- Git: <https://git-scm.com/downloads>
- Flutter: <https://docs.flutter.dev/get-started/install>
- Chrome: <https://www.google.com/chrome/>
- Node.js: <https://nodejs.org/>
- Android Studio: <https://developer.android.com/studio>

### Cuentas y claves que necesitas (pídelas al equipo)

- Acceso al proyecto de **Firebase** `tag-ok-v2` (Auth, Firestore y Hosting).
- Un token de **Mapbox** (mapas y búsqueda de direcciones).
- Un proyecto de **Supabase** (archivos y Edge Function de IA) y su clave anónima.
- Una clave de **OpenAI**, que solo se guarda como secreto en Supabase (nunca en el `.env`).

---

## 2. Verificar la instalación

Abre una terminal nueva y ejecuta:

```bash
git --version
flutter --version        # debe mostrar Flutter 3.41.9
flutter doctor           # revisa que Chrome (y Android si lo usas) estén en verde
node --version           # solo si vas a desplegar
```

En Windows, si Flutter pide permisos de enlaces simbólicos, activa el "Modo de programador":

```powershell
start ms-settings:developers
```

Para publicar en Firebase, instala y accede con su CLI:

```bash
npm install -g firebase-tools
firebase login
```

---

## 3. Descargar el proyecto

```bash
git clone https://github.com/JazminHerrera2/CAPSTOM_EC_DM_AC.git
cd CAPSTOM_EC_DM_AC
git checkout develop
```

La rama `develop` tiene la última versión; `main` y las demás ramas contienen lo mismo.

---

## 4. Crear los archivos `.env`

Los `.env` **no están en el repositorio** porque contienen claves. Hay que crearlos a mano.

### App principal (`Producto/tag_ok/.env`)

Copia la plantilla y reemplaza los valores:

```bash
cp Producto/tag_ok/env_ejemplo.txt Producto/tag_ok/.env
```

Variables que debe tener:

```env
WEB_API_KEY=
WEB_APP_ID=
ANDROID_API_KEY=
ANDROID_APP_ID=
IOS_API_KEY=
IOS_APP_ID=
MESSAGING_SENDER_ID=
PROJECT_ID=
STORAGE_BUCKET=
IOS_BUNDLE_ID=
MAPBOX_ACCESS_TOKEN=
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_BUCKET=
```

Esta app lee el `.env` al compilar, por eso **todos los comandos `flutter run` y `flutter build` de `tag_ok` llevan `--dart-define-from-file=.env`**. Si se olvida, la app muestra "No se pudo iniciar TAG OK" e indica qué variable falta.

### Panel de administración (`Producto/admin/.env`)

Crea el archivo con las mismas variables de Firebase y Mapbox que usa `tag_ok`:

```bash
cp Producto/tag_ok/.env Producto/admin/.env
```

> No pongas claves secretas (OpenAI, Gemini, service role) en ningún `.env`: terminan escritas dentro de la app compilada.

---

## 5. Instalar las dependencias

```bash
cd Producto/tag_ok
flutter pub get

cd ../admin
flutter pub get

cd ../..
```

---

## 6. Ejecutar la app principal (`tag_ok`)

### En Chrome

```bash
cd Producto/tag_ok
flutter run -d chrome --web-hostname localhost --web-port 8090 --dart-define-from-file=.env
```

Se abre en `http://localhost:8090/`. Mientras corre, en esa terminal: `r` hot reload, `R` hot restart, `q` salir.

### En Windows (escritorio)

```bash
flutter run -d windows --dart-define-from-file=.env
```

### Generar el APK de Android

```bash
cd Producto/tag_ok
flutter build apk --release --dart-define-from-file=.env
```

El archivo queda en `Producto/tag_ok/build/app/outputs/flutter-apk/app-release.apk`. Está firmado con clave de depuración: sirve para instalar y probar, no para Play Store.

---

## 7. Ejecutar el panel de administración (`admin`)

```bash
cd Producto/admin
flutter run -d chrome --web-hostname localhost --web-port 8091
```

Se abre en `http://localhost:8091/`. El admin lee su `.env` como archivo incluido en la app, por eso no lleva `--dart-define-from-file`.

---

## 8. Configurar el backend (solo la primera vez o al cambiar algo)

### Reglas de Firestore

```bash
cd Producto/tag_ok
firebase deploy --only firestore:rules --project tag-ok-v2
```

Hay que repetirlo cada vez que cambie `firestore.rules`. Sin eso, funciones nuevas (por ejemplo guardar boletas de Estacionamientos) pueden fallar.

### IA con Supabase (Edge Function `ia-extraccion`)

```bash
cd Producto/tag_ok
npx supabase login
npx supabase link --project-ref <id-del-proyecto-supabase>
npx supabase secrets set OPENAI_API_KEY=<clave-de-openai>
npx supabase functions deploy ia-extraccion
```

---

## 9. Publicar la web (opcional)

**App principal:**

```bash
cd Producto/tag_ok
flutter clean
flutter pub get
flutter build web --release --pwa-strategy=none --dart-define-from-file=.env
firebase deploy --only hosting --project tag-ok-v2
```

**Panel de administración:**

```bash
cd Producto/admin
flutter clean
flutter pub get
flutter build web --release --pwa-strategy=none
firebase deploy --only hosting:admin --project tag-ok-v2
```

---

## 10. Problemas comunes

| Problema | Solución |
| --- | --- |
| "No se pudo iniciar TAG OK" | Falta `--dart-define-from-file=.env` o una variable del `.env` está vacía. |
| `flutter` no se reconoce | Agrega la carpeta `flutter/bin` al PATH y abre una terminal nueva. |
| Versión de Flutter distinta | Usa la 3.41.9. Con `flutter --version` compruébalo. |
| "Failed to bind web development server" | El puerto está ocupado. Cierra la sesión anterior o cambia `--web-port`. |
| "Building with plugins requires symlink support" | Activa el Modo de programador de Windows (ver sección 2). |
| Página en blanco en Chrome | Recarga con `Ctrl+Shift+R` y revisa los errores en la terminal de `flutter run`. |
| El APK no se actualiza en el celular | Desinstala la versión anterior antes de instalar la nueva. |
| La ubicación tarda o no aparece | Acepta el permiso de ubicación del navegador o del celular. |
