# Script para poblar la base de datos (datos de prueba)

`poblar_bd.js` crea datos de prueba en el **emulador local de Firebase** (Authentication + Firestore), con las colecciones que la app usa hoy y **en el mismo formato en que la app las guarda**.

> **No toca la base real.** El script solo funciona contra el emulador local con el proyecto ficticio `demo-tag-ok`. Si detecta otro proyecto u otro servidor, se detiene sin escribir nada. Nunca se conecta a `tag-ok-v2`.

## Qué datos crea

| Colección | Cantidad | Contenido |
|---|---|---|
| Authentication | 3 cuentas | 2 conductores y 1 administrador (contraseña de todas: `Demo1234!`) |
| `usuarios` | 2 | Perfil de cada conductor |
| `administradores` | 1 | Cuenta del panel admin (`super_admin`) |
| `vehiculos` | 3 | 2 de Camila y 1 de Matías (`id_usuario` como referencia, igual que la app) |
| `documentos_vehiculares` | 8 | Permiso, SOAP, revisión técnica y seguro; algunos ingresados con IA y uno vencido |
| `mantenciones` | 9 | Realizadas (con boleta, factura, "otro" o sin comprobante; una de tipo "otra") y programadas (por fecha, por kilometraje o ambos) |
| `notificaciones` | 23 | Avisos generados igual que la app: 30, 15 y 7 días antes del vencimiento de documentos, y 7 días antes y el mismo día de las mantenciones programadas. Los avisos cuya fecha ya pasó no se crean |
| `auditoria` | 11 | Formato de la app (creación de documentos y un vehículo eliminado) y formato del panel admin |
| `porticos` | 104 | Datos públicos de las autopistas, desde `Base de datos/EXPORTACION_BASE_DE_DATOS.json` |
| `usuarios/{uid}/trips` | 4 | Viajes TAG de Camila (Fase 1) |
| `usuarios/{uid}/audited_invoices` | 1 | Factura TAG auditada de Camila (Fase 1) |

| Cuenta | Correo | Rol |
|---|---|---|
| Camila Rojas | camila.rojas@example.com | Conductora (2 vehículos) |
| Matías Soto | matias.soto@example.com | Conductor (1 vehículo) |
| Administración TAG OK | admin.tagok@example.com | `super_admin` del panel |

Las fechas se calculan **a partir del día en que se ejecuta el script**, así siempre hay avisos vigentes, documentos por vencer y mantenciones próximas.

**No se crean** `estacionamientos`, `abastecimientos` ni `beneficios` (módulos aún no implementados), ni `tarifas` (ningún código de la app la escribe). Los campos `archivo_path` y `foto_path` quedan vacíos, porque los archivos se guardan en Supabase Storage, que no forma parte del emulador de Firebase.

Todos los datos son ficticios, salvo los pórticos (información pública de las autopistas).

## Requisitos (una sola vez)

- Node.js y Java instalados.
- Herramienta de Firebase: `npm install -g firebase-tools`
- Dependencias, desde `Producto/tag_ok/tools`: `npm install`

## Cómo ejecutarlo

Desde `Producto/tag_ok/tools/poblar_bd`:

**Opción 1: poblar y revisar los datos en el navegador**

Terminal 1 (deja el emulador encendido):
```
firebase emulators:start --project demo-tag-ok
```

Terminal 2:
```
node poblar_bd.js
```

Después abre **http://127.0.0.1:4000**: en la pestaña *Firestore* se ven las colecciones y en *Authentication*, las cuentas. Para cerrar, presiona `Ctrl + C` en la terminal 1.

**Opción 2: poblar y guardar una copia de los datos**

```
firebase emulators:exec --only firestore,auth --project demo-tag-ok --export-on-exit ./datos_demo "node poblar_bd.js"
```

Para volver a abrir esos datos más tarde:
```
firebase emulators:start --project demo-tag-ok --import ./datos_demo
```

Cada ejecución de `poblar_bd.js` **borra los datos del emulador y los vuelve a crear**, así el resultado es siempre el mismo.

## Notas

- En Windows, si al ejecutar aparece `port taken`, quedó un emulador encendido de una ejecución anterior. Ciérralo (PowerShell):
  ```
  Get-CimInstance Win32_Process -Filter "Name='java.exe'" | Where-Object { $_.CommandLine -like '*cloud-firestore-emulator*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
  ```
- El script fue verificado con las reglas de seguridad del proyecto (`firestore.rules`): cada usuario puede leer y guardar sus propios datos sembrados, y no puede leer los de otro usuario.
- El campo del dueño se llama `uid` en `documentos_vehiculares` y `mantenciones`, igual que en la base real. Cuando se haga la migración a `usuario_id` (Sprint 4), hay que actualizar también este script.
