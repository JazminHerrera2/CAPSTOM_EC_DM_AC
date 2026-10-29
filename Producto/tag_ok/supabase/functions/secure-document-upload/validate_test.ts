import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  CONTENT_TYPES_BENEFICIO,
  esPathBeneficio,
  esRolSuperAdmin,
  extraerBearer,
  HttpError,
  rolDeDocumentoFirestore,
  validarPath,
  validarPathBeneficio,
} from "./validate.ts";

const UID = "abc123UID";

function status(fn: () => unknown): number {
  try {
    fn();
  } catch (e) {
    if (e instanceof HttpError) return e.status;
    throw e;
  }
  return 200;
}

Deno.test("acepta path dentro de la carpeta del usuario", () => {
  const p = `usuarios/${UID}/documentos_vehiculares/veh1/123.jpg`;
  assertEquals(validarPath(p, UID), p);
});

Deno.test("403 si el path es de otro usuario", () => {
  assertEquals(status(() => validarPath("usuarios/otro/doc/1.jpg", UID)), 403);
});

Deno.test("403 si la carpeta raíz no es usuarios", () => {
  assertEquals(status(() => validarPath(`publico/${UID}/1.jpg`, UID)), 403);
});

Deno.test("400 ante path traversal y caracteres raros", () => {
  for (
    const p of [
      `usuarios/${UID}/../otro/1.jpg`,
      `usuarios/${UID}/..%2Fotro/1.jpg`,
      `/usuarios/${UID}/1.jpg`,
      `usuarios//${UID}/1.jpg`,
      `usuarios/${UID}/a b.jpg`,
      `usuarios/${UID}`,
      "",
    ]
  ) {
    assertEquals(status(() => validarPath(p, UID)), 400, p);
  }
});

Deno.test("400 si path no es string", () => {
  assertEquals(status(() => validarPath(null, UID)), 400);
  assertEquals(status(() => validarPath(42, UID)), 400);
});

Deno.test("Bearer: 401 sin header o con formato erróneo", () => {
  assertEquals(status(() => extraerBearer(null)), 401);
  assertEquals(status(() => extraerBearer("Basic xxx")), 401);
  assertEquals(extraerBearer("Bearer tok.en.x"), "tok.en.x");
  assertThrows(() => extraerBearer(""), HttpError);
});

Deno.test("beneficios: acepta beneficios/{archivo} y rechaza el resto", () => {
  assertEquals(validarPathBeneficio("beneficios/123_ab.png"), "beneficios/123_ab.png");
  for (
    const p of [
      "beneficios",
      "beneficios/",
      "beneficios/a/b.png",
      "beneficios/../usuarios/x/1.png",
      "beneficios/a b.png",
      "beneficios/..png",
      "/beneficios/a.png",
      "usuarios/u/beneficios/a.png",
      "",
      null,
      42,
    ]
  ) {
    assertEquals(status(() => validarPathBeneficio(p)), 400, String(p));
  }
});

Deno.test("beneficios: esPathBeneficio distingue la carpeta", () => {
  assertEquals(esPathBeneficio("beneficios/a.png"), true);
  assertEquals(esPathBeneficio("usuarios/u/a.png"), false);
  assertEquals(esPathBeneficio(undefined), false);
});

Deno.test("beneficios: solo imágenes, no PDF", () => {
  assertEquals(CONTENT_TYPES_BENEFICIO.has("image/webp"), true);
  assertEquals(CONTENT_TYPES_BENEFICIO.has("application/pdf"), false);
});

Deno.test("roles de super admin como en las reglas", () => {
  assertEquals(esRolSuperAdmin("super_admin"), true);
  assertEquals(esRolSuperAdmin("Super Administrador"), true);
  assertEquals(esRolSuperAdmin("operador"), false);
  assertEquals(esRolSuperAdmin(undefined), false);
  assertEquals(rolDeDocumentoFirestore({ fields: { rol: { stringValue: "super_admin" } } }), "super_admin");
  assertEquals(rolDeDocumentoFirestore({ fields: { role: { stringValue: "operador" } } }), "operador");
  assertEquals(rolDeDocumentoFirestore({}), undefined);
});
