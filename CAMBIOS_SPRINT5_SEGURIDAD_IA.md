# Cambios Sprint 5: la clave de OpenAI sale de la app y el `.env` deja de publicarse

**Rama:** `Estephany` · **Fecha:** 7 y 8-nov-2026 · **Estado:** probado y web publicada (8-nov); **sin commit**; quedan pasos pendientes (sección 6)

Este documento resume dos cambios de seguridad relacionados:

1. **La IA pasa por una Edge Function** (`ia-extraccion`): la app ya no tiene la clave de OpenAI.
2. **El `.env` deja de publicarse**: la configuración se lee al compilar (`--dart-define-from-file=.env`).

Los números de línea son los de la **versión actual** de cada archivo (después del cambio). Cuando se indica "antes", es la línea en el último commit (`b8f301a`).

---

## 1. El problema

### 1.1 La clave de OpenAI estaba publicada en internet
- `pubspec.yaml` declaraba el `.env` como **asset** de la app. Flutter lo copiaba tal cual a `build/web/assets/.env` y `firebase deploy` lo subía a Firebase Hosting.
- Cualquier persona podía abrir **`https://tag-ok-v2.web.app/assets/.env`** (sin iniciar sesión) y ver todas las variables. Se verificó el 7-nov: el archivo traía, entre otras, `OPENAI_API_KEY`, `GEMINI_API_KEY` y `SUPABASE_ANON_KEY`.
- Lo mismo pasaba con el APK de Android: el `.env` iba dentro del instalador.
- Además, la app llamaba a OpenAI **desde el navegador** con la clave en la cabecera `Authorization`. Aunque el archivo se ocultara, la clave se veía en cada petición (F12 → pestaña *Red*).

**Riesgo:** cualquiera podía usar OpenAI con cargo a la cuenta del proyecto.

### 1.2 Por qué no basta con borrar o esconder el archivo
- **Una app no puede guardar secretos.** Todo lo que la app usa en el navegador del usuario, el usuario lo puede ver. La única forma segura es que la clave viva en un **servidor**.
- **Flutter publica el `.env` completo**, no solo las variables que usa el código. Una clave que quede olvidada en el archivo se publica igual.

> El `.env` **nunca estuvo en GitHub** (está en `.gitignore`). El problema era la publicación de la web y del APK, no el repositorio.

---

## 2. Cambio 1: la IA pasa por la Edge Function `ia-extraccion`

```
Antes:   App ──(clave de OpenAI)──────────────────────────────────▶ OpenAI
Ahora:   App ──(token de sesión de Firebase)──▶ Edge Function ──(clave secreta)──▶ OpenAI
```

Es el mismo patrón que ya usaba la función de archivos `secure-document-upload`. La clave de OpenAI queda guardada como **secreto de Supabase** y solo la función puede leerla.

Los seis flujos con IA (documentos, padrón, velocímetro, mantenciones, combustible y auditoría de boletas) pasan por un único servicio (`OpenAiExtractionService`), así que **solo cambió la dirección a la que llama ese servicio**. Prompts, esquemas, cascada de modelos y reintentos siguen igual: la función devuelve la respuesta de OpenAI tal cual (mismo status y cuerpo).

### 2.1 Archivos nuevos: `Producto/tag_ok/supabase/functions/ia-extraccion/`

**`index.ts`** (141 líneas): la función.

| Líneas | Qué hace |
|---|---|
| 1–27 | Comentario: qué hace la función, variables de entorno y cómo desplegarla |
| 32 | Dirección de OpenAI (`api.openai.com/v1/chat/completions`), que ahora solo usa el servidor |
| 34–39, 57–75 | `verificarUid`: valida el ID Token de Firebase con las claves públicas de Google (copia de la de `secure-document-upload`) |
| 41 | Tiempo máximo de espera a OpenAI: 115 s (menos que los 120 s de la app) |
| 43–55 | Cabeceras CORS, para que la web pueda llamar a la función |
| 77–128 | `manejar`: exige POST y sesión válida, lee `OPENAI_API_KEY` del servidor, limita el tamaño, valida la petición, llama a OpenAI y devuelve su respuesta. Registra solo **uid, modelo, status y tiempo**, nunca el contenido del documento |
| 130–141 | Punto de entrada; los errores se devuelven con el mismo formato que OpenAI (`{error: {code, message}}`) |

