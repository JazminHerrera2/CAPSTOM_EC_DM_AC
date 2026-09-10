# Evidencia para diseñar Mi Vehículo, Mantenciones y Registro Inteligente

**Fecha:** 10 de septiembre de 2026.  
**Base:** código local de TAG OK y revisión del emulador.  
**Propósito:** identificar qué se puede reutilizar, qué falta y qué decisiones deben confirmarse con el equipo. No se implementan funcionalidades nuevas en este documento.

## 1. Respuestas para el diseño

| Pregunta | Respuesta comprobada |
|---|---|
| ¿Existe un extractor de documentos con Gemini? | Sí, pero está especializado en facturas de peajes TAG. |
| ¿Boleta equivale al Registro Inteligente de mantenciones/combustible? | No. El flujo actual genera un resumen de cruces y lo compara contra una factura adjunta. |
| ¿Puede reutilizarse parte del flujo? | Sí: selección de archivo, cámara, multipart, comunicación con Gemini, errores y presentación de resultados. El prompt, el esquema y la operación posterior deben adaptarse. |
| ¿Existe Vehículos? | Sí: lista de vehículos, alta mediante formulario y eliminación con confirmación. Es una base concreta para Mi Vehículo. |
| ¿Hay marca, modelo o documentos? | No aparecen en el esquema de referencia ni en los DTO de vehículo revisados. |
| ¿Existe un catálogo de categorías en Supabase? | No se encontró en los archivos SQL revisados. Hay tipos definidos en código y una asociación tarifaria en PostgreSQL de rutas. |
| ¿Quién administra Beneficios? | No está definido en la matriz de permisos ni se encontró un módulo implementado de Beneficios en los componentes revisados. |
| ¿Hay acceso al esquema remoto completo? | No se realizó una consulta administrativa a Supabase. El SQL del repositorio es evidencia de referencia, no una certificación del esquema remoto actual. |

## 2. Flujo de Boleta: contratos y comportamiento real

### 2.1 Generar una boleta desde el historial

**Endpoint público:** `POST /api/history/v1/boleta/obtener`.  
**Tipo:** `application/json`, con sesión del usuario mediante Bearer.  
**Código:** [BoletaController](Producto/history-service/src/main/java/com/tagok/history_service/controller/BoletaController.java), [BoletaRequest](Producto/history-service/src/main/java/com/tagok/history_service/controller/dto/BoletaRequest.java) y [BoletaService](Producto/history-service/src/main/java/com/tagok/history_service/service/BoletaService.java).

Ejemplo ilustrativo de petición, sin datos reales:

```json
{
  "patente": "ABCD12",
  "fechaDesde": "2026-09-01",
  "fechaHasta": "2026-09-10",
  "autopistas": []
}
```

El servicio consulta MongoDB por usuario, patente, período y autopistas. Devuelve un `BoletaDTO` con:

| Campo | Tipo Java | Significado |
|---|---|---|
| `patente` | String | Vehículo solicitado |
| `fechaDesde`, `fechaHasta` | LocalDate | Período consultado |
| `items` | Lista de BoletaItemDTO | Cruces registrados por la aplicación |
| `total` | BigDecimal | Suma consultada del historial |

Cada elemento de `items` tiene `fecha`, `autopista`, `nombre`, `tipoTarifa`, `valor` y `horaCruce`. Este último es un String construido desde la fecha/hora del cruce: no debe suponerse que contiene exclusivamente `HH:mm:ss`.

**Esta operación no utiliza Gemini.** Devuelve un resumen estructurado del historial; el endpoint revisado no emite un documento tributario ni devuelve por sí mismo un archivo PDF.

### 2.2 Comparar el historial contra una factura externa

**Endpoint público:** `POST /api/history/v1/boleta/comparar`.  
**Tipo:** `multipart/form-data`, con sesión Bearer.  
**Código:** [ComparacionFacturaController](Producto/history-service/src/main/java/com/tagok/history_service/controller/ComparacionFacturaController.java) y [ComparacionFacturaService](Producto/history-service/src/main/java/com/tagok/history_service/service/ComparacionFacturaService.java).

| Parte multipart | Obligatoria según el controlador | Contenido |
|---|---|---|
| `archivo` | Sí | PDF o imagen de la factura |
| `patente` | Sí | Vehículo que se consulta en el historial |
| `fechaDesde` | Sí | Fecha ISO `YYYY-MM-DD` |
| `fechaHasta` | Sí | Fecha ISO `YYYY-MM-DD` |
| `autopistas` | No | Lista; Android repite este campo por cada autopista seleccionada |

