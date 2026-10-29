// Validaciones puras (sin red) de la Edge Function, separadas para poder
// probarlas con `deno test`.

export const MAX_BYTES = 10 * 1024 * 1024; // 10 MB

export const CONTENT_TYPES_PERMITIDOS = new Set([
  "image/jpeg",
  "image/png",
  "application/pdf",
]);

export class HttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

const SEGMENTO_SEGURO = /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/;

/**
 * Exige que `path` sea `usuarios/{uid}/...` con el uid del token ya
 * verificado. Lanza 400 si el path es malformado (traversal, caracteres
 * raros) y 403 si pertenece a otro usuario.
 */
export function validarPath(path: unknown, uid: string): string {
  if (typeof path !== "string" || path.length === 0 || path.length > 512) {
    throw new HttpError(400, "path inválido");
  }
  const segmentos = path.split("/");
  if (segmentos.length < 3 || !segmentos.every((s) => SEGMENTO_SEGURO.test(s))) {
    throw new HttpError(400, "path inválido");
  }
  if (segmentos.some((s) => s.includes(".."))) {
    throw new HttpError(400, "path inválido");
  }
  if (segmentos[0] !== "usuarios" || segmentos[1] !== uid) {
    throw new HttpError(403, "El path no pertenece al usuario autenticado");
  }
  return path;
}

export function extraerBearer(header: string | null): string {
  const m = header?.match(/^Bearer\s+(.+)$/i);
  if (!m) throw new HttpError(401, "Falta el ID Token de Firebase");
  return m[1].trim();
}

// ---- Imágenes del catálogo de beneficios --------------------------------
// Viven en `beneficios/{archivo}` (no en usuarios/{uid}/...). Cualquier
// usuario con sesión puede pedir su URL firmada; subir o borrar exige ser
// super admin (ver index.ts).

export const MAX_BYTES_BENEFICIO = 5 * 1024 * 1024; // 5 MB

export const CONTENT_TYPES_BENEFICIO = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
]);

export function esPathBeneficio(path: unknown): boolean {
  return typeof path === "string" && path.startsWith("beneficios/");
}

/** Exige exactamente `beneficios/{archivo}` con un nombre de archivo seguro. */
export function validarPathBeneficio(path: unknown): string {
  if (typeof path !== "string" || path.length === 0 || path.length > 512) {
    throw new HttpError(400, "path inválido");
  }
  const segmentos = path.split("/");
  if (
    segmentos.length !== 2 ||
    segmentos[0] !== "beneficios" ||
    !SEGMENTO_SEGURO.test(segmentos[1]) ||
    segmentos[1].includes("..")
  ) {
    throw new HttpError(400, "path inválido");
  }
  return path;
}

// Mismos valores que reconocen firestore.rules (isSuperAdmin) y el panel.
const ROLES_SUPER_ADMIN = [
  "super_admin",
  "super_administrador",
  "superadmin",
  "super administrador",
];

export function esRolSuperAdmin(rol: unknown): boolean {
  return typeof rol === "string" &&
    ROLES_SUPER_ADMIN.includes(rol.toLowerCase());
}

/** Lee `rol` (o `role`) de un documento devuelto por la API REST de Firestore. */
// deno-lint-ignore no-explicit-any
export function rolDeDocumentoFirestore(doc: any): unknown {
  return doc?.fields?.rol?.stringValue ?? doc?.fields?.role?.stringValue;
}
