# Desviaciones respecto al Diccionario de Datos oficial — TAG OK Fase 2

Este documento persiste entre Sprints (a diferencia de `00-sprint-actual.md`, que se
reescribe en cada uno). Registra cada punto donde la implementación real se desvía de
`04-diccionario-datos.md` (el diccionario formal presentado como entregable del
proyecto), junto con la razón y si ya fue validado con Grupo Sentte.

## Registro de desviaciones

### 1. `VEHICULOS.usuario_id` → implementado como `id_usuario` (DocumentReference)

- **Qué dice el diccionario:** `usuario_id` — `VARCHAR(24)` — FK → USUARIOS (string).
- **Qué se implementó (Sprint 2):** `id_usuario` — `DocumentReference` hacia el
  documento de usuario, no un string plano.
- **Por qué:** la colección `vehiculos` heredada de Fase 1 ya contiene documentos reales
  de usuarios con `id_usuario` como `DocumentReference`. Forzar el tipo string del
  diccionario habría roto la lectura de todos los vehículos ya registrados en
  producción/pruebas, o habría requerido una migración de datos no planificada.
- **Decisión de nombre del campo:** además del cambio de tipo, el nombre del campo
  coexiste como `id_usuario` (convención de Fase 1) en vez de `usuario_id` (convención
  del diccionario Fase 2). Se mantuvo el nombre de Fase 1 por el mismo motivo: es el que
  ya existe en los datos reales.
- **Estado:** implementado. **Pendiente validar con Grupo Sentte** — mencionar en el
  próximo Sprint Review que el diccionario de datos formal difiere del código real en
  este campo específico, y decidir si se actualiza el diccionario para que refleje la
  implementación (recomendado) o si se hace una migración de datos más adelante para
  alinear con el diccionario original (no recomendado salvo que Grupo Sentte lo pida
  explícitamente).

### 2. `categoria` (Fase 1) y `tipo_vehiculo` (Fase 2) coexisten como campos separados

- **Qué dice el diccionario:** solo aparece `tipo_vehiculo`.
- **Qué se implementó:** ambos campos coexisten en el mismo documento de `vehiculos`.
  `categoria` (AUTO/MOTO/etc.) sigue siendo usado por el motor de tarifas TAG heredado
  de Fase 1; `tipo_vehiculo` (SUV/Sedán/etc.) es el nuevo campo descriptivo de Fase 2.
- **Por qué:** son conceptos distintos (uno tarifario, uno descriptivo) aunque ambos
  describan "tipo de vehículo". Fusionarlos habría requerido decidir una taxonomía única
  y migrar la lógica de tarifas de Fase 1, fuera de alcance de este Sprint.
- **Estado:** implementado, funcionando. No requiere validación urgente con Grupo Sentte
  (es aditivo, no reemplaza nada existente), pero vale la pena mencionarlo igual en el
  Sprint Review para que quede trazado por qué el diccionario formal no lista ambos
  campos por separado.

## Cómo usar este documento

Cuando Claude Code encuentre una nueva desviación entre lo que pide `04-diccionario-datos.md`
y lo que exige el código heredado o una restricción técnica real, se agrega una entrada
nueva acá con el mismo formato (qué dice el diccionario / qué se implementó / por qué /
estado). No se borran entradas antiguas aunque se resuelvan — se marca su estado como
"Resuelto" y se explica cómo.
