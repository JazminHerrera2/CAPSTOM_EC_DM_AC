# Cambios Sprint 3: comprobante en el historial de mantenciones y reglas versionadas

**Rama:** `Estephany` · **Fecha:** 17-oct-2026 · **Estado:** subido a la rama, pendiente de revisión del equipo

Este documento resume dos cambios:

1. **Comprobante asociado en el historial de mantenciones**, para cumplir RF-010 (Módulo 2).
2. **Reglas de seguridad de Firestore versionadas en el repo**, en lugar de editarlas a mano en la consola.

---

## 1. Requerimiento trabajado: RF-010 "Visualizar historial de mantenciones"

**Texto actual del RF** (Módulo 2 de la lista de requerimientos):

| Campo | Texto |
|---|---|
| Descripción | Permite consultar una línea de tiempo cronológica con servicios realizados y **documentos asociados**. |
| Criterio de aceptación | El historial se presenta ordenado cronológicamente y permite consultar las mantenciones registradas. |

La frase viene de la presentación del cliente (diapositiva "Módulo 2 · Mantenciones y cuidado del vehículo").

### El problema
- La app **no guarda la imagen de la boleta**. Según el código, fue decisión del cliente ([mantencion_model.dart](Producto/tag_ok/lib/data/models/mantencion_model.dart)).
- Sin la imagen, el historial no tenía ningún "documento asociado", y RF-010 no se podía dar por cumplido.

### Opciones evaluadas
| Opción | Qué se guarda | Decisión |
|---|---|---|
| A. Archivo completo | La foto o PDF de la boleta en Storage | Descartada: más datos personales que proteger (una factura trae RUT y nombre del cliente), más trabajo y contradice la decisión del cliente |
| **B. Referencia al comprobante** | Tipo (boleta/factura/otro) y número del comprobante | **Elegida** |
| C. Quitar "documentos asociados" del RF | Nada | Descartada: el cliente lo pidió explícitamente en su presentación |

### Por qué la opción B
- Cumple "documentos asociados" **sin almacenar imágenes**: minimización de datos (RNF-002) y protección de datos personales (RNF-012).
- Respeta la decisión del cliente de no guardar la boleta.
- Es un cambio pequeño: 2 campos opcionales, sin Storage.
- Deja abierta la opción A: si más adelante se quiere ver la boleta, se agrega `archivo_path` sin rehacer nada.

### Cómo se ve en el historial
> **15-jul-2026 · Cambio de aceite** · Lubricentro Los Leones
> $129.900 · 78.500 km · Boleta N° 458123

Si no hay comprobante (por ejemplo, un mecánico particular que no da boleta), se muestra "Sin comprobante".

### Redacción propuesta para RF-010 (por validar con el equipo y Sentte)
| Campo | Texto propuesto |
|---|---|
| Descripción | Permite consultar una línea de tiempo cronológica con las mantenciones realizadas y la referencia del comprobante asociado (tipo y número de boleta o factura). |
| Criterio de aceptación | El historial muestra las mantenciones realizadas del vehículo, de la más reciente a la más antigua, con tipo, fecha, kilometraje, costo y comprobante cuando exista. No se almacena la imagen del comprobante. |

### Requerimientos relacionados
- **RF-013** (boleta con IA): la IA ahora también lee el tipo y número del comprobante.
- **RF-040** (ingreso manual): el comprobante también se puede ingresar a mano.
- **RNF-005** (validación antes de guardar): el usuario revisa y puede corregir el comprobante leído por la IA.

---

## 2. Archivos modificados y por qué

### 2.1 Comprobante en mantenciones (RF-010)