El servicio admite los MIME `application/pdf`, `image/jpeg`, `image/png`, `image/webp`, `image/heic` e `image/heif`. Esto describe la validación local; no garantiza la aceptación de todo archivo por el proveedor externo. El límite configurado del archivo es 10 MB.

La ejecución tiene tres pasos:

1. Lee el archivo e inicia la extracción con Gemini.
2. Consulta la boleta del historial del usuario en paralelo.
3. Ejecuta un comparador Java determinista y devuelve las diferencias.

No se encontró en este servicio una operación que guarde el archivo original en Storage, cree una mantención, registre combustible o persista la extracción como un registro independiente. La función actual devuelve el resultado de la comparación.

### 2.3 Qué extrae exactamente Gemini

**Adaptador completo:** [GeminiExtractorFactura.java](Producto/history-service/src/main/java/com/tagok/history_service/ia/gemini/GeminiExtractorFactura.java).  
**Interfaz:** [ExtractorFacturaIA.java](Producto/history-service/src/main/java/com/tagok/history_service/ia/ExtractorFacturaIA.java).  
**Modelo de salida:** [FacturaExtraidaDTO](Producto/history-service/src/main/java/com/tagok/history_service/dto/FacturaExtraidaDTO.java) y [FacturaItemDTO](Producto/history-service/src/main/java/com/tagok/history_service/dto/FacturaItemDTO.java).

| Nivel | Campo | Tratamiento actual |
|---|---|---|
| Documento | `patente` | Texto, puede ser null |
| Documento | `total` | Monto del documento, puede ser null |
| Documento | `items` | Lista de cruces; obligatoria en el esquema solicitado a Gemini |
| Cruce | `fecha` | Texto esperado como `YYYY-MM-DD`; no está incluido en la lista `required` del esquema |
| Cruce | `hora` | Texto esperado como `HH:mm:ss` si aparece; admite null |
| Cruce | `portico` | Nombre del pórtico o punto de cobro; obligatorio en el esquema |
| Cruce | `autopista` | Autopista o concesionaria; admite null |
| Cruce | `valor` | Monto cobrado en pesos; obligatorio en el esquema |

Ejemplo ilustrativo de la estructura que se espera de Gemini:

```json
{
  "patente": "ABCD12",
  "total": 1300,
  "items": [
    {
      "fecha": "2026-09-03",
      "hora": "08:15:00",
      "portico": "Pórtico de ejemplo",
      "autopista": "Autopista de ejemplo",
      "valor": 1300
    }
  ]
}
```

No se extraen campos genéricos de comercio, RUT del emisor, folio, fecha global de emisión, descripción de una reparación, kilometraje, litros, tipo de combustible o precio por litro. `autopista` identifica una concesionaria en el contexto TAG, no un comercio genérico.

El prompt comienza con: «Extrae los datos de esta boleta o factura de peajes TAG de autopistas chilenas». Además instruye a interpretar puntos como separadores de miles en CLP y a omitir cargos administrativos, intereses y descuentos. **El prompt es específico de peajes.**

### 2.4 Petición interna al proveedor

El adaptador realiza `POST /v1beta/models/{model}:generateContent` sobre el host configurado para Gemini y usa la cabecera `x-goog-api-key` en el backend. El cuerpo contiene:

- `contents[].parts[].inline_data`: MIME y bytes del archivo codificados en Base64.
- `contents[].parts[].text`: prompt de extracción TAG.
- `generationConfig.temperature`: `0`.
- `generationConfig.response_mime_type`: `application/json`.
- `generationConfig.response_schema`: objeto con los campos descritos arriba.

Lee `candidates[0].content.parts[0].text` y convierte ese JSON a `FacturaExtraidaDTO`. El esquema obligatorio exige `items`, y `portico`/`valor` en cada elemento; no exige todos los campos mencionados en el prompt.

El timeout de lectura del adaptador es configurable, con 60 segundos por defecto. El cliente Android de comparación lo amplía a 120 segundos en [BoletaApi.kt](Producto/tag-ok-app/app/src/main/java/com/tagok/app/data/remote/BoletaApi.kt), diferente del timeout general de la app.

### 2.5 Resultado y reglas de comparación

La respuesta de `boleta/comparar` es un [ComparacionFacturaDTO](Producto/history-service/src/main/java/com/tagok/history_service/dto/ComparacionFacturaDTO.java):

