# Registro de cambios: módulo Estacionamientos

**Rama:** `Estephany` · **Responsable:** Estephany Cárdenas (Arquitecta de Software y BD)

Este archivo reúne los cambios del módulo Estacionamientos. Cada cambio nuevo se agrega como una sección más, al final.

- **Alcance del módulo:** HU-15 a HU-21, RF-016 a RF-022, CU15 a CU21, épica EP-03 (planificado para el Sprint 4).
- **Reparto del trabajo:** Almendra Cifuentes hace el front y algunas reglas (al 11-nov todavía no están en GitHub). Este archivo registra la parte de arquitectura, base de datos e IA, y la integración de ambas partes.
- **Números de línea:** corresponden a la versión de cada archivo **en la fecha del cambio**. Si el archivo cambia después, pueden moverse.
- **Rutas:** todas son relativas a `Producto/tag_ok/`.

## Índice

| # | Fecha | Cambio | Requisito | Estado |
|---|---|---|---|---|
| 1 | 11-nov | [Reglas de Firestore para `estacionamientos`](#1-reglas-de-firestore-para-estacionamientos) | HU-15 a HU-21 / RF-016 a RF-022 | Tests OK en el emulador, **sin publicar** |

## Qué piden los requisitos

| HU / CU | RF | Qué pide |
|---|---|---|
| HU-15 / CU15 | RF-016 | Registrar manualmente: vehículo, fecha, lugar, hora de entrada, hora de salida, costo y observación |
| HU-16 / CU16 | RF-017 | **Iniciar estacionamiento:** registra el inicio y empieza a contar el tiempo. El estacionamiento queda **activo** hasta finalizarlo |
| HU-17 / CU17 | RF-018 | **Finalizar estacionamiento:** registra la hora de término y calcula la duración. Exige un estacionamiento iniciado antes |
| HU-18 / CU18 | RF-019 | Guardar la ubicación GPS para recordar dónde quedó el vehículo |
| HU-19 / CU19 | RF-020 | Registrar con IA desde la foto del ticket o boleta: lugar, fecha, entrada, salida, duración y monto **cuando estén disponibles** |
| HU-20 / CU20 | RF-021 | Completar o corregir a mano lo que la IA no reconoció. Un campo no obligatorio se puede dejar vacío |
| HU-21 / CU21 | RF-022 | Confirmar explícitamente antes de guardar un registro hecho con IA |

Fuente: `Lista de C. U. __ Historias de Usuario, Épicas, Sprint, etc (1).xlsx`, `Plantillas de C.U. por cada C.U (1).docx` y `Lista de requerimientos funcionales y no funcionales`.

**Relacionados fuera del módulo:**
- **HU-45 / RF-048:** gastos por categoría en el dashboard. Ya leen la colección `estacionamientos`.
- **HU-46 / RF-049:** acción rápida "Registrar estacionamiento" en el Inicio. Hoy abre una pantalla de "próximamente".

---

## 1. Reglas de Firestore para `estacionamientos`

### Para qué
Firestore deniega todo lo que no está en las reglas, así que sin ellas la app no puede guardar ni leer estacionamientos. Las reglas se escribieron desde la arquitectura y la base de datos; cuando Almendra suba su parte, se comparan con las suyas y se unifican.

### Decisiones (11-nov, Estephany)
- **Dueño en `uid`:** igual que mantenciones y cargas, y es el nombre con el que el Inicio y Gastos ya buscan los estacionamientos (`lib/screens/inicio_dashboard_screen.dart:132` y `lib/screens/dashboard/gastos_historial.dart:111`). El diccionario de datos no tiene un campo de dueño para ESTACIONAMIENTOS: hay que agregarlo.
- **`hora_entrada` y `hora_salida` guardan fecha y hora completas** (timestamp), no solo la hora como dice el diccionario (`TIME`). Así el cronómetro sobrevive al cierre de la app y la duración se calcula bien aunque pase la medianoche.
- **Un estacionamiento finalizado no se modifica**, igual que las cargas. Si hay un error, se borra y se registra de nuevo.
- **El cronómetro solo se inicia con "Iniciar estacionamiento"** (CU16). Un registro hecho con IA se guarda siempre como `finalizado`, con lo que se leyó o se completó a mano (CU19 a CU21). Esto se contrastó con las plantillas de casos de uso:
  - el flujo de IA termina en confirmar y guardar, y nunca inicia un cronómetro;
  - si falta un dato, el usuario lo completa o lo deja vacío (CU19 E1, CU20 E1).

### Campos

| Campo | Obligatorio | Tipo y validación |
|---|---|---|
| `uid` | Sí | Texto. Tiene que ser el usuario que guarda. No se puede cambiar |
| `vehiculo_id` | Sí | Texto. El vehículo tiene que ser del usuario. No se puede cambiar |
| `fecha` | Sí | Fecha y hora. No se puede cambiar |
| `estado` | Sí | `activo` (cronómetro corriendo) o `finalizado` |
| `origen_registro` | Sí | `manual` o `ia`. No se puede cambiar |
| `hora_entrada` | No | Fecha y hora. No se puede cambiar |
| `hora_salida` | No | Fecha y hora; no puede ser anterior a la entrada |
| `duracion_min` | No | Entero entre 0 y 43.200 (30 días) |
| `costo` | No | Pesos, entero entre 0 y 10.000.000 |
| `lugar` | No | Texto de hasta 100 caracteres |
| `observacion` | No | Texto de hasta 500 caracteres |
| `ubicacion` | No | Coordenadas GPS (GeoPoint) |
| `fecha_captura` | No | Fecha y hora en que se leyó el ticket |
| `confianza_ia` | No | Número entre 0 y 100 |

Los campos no obligatorios pueden faltar o ser `null`, para permitir registros parciales. No hay `archivo_path`, porque no se guarda la foto del ticket (RF-055).

### Funciones (`firestore.rules`)
- **Encabezado** (línea 62): describe la colección, sus campos y tipos, junto a las demás colecciones.
- **`estacionamientoValido(d)`** (línea 453): valida el documento completo.
  - Solo acepta los campos de la tabla; cualquier otro hace fallar el registro.
  - Revisa los obligatorios, los tipos y los límites de cada campo.
  - Con las dos horas, la salida no puede ser anterior a la entrada.
  - **`activo`** exige `hora_entrada`, no permite `hora_salida` y solo puede ser `manual`.
- **`match /estacionamientos/{estacionamientoId}`** (línea 480):
  - **Leer y borrar:** solo el dueño.
  - **Crear:** con el `uid` propio y en un vehículo propio (`vehiculoEsDe`).
  - **Modificar** (línea 491): **solo mientras está `activo`**.
    - Se pueden cambiar `hora_salida`, `duracion_min`, `costo`, `estado`, `lugar`, `observacion` y `ubicacion`.
    - Para pasar a `finalizado` es obligatoria la `hora_salida` (RF-018).
    - `uid`, `vehiculo_id`, `fecha`, `hora_entrada` y `origen_registro` no se pueden cambiar.
- **Lo que las reglas no pueden exigir:** "un solo estacionamiento activo por vehículo". Lo tiene que controlar la app.

### Pruebas (`tools/rules_test/rules.test.js`, "Prueba 11", línea 381)

| Test | Qué comprueba |
|---|---|
| 11a | Crear manual propio pasa; con `uid` ajeno, sin sesión o con vehículo ajeno falla |
| 11b | Registro parcial: solo fecha, estado y origen son obligatorios |
| 11c | Con IA se crea finalizado; la IA no puede crear uno activo |
| 11d | Cronómetro: activo con entrada y sin salida pasa; sin entrada o con salida falla |
| 11e | Fallan: estado u origen inventados, costo negativo o con decimales, duración excesiva, salida antes de la entrada, ubicación en texto, hora como texto ("10:30"), campos extra y lugar demasiado largo |
| 11f | Finalizar con hora de salida pasa; sin ella, o cambiando `uid`, vehículo, fecha, entrada u origen, falla |
| 11g | Un estacionamiento finalizado no se modifica |
| 11h | El dueño lee, lista por `uid` (la misma consulta del Inicio y Gastos) y borra; otro usuario no lee, no edita ni borra |

**Resultado:** las 8 pruebas nuevas pasan (49 de 50 en total). La que falla, `8g` (mantenciones), ya fallaba antes de este cambio: espera que se rechace un tipo de mantención inventado, pero las reglas aceptan títulos libres desde el Sprint 3.

**Cómo ejecutarlas** (desde `tools/rules_test`, con el emulador):
```
firebase emulators:exec --only firestore --project demo-tag-ok --config firebase.json "node --test --test-concurrency=1 rules.test.js"
```

---

## Pendiente

| Pendiente | Quién |
|---|---|
| **Publicar las reglas** (`firebase deploy --only firestore:rules --project tag-ok-v2`), avisando antes al equipo | Estephany |
| **Subir el front** a una rama propia, aunque no esté terminado | Almendra |
| **Comparar reglas** con las de Almendra y acordar los nombres de campos con su front | Ambas |
| **Modelo y servicio** de estacionamientos en la app, y conexión con Inicio (HU-46), Gastos y auditoría | Al integrar |
| **IA del ticket** (HU-19 a HU-21): agregar el tipo "ticket de estacionamiento" al componente de IA | Estephany |
| **Diccionario de datos:** agregar el dueño (`uid`) y cambiar `hora_entrada` y `hora_salida` a fecha y hora | Estephany |
| **Plantillas de casos de uso:** CU19 dice "Gemini API"; la app usa OpenAI | Documentación |
