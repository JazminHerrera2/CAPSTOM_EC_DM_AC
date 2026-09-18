# Arquitectura Técnica — TAG OK Versión 2.0 (Fase 1 + Fase 2)

## Stack tecnológico

- **Cliente (móvil + web):** Flutter/Dart. Una sola app para conductores (Producto/tag_ok)
  y un panel administrador web separado (Producto/admin), ambos sobre el mismo proyecto
  Firebase `tag-ok-v2`.
- **Backend / datos:** Firebase Cloud Firestore (base de datos documental).
- **Almacenamiento de archivos:** Firebase Storage (fotos de vehículos, documentos
  vehiculares, comprobantes capturados por IA, imágenes de beneficios).
- **Autenticación:** Firebase Authentication.
- **IA:** Google Gemini API (SDK oficial `google_generative_ai`), usada para:
  - Auditoría de boletas TAG (ya existente desde Fase 1, en `audit_screen.dart`).
  - Registro Inteligente con IA (nuevo, transversal a los módulos de Fase 2 — se construye
    en Sprint 2 y lo reutilizan Mantenciones, Estacionamientos y Combustible).
  - Patrón de fallback en cascada de modelos: si un modelo falla o está deprecado, se
    intenta el siguiente de una lista ordenada (ver `_generateContentWithFallback()`).
- **Geolocalización y rutas:** Mapbox Directions API (heredado de Fase 1, sin cambios).
- **Motor de tarifas TAG:** motor local heredado de Fase 1, no depende de servicios
  externos de peaje.
- **Configuración de credenciales:** variables de entorno vía `flutter_dotenv`, cargadas
  desde `.env` (nunca hardcodeadas ni en blobs Base64 en el código fuente). Cada proyecto
  Flutter (`tag_ok` y `admin`) tiene su propio `.env`, ambos excluidos de git.

## Capas de la arquitectura

1. **Capa Cliente (Flutter/Dart):** apps móviles (iOS/Android) y Flutter Web.
   - Módulos existentes de Fase 1: Dashboard de Resumen, Sistema de Alertas, Simulación y Mapas.
   - Módulos nuevos de Fase 2: Mi Vehículo, Mantenciones, Estacionamientos, Combustible,
     Beneficios, Dashboard "Mi Auto".
   - Backoffice Admin (web): Gestión de tarifas y precios (Fase 1), Catálogo de beneficios
     y Backoffice ampliado (Fase 2).
   - Componente transversal: Registro Inteligente con IA (Fase 2), usado desde varios módulos.

2. **Capa de Integración (APIs SaaS / servicios externos):**
   - Mapbox API (mapas y rutas).
   - Firebase Authentication (gestión de usuarios).
   - Google Gemini API (auditoría de boletas + registro inteligente).
   - Flujo del Registro Inteligente con IA: Capturar foto → Identificar tipo de documento →
     Extraer datos → Validar (usuario) → Guardar en módulo correcto.

3. **Capa de Datos (Firebase/Firestore):**
   - Colecciones heredadas de Fase 1: usuarios, vehiculos (extendida en Fase 2), viajes_tag,
     porticos, tarifas_tag, auditoria.
   - Colecciones nuevas de Fase 2: documentos_vehiculares, mantenciones, estacionamientos,
     abastecimientos, beneficios, notificaciones.
   - Firebase Storage: fotos/imágenes originales de documentos y boletas.

## Actores del sistema (diagrama de casos de uso, nivel cero)

- **Usuario** (genérico) → se especializa en:
  - **Administrador:** gestiona Beneficios desde el backoffice web.
  - **Conductor:** usa la app móvil — consulta resumen vehicular, gestiona su vehículo,
    mantenciones, estacionamientos, combustible/carga, registra datos con IA, gestiona
    notificaciones.
- **Gemini API** (actor externo): participa activamente en los procesos que dependen de
  IA — identificación y extracción de datos desde documentos, boletas y tickets.

## Decisión de arquitectura clave para Sprint 2

El componente de Registro Inteligente con IA se construye **una sola vez** durante este
Sprint (dentro del desarrollo de Mi Vehículo) y se diseña para ser **reutilizado** por los
módulos siguientes (Mantenciones, Estacionamientos, Combustible), en vez de reimplementar
la integración con Gemini en cada módulo. Esto reduce el riesgo técnico y concentra el
esfuerzo de pruebas de precisión de la IA en un único componente (RNF-007: esquema
desacoplado por tipo de documento).

## Nota sobre incidente resuelto

Durante Sprint 1 se detectó y corrigió que `main.dart` (en `tag_ok` y `admin`) cargaba
credenciales hardcodeadas en Base64 de un proyecto con `GEMINI_API_KEY` inválida, en vez
de leer el `.env` real del proyecto `tag-ok-v2`. Ya está corregido (commit `840afe0`):
ambas apps cargan credenciales exclusivamente vía `dotenv.load(fileName: ".env")`.