| Campo | Contenido |
|---|---|
| `boletaApp` | Resumen consultado a MongoDB |
| `facturaCliente` | Extracción estructurada devuelta por Gemini |
| `items` | Parejas o elementos sin pareja, con estado y diferencia |
| `totalApp`, `totalFactura` | Totales comparados |
| `diferenciaTotal` | `totalFactura - totalApp` |
| `coincidencias`, `discrepancias` | Conteos de estados |
| `cuadra` | True cuando no existen discrepancias y la diferencia total es cero |

Los estados posibles son `COINCIDE`, `MONTO_DIFERENTE`, `SOLO_EN_APP` y `SOLO_EN_FACTURA`. Cada resultado incluye `itemApp`, `itemFactura` y `diferenciaValor`; uno de los elementos puede ser null.

[ComparadorFacturas.java](Producto/history-service/src/main/java/com/tagok/history_service/service/ComparadorFacturas.java) empareja en tres pasadas: fecha/valor/nombre similar, luego fecha/nombre similar y finalmente fecha/valor. La similitud normaliza nombres y compara palabras. Si no puede interpretar la fecha extraída, no la utiliza para excluir una coincidencia.

El emparejamiento revisado no exige igualdad de hora ni de autopista y no rechaza explícitamente una patente extraída distinta de la solicitada. Si Gemini devuelve `total`, lo usa; si no, suma los elementos extraídos. Como el prompt excluye cargos no relacionados con cruces, un total documental que los incluya puede producir una diferencia aun cuando los peajes coincidan.

Estas características deben considerarse al interpretar el resultado: una discrepancia requiere revisión y no prueba por sí sola un cobro erróneo de la concesionaria.

### 2.6 Reutilización para Registro Inteligente

| Pieza existente | Uso posible en el nuevo módulo |
|---|---|
| Selector PDF, galería y cámara | Reutilizar componentes de entrada de archivos |
| Multipart y modelo local de archivo | Reutilizar la mecánica de envío |
| Adaptador HTTP de Gemini | Extraer o compartir el transporte y manejo de errores |
| Prompt y `FacturaExtraidaDTO` | Mantener para TAG; crear otro contrato para mantención/combustible |
| Comparador de cruces | Conservar en Boleta; no tiene el propósito de precargar mantenciones |
| Pantalla de comparación | Reutilizar patrones visuales, pero diseñar revisión/edición de campos para Registro Inteligente |

**Propuesta, no implementación:** el nuevo flujo sería adjuntar documento → extraer campos específicos → presentar un borrador editable → confirmar el vehículo y los datos → guardar la mantención o carga de combustible. El guardado debe ser una operación separada de la extracción para que el usuario pueda corregirla.

No conviene modificar el prompt TAG para atender todos los documentos sin distinguir el caso de uso: se perdería la compatibilidad del contrato actual. Tampoco es necesario duplicar las credenciales ni toda la infraestructura de integración con Gemini.

## 3. Vehículos: esquema y categorías existentes

### 3.1 Esquema exacto disponible en el repositorio

El archivo completo, que también contiene `presupuesto` y `notificacion`, está en [supabase-schema.sql](Producto/supabase/supabase-schema.sql). Su declaración de `vehiculos` es:

```sql
CREATE TABLE public.vehiculos (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  patente text NOT NULL,
  tipo_vehiculo text NOT NULL,
  numero_tag text,
  alias text,
  es_principal boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT vehiculos_pkey PRIMARY KEY (id),
  CONSTRAINT vehiculos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
```

El archivo advierte que su contenido es de referencia y no necesariamente ejecutable en ese orden. En esa declaración no hay campos de marca, modelo, año de fabricación, kilometraje, documentación, vencimientos ni categoría numérica; tampoco se declara una restricción UNIQUE para la patente.

Los [DTO Android de vehículos](Producto/tag-ok-app/app/src/main/java/com/tagok/app/data/dto/vehiculo/VehiculoDts.kt) reflejan estos campos. El alta visible permite tipo, patente, número TAG opcional y alias opcional. La pantalla revisada ofrece agregar y eliminar, pero no un formulario de edición de un vehículo existente.

El campo `es_principal` existe en el esquema y DTO, pero no debe darse por completada su experiencia de uso: la consulta actual de `VehiculoApi.getVehiculos()` selecciona columnas sin incluir `es_principal`, por lo que el DTO utiliza su valor por defecto cuando no viene en la respuesta. Revisar esto antes de utilizarlo como fuente de verdad del «vehículo principal».

### 3.2 Tipos de vehículo y categorías de tarifa

