import { assertEquals } from "jsr:@std/assert@1";
import { extraerBearer, HttpError, validarSolicitud } from "./validate.ts";

function codigo(fn: () => unknown): string {
  try {
    fn();
  } catch (e) {
    if (e instanceof HttpError) return `${e.status} ${e.code}`;
    throw e;
  }
  return "ok";
}

const IMAGEN = "data:image/jpeg;base64,AAAA";
const PDF = "data:application/pdf;base64,AAAA";

function solicitud(extra: Record<string, unknown> = {}) {
  return {
    model: "gpt-5.4-nano",
    messages: [{
      role: "user",
      content: [
        { type: "image_url", image_url: { url: IMAGEN, detail: "high" } },
        { type: "text", text: "Extrae los datos" },
      ],
    }],
    response_format: { type: "json_object" },
    ...extra,
  };
}

Deno.test("acepta la petición que arma la app", () => {
  const r = validarSolicitud(solicitud());
  assertEquals(r.model, "gpt-5.4-nano");
  assertEquals(r.messages[0].content.length, 2);
  assertEquals(r.response_format, { type: "json_object" });
});

Deno.test("acepta PDF embebido y esquema estricto", () => {
  const r = validarSolicitud(solicitud({
    messages: [{
      role: "user",
      content: [{ type: "file", file: { filename: "boleta.pdf", file_data: PDF } }],
    }],
    response_format: {
      type: "json_schema",
      json_schema: { name: "mantencion", strict: true, schema: { type: "object" } },
    },
  }));
  assertEquals(r.messages[0].content[0], {
    type: "file",
    file: { filename: "boleta.pdf", file_data: PDF },
  });
  assertEquals(r.response_format.type, "json_schema");
});

Deno.test("descarta campos extra del cliente (parámetros de costo)", () => {
  const r = validarSolicitud(solicitud({ max_tokens: 100000, n: 50, temperature: 2 }));
  assertEquals(Object.keys(r).sort(), ["messages", "model", "response_format"]);
});

Deno.test("rechaza modelos fuera de la lista", () => {
  assertEquals(
    codigo(() => validarSolicitud(solicitud({ model: "gpt-4o" }))),
    "400 modelo_no_permitido",
  );
});

Deno.test("rechaza imágenes por URL externa", () => {
  const body = solicitud({
    messages: [{
      role: "user",
      content: [{ type: "image_url", image_url: { url: "https://ejemplo.cl/a.jpg" } }],
    }],
  });
  assertEquals(codigo(() => validarSolicitud(body)), "400 solicitud_invalida");
});

Deno.test("rechaza archivos que no son PDF", () => {
  const body = solicitud({
    messages: [{
      role: "user",
      content: [{ type: "file", file: { file_data: "data:text/plain;base64,AAAA" } }],
    }],
  });
  assertEquals(codigo(() => validarSolicitud(body)), "400 solicitud_invalida");
});

Deno.test("rechaza roles distintos de user y varios mensajes", () => {
  const sistema = solicitud({
    messages: [{ role: "system", content: [{ type: "text", text: "x" }] }],
  });
  assertEquals(codigo(() => validarSolicitud(sistema)), "400 solicitud_invalida");

  const dos = solicitud({
    messages: [
      { role: "user", content: [{ type: "text", text: "a" }] },
      { role: "user", content: [{ type: "text", text: "b" }] },
    ],
  });
  assertEquals(codigo(() => validarSolicitud(dos)), "400 solicitud_invalida");
});

Deno.test("rechaza response_format desconocido", () => {
  assertEquals(
    codigo(() => validarSolicitud(solicitud({ response_format: { type: "text" } }))),
    "400 solicitud_invalida",
  );
});

Deno.test("401 sin token de Firebase", () => {
  assertEquals(codigo(() => extraerBearer(null)), "401 sin_sesion");
  assertEquals(codigo(() => extraerBearer("Basic abc")), "401 sin_sesion");
  assertEquals(extraerBearer("Bearer abc.def"), "abc.def");
});