**`validate.ts`** (125 líneas): validaciones sin red, probadas con `deno test`.

| Líneas | Qué hace |
|---|---|
| 5 | Tamaño máximo de la petición: 20 MB |
| 12–16 | `MODELOS_PERMITIDOS`: solo los 3 modelos de la app (`gpt-6-luna`, `gpt-5.6-luna`, `gpt-5.4-nano`). Así una sesión robada no puede usar un modelo más caro |
| 18–19 | Máximo 10 partes por mensaje y 80.000 caracteres por texto |
| 25–29 | `HttpError` con código, en el formato de OpenAI |
| 31–35 | `extraerBearer`: exige `Authorization: Bearer <token>` (401 `sin_sesion` si falta) |
| 39–75 | `validarParte`: acepta texto, imagen **embebida** (`data:image/...`) o PDF **embebido**. Rechaza imágenes por enlace externo |
| 77–94 | `validarFormato`: solo respuesta JSON (`json_object` o `json_schema`) |
| 100–125 | `validarSolicitud`: **rearma** la petición solo con `model`, `messages` y `response_format`. Descarta cualquier otro campo (por ejemplo `max_tokens` o `n`), para que el cliente no decida parámetros de costo |

**`validate_test.ts`** (115 líneas): 9 tests de Deno (petición válida, PDF y esquema, campos extra descartados, modelo no permitido, imagen por URL, archivo que no es PDF, rol distinto de `user`, `response_format` desconocido y falta de token).

### 2.2 `Producto/tag_ok/supabase/config.toml`
| Líneas | Cambio |
|---|---|
| 8–11 | Registra `[functions.ia-extraccion]` con `verify_jwt = false`. El token es de Firebase, no de Supabase, así que lo verifica la función misma (igual que `secure-document-upload`) |

### 2.3 `Producto/tag_ok/lib/features/registro_inteligente/openai_extraction_service.dart`
| Líneas | Antes | Ahora |
|---|---|---|
| 3 | — | Importa `firebase_auth`, para obtener el ID Token del usuario |
| 7 | Importaba `flutter_dotenv` | Importa `entorno.dart` (cambio 2) |
| 30–38 | — | `esErrorNoDisponible503`: un 500 con código `configuracion_servidor` (falta un secreto en la función) **no** se reintenta |
| 46–55 | — | `esErrorFatalOpenAi`: `configuracion_servidor` corta la cascada de inmediato |
| 57–63 | — | Función nueva `endpointIaExtraccion`: arma `https://<SUPABASE_URL>/functions/v1/ia-extraccion` |
| 147–156 | Decía que llamaba a la API de OpenAI | Documenta que la app no tiene la clave y llama a la Edge Function |
| 171–175 | Constante `_endpoint` con la URL de OpenAI | Eliminada. El comentario indica que la lista de modelos debe coincidir con `MODELOS_PERMITIDOS` de `validate.ts` |
| 192–210 | Constructor solo con `cliente` | Agrega `endpoint` y `obtenerToken` (solo para tests) y `_idTokenActual()`, que pide el ID Token a Firebase |
| 219–227 | Leía `OPENAI_API_KEY` del `.env` y fallaba con "Clave de API de OpenAI no configurada." | Arma la dirección de la función desde `SUPABASE_URL` y obtiene el ID Token. Mensajes: "Servicio de IA no configurado (falta SUPABASE_URL)." y "Debes iniciar sesión para usar la IA." |
| 237–244 | `_llamar(apiKey, ...)` | `_llamar(endpoint, token, ...)` |
| 279–292 | POST a `api.openai.com` con `Bearer <clave de OpenAI>` | POST a la Edge Function con `Bearer <ID Token de Firebase>` |