Los valores compartidos por el enum Java, el enum Android y el selector del formulario son:

| Valor | Etiqueta del formulario |
|---|---|
| `AUTO` | Automóvil |
| `MOTO` | Motocicleta |
| `CAMIONETA` | Camioneta |
| `BUS` | Bus |
| `CAMION` | Camión |
| `CAMION_REMOLQUE` | Camión con remolque |

Fuentes: [TipoVehiculo.java](Producto/routes-service/src/main/java/com/tagok/routes_service/domain/vehiculo/TipoVehiculo.java), [TipoVehiculo.kt](Producto/tag-ok-app/app/src/main/java/com/tagok/app/domain/vehiculo/TipoVehiculo.kt) y [VehiculosScreen.kt](Producto/tag-ok-app/app/src/main/java/com/tagok/app/ui/vehiculos/VehiculosScreen.kt).

`regla_tarifaria_vehiculos` pertenece al PostgreSQL del servicio de rutas. [ReglaTarifaria.java](Producto/routes-service/src/main/java/com/tagok/routes_service/domain/tarifa/ReglaTarifaria.java) la mapea como una colección con `regla_id` y `tipo_vehiculo`: expresa a qué tipos se aplica una regla de cobro. **No representa vehículos personales ni un catálogo de marcas/modelos.**

Existe además un campo TypeScript `categoria: number` en el tipo de usuario/vehículo de la web y una función `categoriaLabel` con categorías numéricas. Eso no demuestra que exista una columna o tabla correspondiente: no aparece en el esquema Supabase de referencia ni en el DTO Android. Su origen y uso real deben confirmarse antes de diseñar una dependencia sobre ese campo.

### 3.3 Confirmar el esquema remoto antes de migrar

El equipo puede ejecutar estas consultas de lectura en el SQL Editor de Supabase para obtener la definición realmente desplegada:

```sql
SELECT table_name, column_name, data_type, udt_name,
       is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('vehiculos', 'presupuesto', 'notificacion')
ORDER BY table_name, ordinal_position;

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

SELECT conname, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE conrelid = 'public.vehiculos'::regclass;
```

La segunda consulta permite comprobar si existe algún catálogo o módulo añadido directamente en el proyecto remoto y ausente del repositorio.

### 3.4 Base de diseño sin duplicación

Mi Vehículo puede evolucionar sobre `public.vehiculos` y la ruta móvil `vehiculos`, preservando `id` y `user_id`. Marca, modelo, kilometraje y documentos son ampliaciones a diseñar, no campos existentes que solo falte mostrar.

Las mantenciones y cargas de combustible pueden referenciar `vehiculos.id` mediante nuevas entidades. La definición de columnas, adjuntos, vencimientos y eliminación debe acordarse según los requisitos. No utilizar `regla_tarifaria_vehiculos` para almacenar estos registros.

El presupuesto actual se presenta como control de gastos **en peajes**. Ampliarlo a gastos generales del vehículo implica definir si se mezclan o separan combustible, mantenciones y TAG; no asumir que el total existente ya los incluye.

## 4. Beneficios: decisión de permisos pendiente

[roles.ts](Producto/routes-ui/src/app/auth/roles.ts) solo reconoce las secciones `usuarios`, `concesionarios`, `porticos`, `tarifas`, `reportes`, `auditoria` y `carga-masiva`. No hay una sección `beneficios`.

La búsqueda en los clientes, SQL y servicios revisados no encontró un módulo implementado de Beneficios. Por tanto, **no existe evidencia para asignarlo automáticamente a `admin_operacional` o `super_admin` como una regla ya aprobada**. Que un rol gestione tarifas no define quién puede publicar promociones.

En la Sprint Review se debe resolver la matriz por acción:

| Acción sobre un beneficio | Decisión por confirmar |
|---|---|
| Crear y editar borradores | Rol responsable y alcance por concesionaria/proveedor |
| Publicar, activar o desactivar | Si requiere aprobación y quién la otorga |
| Eliminar o archivar | Permisos y conservación del historial |
| Consultar/canjear desde Android | Usuarios elegibles y reglas de vigencia |
| Consultar resultados o auditoría | Rol que accede a reportes del módulo |

Si el equipo necesita una propuesta inicial, una opción es que `admin_operacional` gestione contenido operativo y `super_admin` supervise/publice. **Es una propuesta de producto para discutir, no un comportamiento del software actual.** También puede aprobarse gestión directa por uno de los roles; el código no decide entre esas alternativas.

