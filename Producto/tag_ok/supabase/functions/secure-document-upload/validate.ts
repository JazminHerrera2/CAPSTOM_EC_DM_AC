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