### 2.4 Test nuevo: `Producto/tag_ok/test/ia_extraccion_edge_function_test.dart`
141 líneas, 6 tests con un servidor simulado (`MockClient`):

| Líneas | Test |
|---|---|
| 24–36 | `endpointIaExtraccion` arma la URL y la rechaza si no es `https` |
| 39–63 | La app llama a la función con el ID Token y **nunca** a `api.openai.com` |
| 65–85 | Sin sesión no se hace ninguna llamada |
| 87–111 | Si falta el secreto en el servidor, se corta sin reintentar (1 sola llamada) |
| 113–139 | Si un modelo es rechazado, se pasa al siguiente de la cascada |

---

## 3. Cambio 2: el `.env` deja de publicarse

```
Antes:   flutter build web                              → copia el .env completo a assets/.env (público)
Ahora:   flutter build web --dart-define-from-file=.env → el archivo no se publica;
                                                          solo llegan a la app las variables que el código lee
```

Las variables que la app usa (configuración de Firebase, token de Mapbox, URL de Supabase) **siguen quedando dentro de la app compilada**: son datos públicos por diseño. Lo que cambia es que el archivo ya no existe en el sitio y que una variable olvidada en el `.env` **no llega** a la app.

### 3.1 Archivo nuevo: `Producto/tag_ok/lib/entorno.dart` (34 líneas)
| Líneas | Qué hace |
|---|---|
| 1–15 | Explica de dónde salen los valores, qué se puede poner y por qué deben ser `const` |
| 16–34 | Clase `Entorno` con las 12 variables que usa la app, leídas con `String.fromEnvironment` |

### 3.2 Archivos que dejaron de leer el `.env`
| Archivo | Líneas | Cambio |
|---|---|---|
| `lib/main.dart` | 4 (antes 5) | Se quita el import de `flutter_dotenv` |
| `lib/main.dart` | 17–19 (antes 18–25) | Se elimina `dotenv.load(fileName: ".env")`; el comentario explica que la configuración llega al compilar |
| `lib/main.dart` | 25–28 | Comentario del error de inicio: menciona compilar sin `--dart-define-from-file=.env` |
| `lib/firebase_options.dart` | 3–7 | Se quita `flutter_dotenv`; importa `entorno.dart` |
| `lib/firebase_options.dart` | 51–67 | `_requireEnv(key)` pasa a ser `_requerido(valor, nombre)`. Si falta un valor, el mensaje dice que hay que compilar con `--dart-define-from-file=.env` |
| `lib/firebase_options.dart` | 69–81 | Configuración web con `Entorno.*` |
| `lib/firebase_options.dart` | 83–98 | Configuración Android e iOS con `Entorno.*` (ahora `const`) |
| `lib/data/services/geocoding_service.dart` | 2–5, 23 | Token de Mapbox desde `Entorno.mapboxAccessToken` |
| `lib/data/services/simulated_toll_service.dart` | 3–7 | Se quita `flutter_dotenv`; importa `entorno.dart` |
| `lib/data/services/simulated_toll_service.dart` | 13–18 | Constructor nuevo con `mapboxToken` opcional (por defecto el de `Entorno`), para poder pasárselo en los tests |
| `lib/data/services/simulated_toll_service.dart` | 23–26 | Usa ese token; el mensaje de error indica la variable `MAPBOX_ACCESS_TOKEN` |
| `lib/data/services/storage_service.dart` | 4–9 | Se quita `flutter_dotenv`; importa `entorno.dart` |
| `lib/data/services/storage_service.dart` | 33, 121 | `SUPABASE_URL` desde `Entorno.supabaseUrl` |
| `lib/screens/live_map_screen.dart` | 10 (antes 11), 19 | Se quita `flutter_dotenv`; importa `entorno.dart` |
| `lib/screens/live_map_screen.dart` | 839 | Token del mapa desde `Entorno.mapboxAccessToken` |
| `lib/features/registro_inteligente/openai_extraction_service.dart` | 7, 220 | `SUPABASE_URL` desde `Entorno.supabaseUrl` |