El RF debería nombrar acciones y roles explícitamente. «El administrador gestiona Beneficios» deja sin resolver precisamente la diferencia entre los dos perfiles.

## 5. Pantallas reales y patrones de interfaz

### 5.1 Navegación y archivos

| Pantalla | Cómo llegar | Código fuente |
|---|---|---|
| Vehículos | `Perfil → Vehículos`; Home también tiene acceso de alta | [VehiculosScreen](Producto/tag-ok-app/app/src/main/java/com/tagok/app/ui/vehiculos/VehiculosScreen.kt) |
| Nuevo vehículo | Botón flotante `+` en Vehículos | `AgregarVehiculoSheet`, dentro del mismo archivo |
| Presupuesto | Pestaña inferior `Presupuesto` | [PresupuestoScreen](Producto/tag-ok-app/app/src/main/java/com/tagok/app/ui/presupuesto/PresupuestoScreen.kt) |
| Boleta | Pestaña inferior `Boleta` | [BoletaScreen](Producto/tag-ok-app/app/src/main/java/com/tagok/app/ui/boleta/BoletaScreen.kt) |
| Verificar factura | Generar boleta y pulsar `Verificar factura con IA` | [ComparacionScreen](Producto/tag-ok-app/app/src/main/java/com/tagok/app/ui/boleta/comparacion/ComparacionScreen.kt) |

La navegación inferior actual contiene `Home`, `Presupuesto`, `Boleta` y `Perfil`; Vehículos es una ruta interna. Fuente: [NavGraph.kt](Producto/tag-ok-app/app/src/main/java/com/tagok/app/ui/navigation/NavGraph.kt).

### 5.2 Contenido que conviene conservar al diseñar

- **Vehículos:** tarjetas con tipo, patente y alias/datos disponibles; acción de eliminar; botón flotante de alta; formulario en hoja modal inferior. El botón de guardar exige una patente no vacía y convierte su texto a mayúsculas; esto no equivale a una validación completa de formato.
- **Presupuesto:** selector de vehículo o ámbito global, gasto y monto máximo del mes, creación/edición mediante hoja inferior y umbrales de alerta.
- **Boleta:** selección de vehículo, rango de fechas, filtro opcional de autopistas, generación del resumen y acceso posterior a verificación.
- **Verificar factura:** cámara, PDF o galería; selección del documento, ejecución y resultados de comparación. No existe aquí un formulario editable de mantención/combustible precargado por IA.

Los componentes utilizan tarjetas blancas, fondos claros, esquinas redondeadas y acciones azules. [BrandColors.kt](Producto/tag-ok-app/app/src/main/java/com/tagok/app/ui/theme/BrandColors.kt) define `NavyBlue #172955`, `AccentBlue #1C42B1`, `PageBg #F4F6FB`, `LightBlueBg #EEF2FF` y `TextDark #111827`. Estos son recursos concretos para mantener continuidad visual; conviene reutilizar el tema y componentes existentes antes de copiar estilos.

### 5.3 Capturas

Se abrió el emulador y se comprobó que la sesión permite navegar a Vehículos. La conservación de capturas con la patente visible dentro del repositorio está pendiente de autorización explícita. No se presentan recreaciones o mockups como evidencia de las pantallas existentes.

## 6. Qué pedir a Rodrigo/Oliver y qué ya está disponible

| Elemento | Situación |
|---|---|
| Adaptador Gemini, prompt y DTO | Disponible en el repositorio y enlazado en este complemento |
| Contratos de Boleta y comparación | Disponibles; descritos en la sección 2 |
| Esquema SQL de referencia | Disponible; tabla Vehículos transcrita y archivo completo enlazado |
| Campos/políticas reales del Supabase remoto | Confirmar mediante exportación o consultas administrativas |
| Catálogo real detrás de `categoria` numérica | Confirmar si existe fuera del código/SQL revisado |
| Permisos del módulo Beneficios | Decisión funcional pendiente del equipo |
| Pantallas implementadas | Código disponible; emulador accesible, capturas sujetas a conservación autorizada |
| Alcance del Registro Inteligente | Definir tipos de documento, campos, revisión humana, adjuntos y operación de guardado |
| Alcance de Mantenciones/Mi Vehículo | Definir nuevos campos, eventos, vencimientos y relación con los presupuestos de peajes |

No es necesario esperar a la Sprint Review para obtener el extractor, el esquema de referencia o las pantallas en código. La reunión aporta principalmente las decisiones de producto y la confirmación de cualquier cambio remoto o trabajo no incorporado a esta copia del repositorio.
