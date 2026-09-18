# Sprint actual: Sprint 2 — Mi Vehículo + Registro Inteligente con IA

**Duración:** 28 de septiembre al 11 de octubre de 2026
**Responsable principal:** Estephany Cárdenas (arquitectura/BD/IA), con apoyo del equipo
**Objetivo del Sprint:** Desarrollar el módulo Mi Vehículo y construir el componente
transversal de Registro Inteligente con IA. Este componente es prioritario porque los
Sprints siguientes (Mantenciones, Estacionamientos, Combustible) lo van a reutilizar
para procesar sus propias boletas/tickets — no debe reconstruirse por módulo.

## Alcance funcional de este Sprint

### Épica EP-01: Mi Vehículo (CU1 a CU7 / HU-01 a HU-07 / RF-001 a RF-008)

| CU | HU | RF | Nombre |
|---|---|---|---|
| CU1 | HU-01 | RF-001 | Registrar vehículo |
| CU2 | HU-02 | RF-002 | Modificar información del vehículo |
| CU3 | HU-03 | RF-003, RF-051, RF-055 | Gestionar documentos del vehículo |
| CU4 | HU-04 | RF-004 | Configurar vencimientos |
| CU5 | HU-05 | RF-005 | Visualizar estado general del vehículo |
| CU6 | HU-06 | RF-006, RF-007 | Registrar documento vehicular con IA |
| CU7 | HU-07 | RF-008, RF-051, RF-055 | Revisar y confirmar datos (documento vehicular) |

### Épica EP-06: Registro Inteligente con IA (CU33 a CU40 / HU-33 a HU-40 / RF-035 a RF-043)

Componente transversal — se construye una sola vez aquí y lo reutilizan Mantenciones
(Sprint 3), Estacionamientos y Combustible (Sprint 4).

| CU | HU | RF | Nombre |
|---|---|---|---|
| CU33 | HU-33 | RF-035, RF-040 | Capturar evidencia |
| CU34 | HU-34 | RF-036, RF-040, RF-041 | Identificar tipo de documento |
| CU35 | HU-35 | RF-037, RF-041, RF-043 | Extraer datos con IA |
| CU36 | HU-36 | RF-038, RF-041, RF-043 | Validar información detectada |
| CU37 | HU-37 | RF-038, RF-039 | Confirmar información |
| CU38 | HU-38 | RF-038, RF-041 | Corregir o completar datos |
| CU39 | HU-39 | RF-039, RF-042, RF-054 | Guardar en módulo correspondiente |
| CU40 | HU-40 | RF-040 | Registrar manualmente (alternativa sin IA) |

El detalle completo (secuencia paso a paso, precondiciones, excepciones, criterios de
aceptación) de cada CU/HU está en `03-casos-de-uso.md` y `02-historias-usuario.md`.
Buscar por el código (ej. "CU6", "HU-35") en esos archivos.

## Entidades de datos involucradas (ver 04-diccionario-datos.md para el detalle completo)

- **VEHICULOS** — entidad central de este Sprint, se crea aquí.
- **DOCUMENTOS_VEHICULARES** — Permiso de Circulación, Revisión Técnica, SOAP, seguro.
- **NOTIFICACIONES** — para las alertas de vencimiento configuradas en CU4 (el envío real
  se implementa en el Sprint 5 / EP-08, pero el campo de configuración de vencimiento sí
  se implementa aquí).
- **AUDITORIA** — cada operación de registro/confirmación vía IA debe dejar traza (RF-054).

## Reglas no funcionales que aplican directamente a este Sprint (ver RNF completos en 01)

Estas son las más críticas para el componente de IA que se construye aquí:

- **RNF-004 (Control del usuario sobre la IA):** ningún dato detectado por IA se persiste
  automáticamente. Siempre debe pasar por pantalla de revisión + confirmación explícita.
- **RNF-005 (Validación antes de persistencia):** todo flujo inteligente termina en una
  pantalla de revisión con campos editables y una acción explícita de confirmación.
- **RNF-006 (Trazabilidad):** cada captura conserva origen (manual/ia) y fecha de captura.
  Ver campos `origen_registro`, `fecha_captura`, `confianza_ia` en el diccionario de datos.
- **RNF-007 (Esquema desacoplado para IA):** usar un esquema JSON por tipo de documento
  para desacoplar el motor de IA (Gemini) del front y del modelo de datos — no acoplar
  directamente el parsing de la respuesta de Gemini a los widgets de UI.
- **RNF-010 (Tiempo de respuesta IA):** máximo 15 segundos entre la captura y la precarga
  editable, en condiciones normales de conexión.
- **RNF-011 (Disponibilidad ante falla de IA):** si Gemini no responde o falla, informar
  al usuario y ofrecer el ingreso manual (CU40) sin bloquear el flujo.
- **RNF-041 / patrón "no inventar":** un campo que la IA no reconozca debe quedar vacío,
  nunca con un valor inferido o ficticio.

## Contexto técnico ya resuelto (no repetir este trabajo)

- La integración con Gemini API ya existe y funciona en `audit_screen.dart` (heredado de
  Fase 1, usado para auditoría de boletas TAG). Tiene un patrón de fallback en cascada de
  modelos (`_generateContentWithFallback()`) que vale la pena **reutilizar o generalizar**
  para el nuevo componente de Registro Inteligente, en vez de escribir la integración con
  Gemini desde cero.
- Las credenciales (Firebase + Gemini) del proyecto `tag-ok-v2` ya están correctamente
  cargadas vía `.env` (`flutter_dotenv`) tanto en `Producto/tag_ok` como en `Producto/admin`.
  No hardcodear keys nuevas ni crear blobs Base64 — usar `dotenv.env['GEMINI_API_KEY']`.

## Qué NO corresponde a este Sprint (para no adelantarse)

- Mantenciones, Estacionamientos, Combustible, Beneficios → Sprints 3, 4 y 5.
- Dashboard "Mi Auto" → Sprint 5.
- Envío real de notificaciones (push/in-app) → Sprint 5 / EP-08. En este Sprint solo se
  guarda la configuración de vencimiento (fecha + antelación deseada).