### 3.3 Dependencias y assets: `Producto/tag_ok/pubspec.yaml`
| Líneas | Cambio |
|---|---|
| 44 (antes 45) | Se elimina la dependencia `flutter_dotenv: ^5.1.0` |
| 98–101 (antes 99–100) | Se quita `- .env` de los assets; un comentario explica por qué |

`pubspec.lock` cambia porque se quitó `flutter_dotenv`, y además Flutter actualizó algunos paquetes fijados por el SDK (`intl`, `meta`, `test_api`, etc.). **Sí debe ir en el commit.**

### 3.4 Archivo eliminado: `lib/data/services/tollguru_service.dart` (64 líneas)
Era código muerto: ninguna parte de la app lo usaba (verificado con búsqueda), y era el único otro archivo que dependía de `flutter_dotenv` (`TOLLGURU_API_KEY` y `WEB_CORS_PROXY`).

### 3.5 Test adaptado: `Producto/tag_ok/test/toll_calc_test.dart`
| Líneas | Cambio |
|---|---|
| 4 (antes 5) | Se quita el import de `flutter_dotenv` |
| 7–13 | Variable `mapboxToken` y función `servicioDePrueba()` |
| 22–26 | En vez de `dotenv.testLoad(...)`, se extrae `MAPBOX_ACCESS_TOKEN` de las variables de prueba |
| 46, 68, 90 | Los 3 tests de rutas usan `servicioDePrueba()` |

### 3.6 Forma de ejecutar y compilar
| Archivo | Líneas | Cambio |
|---|---|---|
| `Producto/tag_ok/.vscode/launch.json` | 9 | Agrega `--dart-define-from-file=.env` al ejecutar desde VS Code |
| `Producto/setup.bat` | 52–54 | Corrige la nota final, que decía que no se necesitaban archivos `.env` |
| `Producto/setup.bat` | 71, 78 | Las opciones 1 y 2 (`tag_ok`) agregan `--dart-define-from-file=.env` |

---

## 4. Documentación

| Archivo | Líneas | Cambio |
|---|---|---|
| `Producto/tag_ok/env_ejemplo.txt` | 1–6 | Aviso: el `.env` se lee al compilar, solo lleva datos públicos y nunca claves secretas |
| `Producto/tag_ok/env_ejemplo.txt` | 18–21 (antes 12–13) | Se elimina `OPENAI_API_KEY`; se explica que la IA va por la Edge Function |
| `GUIA_LEVANTAR_PROYECTO_LOCAL.md` | 85 (antes 85–86) | Se reemplazan `GEMINI_API_KEY` y `OPENAI_API_KEY` por `SUPABASE_URL` en el ejemplo de `.env` |
| `GUIA_LEVANTAR_PROYECTO_LOCAL.md` | 88–107 | Aviso sobre `--dart-define-from-file=.env`, prohibición de claves secretas y comandos para desplegar la Edge Function |
| `GUIA_LEVANTAR_PROYECTO_LOCAL.md` | 117 | La nota final menciona Supabase en vez de Gemini |
| `GUIA_LEVANTAR_PROYECTO_LOCAL.md` | 146–165 (antes 128–161) | Sección 6 reordenada: había comandos mezclados fuera de bloque. Todos los comandos de `tag_ok` llevan `--dart-define-from-file=.env`; se agregan Edge y `web-server` como alternativas a Chrome |
| `GUIA_LEVANTAR_PROYECTO_LOCAL.md` | 177–184 | Ejecución en Windows con el parámetro nuevo y comando para generar el APK |

