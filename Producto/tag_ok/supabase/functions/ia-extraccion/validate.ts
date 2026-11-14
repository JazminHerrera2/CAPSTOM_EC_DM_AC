// Validaciones puras (sin red) de la Edge Function ia-extraccion, separadas
// para poder probarlas con `deno test`.

/** Tamaño máximo del cuerpo recibido (imagen o PDF en base64 + prompt). */
export const MAX_BYTES = 20 * 1024 * 1024; // 20 MB

/**
 * Modelos que la app puede pedir: los mismos de
 * `OpenAiExtractionService.modelosEnOrden`. Si se cambia uno allá, se cambia
 * también acá; así una sesión robada no puede usar un modelo más caro.
 */
export const MODELOS_PERMITIDOS = new Set([
  "gpt-6-luna",
  "gpt-5.6-luna",
  "gpt-5.4-nano",
]);

const MAX_PARTES = 10;
const MAX_TEXTO = 80_000; // el prompt de auditoría manda hasta 60.000 caracteres

/**
 * Error con el mismo formato que devuelve OpenAI (`{error: {code, message}}`),
 * para que la app lo interprete igual que un error de OpenAI.
 */
export class HttpError extends Error {
  constructor(public status: number, public code: string, message: string) {
    super(message);
  }
}

export function extraerBearer(header: string | null): string {
  const m = header?.match(/^Bearer\s+(.+)$/i);
  if (!m) throw new HttpError(401, "sin_sesion", "Falta el ID Token de Firebase");
  return m[1].trim();
}

type Parte = Record<string, unknown>;

function validarParte(parte: unknown): Parte {
  if (typeof parte !== "object" || parte === null) {
    throw new HttpError(400, "solicitud_invalida", "Parte del mensaje inválida");
  }
  const p = parte as Record<string, unknown>;
  switch (p.type) {
    case "text":
      if (typeof p.text !== "string" || p.text.length > MAX_TEXTO) {
        throw new HttpError(400, "solicitud_invalida", "Texto inválido o demasiado largo");
      }
      return { type: "text", text: p.text };
    case "image_url": {
      const img = p.image_url as Record<string, unknown> | undefined;
      // Solo imágenes embebidas: OpenAI no debe ir a buscar URLs externas.
      if (typeof img?.url !== "string" || !img.url.startsWith("data:image/")) {
        throw new HttpError(400, "solicitud_invalida", "La imagen debe ir embebida (data:image/...)");
      }
      const detail = img.detail === "low" || img.detail === "auto" ? img.detail : "high";
      return { type: "image_url", image_url: { url: img.url, detail } };
    }
    case "file": {
      const f = p.file as Record<string, unknown> | undefined;
      if (
        typeof f?.file_data !== "string" ||
        !f.file_data.startsWith("data:application/pdf;base64,")
      ) {
        throw new HttpError(400, "solicitud_invalida", "Solo se aceptan archivos PDF embebidos");
      }
      const filename = typeof f.filename === "string" && f.filename.length <= 200
        ? f.filename
        : "documento.pdf";
      return { type: "file", file: { filename, file_data: f.file_data } };
    }
    default:
      throw new HttpError(400, "solicitud_invalida", "Tipo de contenido no permitido");
  }
}

function validarFormato(formato: unknown): Record<string, unknown> {
  const f = formato as Record<string, unknown> | undefined;
  if (f?.type === "json_object") return { type: "json_object" };
  if (f?.type === "json_schema") {
    const js = f.json_schema as Record<string, unknown> | undefined;
    if (
      typeof js?.name !== "string" || typeof js.schema !== "object" || js.schema === null
    ) {
      throw new HttpError(400, "solicitud_invalida", "json_schema inválido");
    }
    return {
      type: "json_schema",
      json_schema: { name: js.name, strict: js.strict === true, schema: js.schema },
    };
  }
  throw new HttpError(400, "solicitud_invalida", "response_format inválido");
}

/**
 * Rearma la petición a OpenAI solo con lo que la app usa (un mensaje de
 * usuario con texto, imágenes o PDF, y respuesta JSON). Cualquier otro campo
 * que venga del cliente se descarta: el cliente no decide parámetros de costo.
 */
export function validarSolicitud(body: unknown): {
  model: string;
  messages: { role: "user"; content: Parte[] }[];
  response_format: Record<string, unknown>;
} {
  const b = body as Record<string, unknown> | null;
  if (typeof b?.model !== "string" || !MODELOS_PERMITIDOS.has(b.model)) {
    throw new HttpError(400, "modelo_no_permitido", "Modelo no permitido");
  }
  const mensajes = b.messages;
  if (!Array.isArray(mensajes) || mensajes.length !== 1) {
    throw new HttpError(400, "solicitud_invalida", "Se espera un único mensaje");
  }
  const mensaje = mensajes[0] as Record<string, unknown>;
  if (mensaje?.role !== "user" || !Array.isArray(mensaje.content)) {
    throw new HttpError(400, "solicitud_invalida", "Mensaje inválido");
  }
  if (mensaje.content.length === 0 || mensaje.content.length > MAX_PARTES) {
    throw new HttpError(400, "solicitud_invalida", "Cantidad de partes no permitida");
  }
  return {
    model: b.model,
    messages: [{ role: "user", content: mensaje.content.map(validarParte) }],
    response_format: validarFormato(b.response_format),
  };
}
