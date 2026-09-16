# Guia para levantar TAG OK desde terminal

Esta guia explica como ejecutar el proyecto TAG OK comando por comando desde una terminal en Windows. El repositorio contiene dos aplicaciones Flutter:

- `Producto/tag_ok`: aplicacion principal para usuarios.
- `Producto/admin`: panel web/desktop de administracion.

Los comandos asumen que la terminal parte desde la raiz del repositorio:

```powershell
C:\Users\Naneuwu\Documents\GitHub\CAPSTOM_EC_DM_AC
```

## 1. Abrir terminal en la raiz del proyecto

En PowerShell:

```powershell
cd C:\Users\Naneuwu\Documents\GitHub\CAPSTOM_EC_DM_AC
```

Verifica que estas en la carpeta correcta:

```powershell
dir
```

Deberias ver carpetas como `Producto`, `Documentacion`, `Gestion` y `README.md`.

## 2. Verificar Flutter

Ejecuta:

```powershell
flutter --version
```

El proyecto fue documentado usando Flutter `3.41.9` y Dart `3.11.5`.

Si `flutter` no existe globalmente, el proyecto incluye un SDK local en:

```powershell
.\.tools\flutter\bin\flutter.bat
```

En ese caso puedes agregarlo temporalmente al `PATH` de la terminal actual:

```powershell
$env:PATH = "$PWD\.tools\flutter\bin;$env:PATH"
```

Opcionalmente define un cache local de paquetes para este repositorio:

```powershell
$env:PUB_CACHE = "$PWD\.tools\pub-cache"
```

Vuelve a comprobar:

```powershell
flutter --version
```

## 3. Crear archivos `.env` si no existen

Flutter espera que exista un archivo `.env` porque esta declarado como asset en el `pubspec.yaml`.

Para la app principal:

```powershell
if (!(Test-Path .\Producto\tag_ok\.env)) { New-Item -ItemType File .\Producto\tag_ok\.env }
```

Para el panel admin:

```powershell
if (!(Test-Path .\Producto\admin\.env)) { New-Item -ItemType File .\Producto\admin\.env }
```

Segun el README y `setup.bat`, las claves principales se cargan en memoria desde el codigo, por lo que estos `.env` pueden estar vacios.

## 4. Instalar dependencias de la app principal

Entra a la app principal:

```powershell
cd .\Producto\tag_ok
```

Descarga/actualiza dependencias:

```powershell
flutter pub get
```

## 5. Levantar la app principal en Chrome

Desde `Producto/tag_ok`, ejecuta:

```powershell
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8090 --no-web-experimental-hot-reload
```

Cuando termine de compilar, abre:

```text
http://127.0.0.1:8090
```

Para detener el servidor, vuelve a la terminal donde esta corriendo Flutter y presiona:

```text
q
```

## 6. Levantar el panel administrador en Chrome

Abre otra terminal desde la raiz del repositorio o vuelve a ella:

```powershell
cd C:\Users\Naneuwu\Documents\GitHub\CAPSTOM_EC_DM_AC
```

Entra al panel admin:

```powershell
cd .\Producto\admin
```

Instala dependencias:

```powershell
flutter pub get
```

Ejecuta en Chrome:

```powershell
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8091 --no-web-experimental-hot-reload
```

Cuando termine de compilar, abre:

```text
http://127.0.0.1:8091
```

## 7. Ejecutar con el instalador interactivo

Tambien existe un script listo para instalar dependencias y mostrar un menu:

```powershell
cd C:\Users\Naneuwu\Documents\GitHub\CAPSTOM_EC_DM_AC\Producto
.\setup.bat
```

Opciones del menu:

- `1`: App principal en Windows Desktop.
- `2`: App principal en Chrome, puerto `8090`.
- `3`: Admin en Windows Desktop.
- `4`: Admin en Chrome, puerto `8091`.
- `5`: Salir.

## 8. Probar lectura de boletas

Los archivos de prueba estan en:

```powershell
.\Producto\tag_ok\pdf_privados
```

Archivos utiles:

- `AUTOPISTA_CENTRAL_falso.csv`
- `AUTOPISTA_CENTRAL.csv`
- `COSTANERA_NORTE.pdf`
- `VESPUCIO_SUR.pdf`
- `VESPUCIO_NORTE_1.pdf`
- `VESPUCIO_NORTE_2.xlsx`

Para validar la extraccion PDF desde test:

```powershell
cd C:\Users\Naneuwu\Documents\GitHub\CAPSTOM_EC_DM_AC\Producto\tag_ok
flutter test test\pdf_test.dart
```

El test esperado debe extraer transacciones de Costanera Norte, Vespucio Sur y Vespucio Norte.

## 9. Problemas comunes

### Error con `adb` o `.android`

Si al ejecutar:

```powershell
flutter devices
```

aparece un error parecido a:

```text
Cannot mkdir '\.android': Permission denied
```

puedes evitarlo ejecutando directamente en Chrome:

```powershell
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8090 --no-web-experimental-hot-reload
```

Ese problema afecta la deteccion de dispositivos Android, pero no necesariamente impide ejecutar la version web.

### Puerto ocupado

Si `8090` ya esta ocupado, cambia el puerto:

```powershell
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8092 --no-web-experimental-hot-reload
```

En esta maquina, durante la ultima ejecucion, `8090` estaba ocupado y la app principal se levanto correctamente en:

```text
http://127.0.0.1:8092
```

### `flutter analyze` muestra muchos warnings

Puedes correr:

```powershell
flutter analyze
```

Actualmente el proyecto puede mostrar warnings e infos existentes, como imports no usados, `print` en codigo de desarrollo o APIs deprecadas. Eso no necesariamente bloquea levantar la app.

## 10. Resumen rapido

App principal:

```powershell
cd C:\Users\Naneuwu\Documents\GitHub\CAPSTOM_EC_DM_AC
$env:PATH = "$PWD\.tools\flutter\bin;$env:PATH"
if (!(Test-Path .\Producto\tag_ok\.env)) { New-Item -ItemType File .\Producto\tag_ok\.env }
cd .\Producto\tag_ok
flutter pub get
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8090 --no-web-experimental-hot-reload
```

Panel admin:

```powershell
cd C:\Users\Naneuwu\Documents\GitHub\CAPSTOM_EC_DM_AC
$env:PATH = "$PWD\.tools\flutter\bin;$env:PATH"
if (!(Test-Path .\Producto\admin\.env)) { New-Item -ItemType File .\Producto\admin\.env }
cd .\Producto\admin
flutter pub get
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8091 --no-web-experimental-hot-reload
```
