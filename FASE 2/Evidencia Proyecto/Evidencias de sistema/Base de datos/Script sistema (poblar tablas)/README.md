# TAG OK – Fase 2 · Script de sistema (poblar tablas)

Puebla las colecciones de **Cloud Firestore** con datos de ejemplo (ficticios) que siguen el
*Diccionario de datos* y la *Descripción de las colecciones*: mismos campos, mismos valores
permitidos y las mismas relaciones.

## Archivos

| Archivo | Qué hace |
|---|---|
| `datos.js` | Define todos los documentos de ejemplo. No se conecta a Firebase. |
| `validar.js` | Comprueba que las referencias y los valores sean coherentes con el modelo. |
| `poblar_firestore.js` | Script principal: valida y escribe en Firestore. |

## Qué se crea (203 documentos)

| Colección | Docs | Notas |
|---|---|---|
| usuarios | 3 | + subcolecciones `trips` (7) y `audited_invoices` (3) |
| administradores | 2 | un `super_admin` y un `operador` |
| concesionarias | 4 | AC, CN, VS, VN |
| porticos | 16 | 8 en formato carga inicial (id numérico) y 8 en formato panel admin |
| beneficios | 8 | una categoría «Otros» con `categoria_otra` |
| vehiculos | 6 | auto, moto, camioneta y eléctrico; `id_usuario` es referencia |
| documentos_vehiculares | 18 | permiso, revisión técnica, SOAP y seguro; manual e IA |
| mantenciones | 12 | 7 realizadas y 5 programadas |
| estacionamientos | 8 | uno en `pendienteComprobante` |
| abastecimientos | 11 | combustible y carga eléctrica |
| notificaciones | 64 | generadas desde los vencimientos y las mantenciones programadas |
| auditoria | 41 | formato app y formato panel admin |

`estacionamientos_activos` queda vacía (como en la base real: no hay cronómetro corriendo).
Las colecciones heredadas (`tarifas`, `alertas`, `componentes_mantencion`) no se pueblan.

Los ids son fijos (por ejemplo `veh_krtp45`, `doc_krtp45_soap`) para que el script se pueda
ejecutar varias veces sin duplicar datos. En la app real Firestore genera ids automáticos.

## Cómo usarlo

```bash
npm install

# 1) Solo validar (no toca Firebase)
npm run validar

# 2) Poblar
export GOOGLE_APPLICATION_CREDENTIALS=/ruta/a/serviceAccountKey.json   # Windows PowerShell: $env:GOOGLE_APPLICATION_CREDENTIALS="C:\ruta\clave.json"
node poblar_firestore.js
```

El script muestra el proyecto y pide escribir su id para confirmar antes de escribir.

Opciones: `--auth` (crea también las cuentas en Firebase Authentication con la contraseña de
prueba `TagOk2026!`), `--limpiar` (borra **solo** los documentos que crea este script),
`--proyecto <id>`, `--yes` (sin confirmación), `--dry-run`.

### Obtener la clave de la cuenta de servicio
Firebase Console → Configuración del proyecto → Cuentas de servicio → *Generar nueva clave privada*.

## Seguridad

- **No subas la clave JSON a GitHub.** El `.gitignore` incluido ya la excluye, igual que `.env`.
- Úsalo en un proyecto de pruebas o con el emulador (`FIRESTORE_EMULATOR_HOST=127.0.0.1:8080`)
  si no quieres mezclar estos datos con los reales. Con el emulador no pide confirmación.