> El **panel admin** no se modificó: su `firebase.json` excluye los archivos que empiezan con punto (`**/.*`) y se comprobó que `https://tag-ok-v2-admin.web.app/assets/.env` no entrega el archivo.

---

## 5. Pruebas realizadas

| Prueba | Resultado |
|---|---|
| `flutter test` (suite completa) | ✅ 326 tests pasan. El catálogo de pórticos sigue con 104 |
| `flutter analyze` | ✅ Sin errores. Los avisos que quedan son los mismos de antes del cambio |
| `deno test` (Edge Functions) | ✅ 19 pasan: 9 de `ia-extraccion` y 10 de `secure-document-upload` (sin cambios) |
| `deno check` de `ia-extraccion/index.ts` | ✅ Compila sin errores de tipos |
| Lectura del `.env` con comentarios y saltos de línea de Windows | ✅ `--dart-define-from-file` lo interpreta bien |
| `flutter build web --dart-define-from-file=.env` + una variable falsa | ✅ No existe `assets/.env`; la variable falsa no aparece en `main.dart.js`; sí aparecen la configuración de Firebase y la URL de Supabase; no hay llamadas a `api.openai.com` |
| Función publicada, llamada sin token | ✅ Responde 401 `{"error":{"code":"sin_sesion",...}}` |
| App local (`flutter run -d web-server`) registrando un documento con IA | ✅ La IA leyó una revisión técnica a través de la Edge Function |
| Web publicada (`firebase deploy`, 8-nov) | ✅ `https://tag-ok-v2.web.app/assets/.env` ya no entrega las variables (devuelve la página de la app) |

---

## 6. Despliegue y pasos pendientes

### Hecho
- [x] `SUPABASE_URL` agregada al `.env` local.
- [x] Secreto `OPENAI_API_KEY` guardado en Supabase (proyecto `auvgnsvzcrszguerorot`). `FIREBASE_PROJECT_ID` ya existía.
- [x] `npx supabase functions deploy ia-extraccion`.
- [x] `OPENAI_API_KEY` y `GEMINI_API_KEY` eliminadas del `.env` local.
- [x] Web publicada con `flutter build web --release --pwa-strategy=none --dart-define-from-file=.env` y `firebase deploy --only hosting --project tag-ok-v2`.

### Pendiente
- [ ] **Crear una clave nueva de OpenAI.** El secreto de Supabase quedó con la **misma clave que estaba expuesta** en la web. Reemplazarlo con `npx supabase secrets set OPENAI_API_KEY=<clave nueva>` y probar la IA.
- [ ] **Revocar la clave vieja de OpenAI**, solo **después** del punto anterior. Si se revoca antes, la IA deja de funcionar.
- [ ] **Revocar la clave de Gemini** en aistudio.google.com (ya no se usa).
- [ ] **Commit y push** a la rama `Estephany`. La web publicada tiene código que todavía no está en GitHub.
- [ ] **Avisar al equipo:**
  - limpiar su `.env` (sin `OPENAI_API_KEY` ni `GEMINI_API_KEY`) y agregar `SUPABASE_URL`;
  - ejecutar y publicar siempre con `--dart-define-from-file=.env`;
  - los APK antiguos traen la clave vieja: al revocarla pierden la IA y hay que generar uno nuevo (`flutter build apk --release --dart-define-from-file=.env`).
- [ ] **Mejora futura:** límite de uso por usuario en la Edge Function. Hoy cualquier usuario registrado puede usar la IA sin tope; la función registra uid, modelo y status para poder revisar el consumo.

### Si se cambian los modelos de IA
La lista de modelos está en **dos lugares** y deben coincidir:
- `OpenAiExtractionService.modelosEnOrden` (`openai_extraction_service.dart`, línea 176).
- `MODELOS_PERMITIDOS` (`supabase/functions/ia-extraccion/validate.ts`, líneas 12–16). Después de cambiarla hay que volver a ejecutar `npx supabase functions deploy ia-extraccion`.
