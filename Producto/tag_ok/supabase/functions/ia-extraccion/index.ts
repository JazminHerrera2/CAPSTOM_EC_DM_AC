// Edge Function: ia-extraccion
//
// Único punto de acceso a OpenAI. La clave de OpenAI vive SOLO acá, como
// secreto de Supabase: la app (web, Android, iOS) nunca la recibe. El cliente
// Flutter (`OpenAiExtractionService`) envía el ID Token de Firebase en
// `Authorization: Bearer <token>` y el cuerpo de la petición a OpenAI. Esta
// función:
//   1. verifica el token contra las claves públicas de Google (JWKS), igual
//      que secure-document-upload,
//   2. rearma la petición solo con lo permitido (modelo de la lista, un
//      mensaje con texto/imagen/PDF y respuesta JSON),
//   3. llama a OpenAI con la clave secreta y devuelve la respuesta tal cual
//      (mismo status y cuerpo), para que la app mantenga su lógica de
//      reintentos y cambio de modelo.
//
// Los errores propios de esta función usan el formato de OpenAI
// ({error: {code, message}}). `configuracion_servidor` indica que falta un
// secreto: la app no reintenta en ese caso.
//
// Variables de entorno (secretos de Supabase):
//   OPENAI_API_KEY        clave de OpenAI (supabase secrets set ...)
//   FIREBASE_PROJECT_ID   el mismo que usa secure-document-upload
//
// Despliegue (desde Producto/tag_ok):
//   npx supabase secrets set OPENAI_API_KEY=sk-...
//   npx supabase functions deploy ia-extraccion
// verify_jwt = false en config.toml: el token es de Firebase, no de Supabase.

import { createRemoteJWKSet, jwtVerify } from "npm:jose@5";
import { extraerBearer, HttpError, MAX_BYTES, validarSolicitud } from "./validate.ts";

const OPENAI_URL = "https://api.openai.com/v1/chat/completions";

const FIREBASE_JWKS = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);

/** Algo menos que el timeout de la app (120 s), para responder antes que ella. */
const TIMEOUT_OPENAI_MS = 115_000;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

/** Devuelve el uid de Firebase si el ID Token es válido; si no, lanza 401. */
async function verificarUid(idToken: string): Promise<string> {
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  if (!projectId) {
    throw new HttpError(500, "configuracion_servidor", "FIREBASE_PROJECT_ID no configurado");
  }
  try {
    const { payload } = await jwtVerify(idToken, FIREBASE_JWKS, {
      algorithms: ["RS256"],
      issuer: `https://securetoken.google.com/${projectId}`,
      audience: projectId,
    });
    if (typeof payload.sub !== "string" || payload.sub.length === 0) {
      throw new Error("sin sub");
    }
    return payload.sub;
  } catch {
    throw new HttpError(401, "sin_sesion", "ID Token inválido o expirado");
  }
}

async function manejar(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    throw new HttpError(405, "metodo_no_permitido", "Método no permitido");
  }

  const uid = await verificarUid(extraerBearer(req.headers.get("Authorization")));

  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) {
    throw new HttpError(500, "configuracion_servidor", "OPENAI_API_KEY no configurada");
  }

  const texto = await req.text();
  if (texto.length > MAX_BYTES) {
    throw new HttpError(413, "archivo_muy_grande", "La solicitud supera el tamaño permitido");
  }
  let body: unknown;
  try {
    body = JSON.parse(texto);
  } catch {
    throw new HttpError(400, "solicitud_invalida", "El cuerpo no es JSON");
  }
  const solicitud = validarSolicitud(body);

  const inicio = Date.now();
  let respuesta: Response;
  try {
    respuesta = await fetch(OPENAI_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(solicitud),
      signal: AbortSignal.timeout(TIMEOUT_OPENAI_MS),
    });
  } catch (e) {
    // 504: la app lo trata como error temporal y reintenta.
    console.error("openai sin respuesta", uid, solicitud.model, String(e));
    throw new HttpError(504, "openai_sin_respuesta", "OpenAI no respondió a tiempo");
  }

  // Solo metadatos: el contenido del documento no se registra.
  console.log(
    `uid=${uid} modelo=${solicitud.model} status=${respuesta.status} ms=${Date.now() - inicio}`,
  );

  return new Response(await respuesta.text(), {
    status: respuesta.status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    return await manejar(req);
  } catch (e) {
    if (e instanceof HttpError) {
      return json({ error: { code: e.code, message: e.message } }, e.status);
    }
    console.error("error inesperado", e);
    return json({ error: { code: "error_interno", message: "Error interno" } }, 500);
  }
});
