# Documentación de contexto — TAG OK Versión 2.0 (Fase 2)

Esta carpeta contiene la documentación funcional del proyecto en formato texto/markdown,
para que Claude Code pueda leerla directamente del repositorio en cada sesión de trabajo,
sin depender de que se le pegue contenido manualmente.

## Orden de lectura recomendado para Claude Code

1. **00-sprint-actual.md** — SIEMPRE empezar aquí. Define qué Sprint se está desarrollando
   ahora mismo y qué CU/HU/RF corresponden. Se actualiza al inicio de cada Sprint.
2. **01-requerimientos-fase2.md** — Los 55 RF + 12 RNF completos, por módulo.
3. **02-historias-usuario.md** — Las 50 HU con criterios de aceptación, trazadas a CU/RF/Épica/Sprint.
4. **03-casos-de-uso.md** — Las 50 plantillas de CU completas (actores, precondición, secuencia,
   postcondición, excepciones).
5. **04-diccionario-datos.md** — Modelo de datos completo (Firestore), campos, tipos y relaciones.
6. **05-arquitectura-tecnica.md** — Stack tecnológico y decisiones de arquitectura.

## Regla de oro para Claude Code

Antes de implementar cualquier funcionalidad nueva, leer primero `00-sprint-actual.md`
para saber el alcance exacto del Sprint, y consultar el detalle de cada CU/HU/RF en los
documentos 01-04 según se necesite. No inventar campos, flujos ni validaciones que no
estén en estos documentos — si algo no está definido, preguntar antes de asumir.
