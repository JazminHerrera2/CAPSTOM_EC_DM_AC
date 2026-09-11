# TAG OK Admin

Panel web de administración para el ecosistema TAG OK.

## Qué incluye

- Dashboard inicial con KPIs del sistema.
- Listado de usuarios desde Firestore.
- Catálogo de pórticos compartido con la app principal.
- Vista base para tarifas y reportes.

## Base de datos compartida

Este proyecto apunta al mismo Firebase project que la app final. Las colecciones iniciales usadas por el admin son:

- `usuarios`
- `vehiculos`
- `porticos`
- `tarifas`
- `alertas`

## Arranque local

1. Ubícate en la carpeta `Producto/admin`.
2. Ejecuta `flutter pub get`.
3. Ejecuta `flutter run -d chrome` para abrir la versión web.

## Nota

El archivo `.env` contiene la configuración del proyecto Firebase usada para desarrollo local.