| Archivo | Qué se modificó | Por qué era necesario |
|---|---|---|
| [mantencion_model.dart](Producto/tag_ok/lib/data/models/mantencion_model.dart) | Nuevo tipo `TipoComprobante` (Boleta, Factura, Otro). Nuevos campos `tipoComprobante` y `numeroComprobante`. Nuevo texto `referenciaComprobante` (p. ej. "Boleta N° 458123") | El modelo define qué se escribe y se lee en Firestore. Sin estos campos, el dato no existiría |
| [mantencion_service.dart](Producto/tag_ok/lib/data/services/mantencion_service.dart) | `crear()` recibe los dos campos, y estos quedan en la lista de campos editables | Es el único punto por el que la app guarda mantenciones |
| [mantencion_extraction.dart](Producto/tag_ok/lib/features/registro_inteligente/mantencion_extraction.dart) | La IA devuelve `tipo_comprobante` y `numero_comprobante`. Se le indica buscarlos en el recuadro del SII, no confundirlos con RUT, patente o kilometraje, y **no extraer datos del cliente**. Se limpian prefijos como "N°" o "Folio:" | Para que la IA precargue el comprobante (RF-013) cumpliendo minimización de datos (RNF-002, RNF-012) |
| [registrar_mantenimiento_screen.dart](Producto/tag_ok/lib/screens/mantenimiento/registrar_mantenimiento_screen.dart) | Nueva sección "Comprobante": un selector (Sin comprobante / Boleta / Factura / Otro) y el campo "Número", que aparece solo si se elige un tipo. Se precarga con lo que leyó la IA | Ingreso manual (RF-040) y revisión de lo leído por la IA antes de guardar (RNF-005) |
| [tarjeta_mantencion.dart](Producto/tag_ok/lib/screens/mantenimiento/tarjeta_mantencion.dart) | Las mantenciones realizadas muestran "Boleta N° …" o "Sin comprobante" | Es la parte visible de RF-010 en el historial |
| [firestore.rules](Producto/tag_ok/firestore.rules) | `mantencionValida` acepta los dos campos (tipo solo `boleta`/`factura`/`otro`; número de hasta 50 caracteres), y ambos se pueden editar | Las reglas solo aceptan una lista cerrada de campos. Sin este cambio, Firestore rechazaría las mantenciones nuevas |
| [mantencion_model_test.dart](Producto/tag_ok/test/mantencion_model_test.dart) | Prueba: guardar y leer el comprobante, y que las mantenciones antiguas sin comprobante sigan funcionando | Comprobar que el cambio funciona y no rompe datos existentes |
| [mantencion_extraction_test.dart](Producto/tag_ok/test/mantencion_extraction_test.dart) | Prueba: lectura del comprobante, limpieza de "N°" / "Folio:" / "No.", tipos inválidos y largo máximo | Comprobar que lo leído por la IA siempre se puede guardar |
| [rules.test.js](Producto/tag_ok/tools/rules_test/rules.test.js) | Dos pruebas nuevas (8l y 8m): comprobante válido e inválido, y mantenciones antiguas sin comprobante | Comprobar que las reglas aceptan lo correcto y rechazan lo inválido |

**Campos nuevos en la colección `mantenciones`:**

| Campo | Tipo | Valores | Obligatorio |
|---|---|---|---|
| `tipo_comprobante` | string | `boleta` / `factura` / `otro` | No |
| `numero_comprobante` | string (máx. 50) | Folio, p. ej. "458123" | No |

Las mantenciones existentes no se modifican: se muestran como "Sin comprobante".

### 2.2 Reglas de Firestore versionadas en el repo

| Archivo | Qué se modificó | Por qué era necesario |
|---|---|---|
| `firestore.rules.borrador` → [firestore.rules](Producto/tag_ok/firestore.rules) | Se renombró (con `git mv`, conservando el historial) y el encabezado "BORRADOR - NO PUBLICADO" se cambió por uno que lo marca como la versión oficial | Las reglas **sí estaban publicadas**, pero se habían copiado a mano en la consola. La consola tenía una versión anterior a la del repo y nadie lo sabía. El encabezado "NO PUBLICADO" era engañoso |
| [firebase.json](Producto/tag_ok/firebase.json) | Nueva sección `"firestore": { "rules": "firestore.rules" }` | Permite publicar las reglas desde el archivo del repo con un comando, sin copiar y pegar. No cambia el deploy de la web (`--only hosting`) |
| [rules.test.js](Producto/tag_ok/tools/rules_test/rules.test.js) | La ruta del archivo de reglas pasa de `firestore.rules.borrador` a `firestore.rules` | Con el cambio de nombre, las pruebas de reglas habían quedado apuntando a un archivo inexistente |
| [rules.test.js](Producto/tag_ok/tools/rules_test/rules.test.js) | El entorno de prueba se inicializa en el primer `beforeEach` en vez de en un `before()` global | Con Node 22.0.0, el `before()` global no se espera antes de las pruebas: las 29 fallaban con `Cannot read properties of undefined (reading 'clearFirestore')` sin llegar a probar ninguna regla |

---

## 3. ⚠️ Orden obligatorio al publicar

