// Edge Function: secure-document-upload
//
// Único punto de acceso al bucket privado de documentos. El cliente Flutter
// NO habla con Supabase Storage directamente: envía el ID Token de Firebase
// en `Authorization: Bearer <token>` y esta función:
//   1. verifica el token contra las claves públicas de Google (JWKS),
//   2. toma el uid del token (`sub`) y exige que el path sea usuarios/{uid}/...,
//   3. recién entonces usa la Service Role Key (secreto del servidor) para
//      subir el archivo o emitir una URL firmada de lectura.
//
// Acciones:
//   POST multipart/form-data  { path, file }          -> sube el archivo
//   POST application/json     { action:"sign", path } -> URL firmada de lectura
//   POST application/json     { action:"delete", path } -> elimina el archivo
//
// Imágenes del catálogo de beneficios: viven en `beneficios/{archivo}`.
// Cualquier usuario con sesión puede pedir su URL firmada ("sign"); subir o
// borrar exige ser super admin. Eso se comprueba leyendo administradores/{uid}
// en Firestore con el propio ID Token del usuario, así que lo decide
// firestore.rules (un admin puede leer su documento; los demás no).
//
// Variables de entorno:
//   FIREBASE_PROJECT_ID          (secreto propio, ver README)
//   STORAGE_BUCKET               (opcional, por defecto "documentos")
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY  (las inyecta Supabase solas)

import { createClient } from "npm:@supabase/supabase-js@2";
import { createRemoteJWKSet, jwtVerify } from "npm:jose@5";
import {
  CONTENT_TYPES_BENEFICIO,
  CONTENT_TYPES_PERMITIDOS,
  esPathBeneficio,
  esRolSuperAdmin,
  extraerBearer,
  HttpError,
  MAX_BYTES,
  MAX_BYTES_BENEFICIO,
  rolDeDocumentoFirestore,
  validarPath,
  validarPathBeneficio,
} from "./validate.ts";

const FIREBASE_JWKS = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);

const SIGNED_URL_TTL_SECONDS = 60 * 10;

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
  if (!projectId) throw new HttpError(500, "FIREBASE_PROJECT_ID no configurado");
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
    throw new HttpError(401, "ID Token inválido o expirado");
  }
}

/**
 * `true` si el usuario es super admin. Lee administradores/{uid} con su propio
 * ID Token: las reglas de Firestore solo dejan leer ese documento a un admin.
 */
async function esSuperAdmin(idToken: string, uid: string): Promise<boolean> {
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  if (!projectId) throw new HttpError(500, "FIREBASE_PROJECT_ID no configurado");
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/administradores/${
      encodeURIComponent(uid)
    }`;
  const respuesta = await fetch(url, {
    headers: { Authorization: `Bearer ${idToken}` },
  });
  if (!respuesta.ok) {
    await respuesta.body?.cancel();
    return false;
  }
  return esRolSuperAdmin(rolDeDocumentoFirestore(await respuesta.json()));
}

async function exigirSuperAdmin(idToken: string, uid: string): Promise<void> {
  if (!(await esSuperAdmin(idToken, uid))) {
    throw new HttpError(403, "Solo un administrador puede modificar las imágenes de beneficios");
  }
}

async function manejar(req: Request): Promise<Response> {
  if (req.method !== "POST") throw new HttpError(405, "Método no permitido");

  const idToken = extraerBearer(req.headers.get("Authorization"));
  const uid = await verificarUid(idToken);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
  const bucket = Deno.env.get("STORAGE_BUCKET") ?? "documentos";

  const contentType = req.headers.get("Content-Type") ?? "";

  // ---- Lectura: URL firmada ------------------------------------------
  if (contentType.includes("application/json")) {
    const body = await req.json().catch(() => null);
    if (body?.action !== "sign" && body?.action !== "delete") {
      throw new HttpError(400, "action inválida");
    }
    const esBeneficio = esPathBeneficio(body.path);
    const path = esBeneficio
      ? validarPathBeneficio(body.path)
      : validarPath(body.path, uid);

    if (body.action === "delete") {
      if (esBeneficio) await exigirSuperAdmin(idToken, uid);
      const { error } = await supabase.storage.from(bucket).remove([path]);
      if (error) {
        console.error("delete error", error.message);
        throw new HttpError(500, "No se pudo eliminar el archivo");
      }
      return json({ deleted: path });
    }

    const { data, error } = await supabase.storage
      .from(bucket)
      .createSignedUrl(path, SIGNED_URL_TTL_SECONDS);
    if (error || !data) throw new HttpError(404, "Archivo no encontrado");
    return json({ signedUrl: data.signedUrl, expiresIn: SIGNED_URL_TTL_SECONDS });
  }

  // ---- Escritura: subida ---------------------------------------------
  if (contentType.includes("multipart/form-data")) {
    const form = await req.formData();
    const rutaPedida = form.get("path");
    const esBeneficio = esPathBeneficio(rutaPedida);
    const path = esBeneficio
      ? validarPathBeneficio(rutaPedida)
      : validarPath(rutaPedida, uid);
    if (esBeneficio) await exigirSuperAdmin(idToken, uid);

    const file = form.get("file");
    if (!(file instanceof File)) throw new HttpError(400, "Falta el archivo");
    const maxBytes = esBeneficio ? MAX_BYTES_BENEFICIO : MAX_BYTES;
    if (file.size === 0 || file.size > maxBytes) {
      throw new HttpError(
        413,
        `Tamaño de archivo no permitido (máx. ${maxBytes / 1024 / 1024} MB)`,
      );
    }
    const tiposPermitidos = esBeneficio
      ? CONTENT_TYPES_BENEFICIO
      : CONTENT_TYPES_PERMITIDOS;
    if (!tiposPermitidos.has(file.type)) {
      throw new HttpError(415, "Tipo de archivo no permitido");
    }

    const { error } = await supabase.storage
      .from(bucket)
      .upload(path, file, { contentType: file.type, upsert: false });
    if (error) {
      console.error("upload error", error.message);
      throw new HttpError(500, "No se pudo guardar el archivo");
    }
    return json({ path }, 201);
  }

  throw new HttpError(415, "Content-Type no soportado");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    return await manejar(req);
  } catch (e) {
    if (e instanceof HttpError) return json({ error: e.message }, e.status);
    console.error("error inesperado", e);
    return json({ error: "Error interno" }, 500);
  }
});