Las reglas publicadas hoy **no aceptan** los campos de comprobante. Si se publica primero la app, **ninguna mantención nueva se podrá guardar**.

1. Publicar las reglas:
   ```
   firebase deploy --only firestore:rules --project tag-ok-v2
   ```
   Las reglas nuevas también aceptan mantenciones sin comprobante, así que la versión actual de la app sigue funcionando.
2. Después, publicar la app web:
   ```
   flutter build web --release
   firebase deploy --only hosting --project tag-ok-v2
   ```
3. La app Android debe instalarse **después** del paso 1.

---

## 4. Verificación

| Prueba | Resultado |
|---|---|
| Pruebas de Dart (`mantencion_model_test`, `mantencion_extraction_test`) | ✅ 9 de 9 pasan |
| Análisis estático (`flutter analyze`) de los archivos modificados | ✅ Sin errores (solo 5 avisos antiguos de `withOpacity`, no relacionados) |
| Pruebas de reglas en el emulador (`rules.test.js`) | ✅ 29 de 29 pasan, incluidas las nuevas 8l y 8m (17-oct-2026) |
| Prueba manual en la app: registro manual con boleta | ✅ 17-oct-2026, en local (Edge) contra `tag-ok-v2`: el historial muestra "Boleta N° 458123" y Firestore guardó `tipo_comprobante: "boleta"` y `numero_comprobante: "458123"` |
| Prueba manual en la app: lectura con IA | ✅ 17-oct-2026, con la boleta ficticia [documentos_prueba/boleta_mantencion_prueba.pdf](documentos_prueba/boleta_mantencion_prueba.pdf): la IA precargó correctamente los 8 campos (incluidos Boleta y N° 512037) y no cayó en las trampas del documento (N° de orden de trabajo, kilometraje de la observación, monto del IVA). En un intento previo con un PDF mal recortado, la IA dejó vacío el costo que no podía leer, en vez de inventarlo (RF-041) |
| Prueba manual en la app: "Sin comprobante" | ✅ 17-oct-2026: el historial muestra "Sin comprobante" y las 3 mantenciones de prueba aparecen ordenadas de la más reciente a la más antigua |

Para correr las pruebas de reglas (desde `Producto/tag_ok/tools/rules_test`):
```
firebase emulators:exec --only firestore --project demo-tag-ok "node --test rules.test.js"
```
Los mensajes `PERMISSION_DENIED` en la salida son normales: corresponden a las operaciones que las reglas deben bloquear.

**En Windows**, el emulador a veces queda encendido en segundo plano al terminar, y la siguiente ejecución falla con `port taken`. Para cerrarlo (PowerShell):
```
Get-CimInstance Win32_Process -Filter "Name='java.exe'" | Where-Object { $_.CommandLine -like '*cloud-firestore-emulator*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
```

---

## 5. Pendientes

- [ ] Confirmar con Sentte que "documentos asociados" se cumple con la referencia del comprobante.
- [ ] Actualizar la redacción de RF-010 en la lista de requerimientos (sección 1).
- [ ] Actualizar MANTENCIONES en el modelo relacional: agregar `tipo_comprobante VARCHAR(20)` y `numero_comprobante VARCHAR(50)`. Siguen pendientes también `estado`, `tipo_otro`, `confianza_ia` y `uid`, que ya existen en Firestore.
- [x] Correr las pruebas de reglas (sección 4).
- [x] Prueba manual en la app con boleta (sección 4).
- [x] Prueba manual con IA (sección 4).
- [x] Prueba manual con "Sin comprobante" (sección 4).
- [ ] Borrar el vehículo de prueba `PRUE01` (y con él sus mantenciones) desde Mi Vehículo.
- [x] Publicar las reglas (paso 1 de la sección 3): hecho el 17-oct-2026 con `firebase deploy --only firestore:rules`.
- [ ] Publicar la app web y la Android (pasos 2 y 3 de la sección 3), después de la prueba manual.

---

## 6. Mensaje de commit sugerido

```
Mantenciones: comprobante asociado en el historial (RF-010) y reglas versionadas

- Guarda tipo y número del comprobante (boleta/factura) para mostrarlo en el
  historial como documento asociado, sin almacenar la imagen (RNF-002, RNF-012).
  La IA lo lee del recuadro del SII y el usuario puede corregirlo.
- Las reglas de Firestore pasan a firestore.rules y se publican desde
  firebase.json; antes se copiaban a mano y la consola estaba desactualizada.
```
