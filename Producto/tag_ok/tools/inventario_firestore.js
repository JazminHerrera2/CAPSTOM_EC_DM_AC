/**
 * Inventario de la base de datos: lista cada colección (y subcolección) de
 * Firestore con su cantidad de documentos y, por cada campo, en cuántos
 * documentos aparece y de qué tipo es. SOLO LECTURA: no escribe nada.
 *
 * Solo imprime NOMBRES de campos, tipos y conteos; nunca valores (así no
 * salen emails, patentes ni otros datos personales).
 *
 * Uso (desde Producto/tag_ok/tools, mismo entorno que verificar_admins.js):
 *   set GOOGLE_APPLICATION_CREDENTIALS=C:\ruta\fuera-del-repo\service-account.json
 *   node inventario_firestore.js
 *
 * Opcional: guardar el resultado fuera del repo
 *   node inventario_firestore.js > C:\ruta\fuera-del-repo\inventario.txt
 */
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore, Timestamp, DocumentReference, GeoPoint } = require('firebase-admin/firestore');

const PROJECT_ID = 'tag-ok-v2';

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

function tipoDe(valor) {
  if (valor === null) return 'null';
  if (Array.isArray(valor)) return 'list';
  if (valor instanceof Timestamp) return 'timestamp';
  if (valor instanceof DocumentReference) return 'reference';
  if (valor instanceof GeoPoint) return 'geopoint';
  if (Buffer.isBuffer(valor)) return 'bytes';
  if (typeof valor === 'number') return Number.isInteger(valor) ? 'int' : 'number';
  if (typeof valor === 'object') return 'map';
  return typeof valor; // string, boolean
}

/** Cuenta campos de un documento en `campos` (clave -> {n, tipos}). */
function contar(campos, data, prefijo = '') {
  for (const [clave, valor] of Object.entries(data)) {
    const ruta = prefijo + clave;
    const tipo = tipoDe(valor);
    const c = campos.get(ruta) ?? { n: 0, tipos: new Map() };
    c.n += 1;
    c.tipos.set(tipo, (c.tipos.get(tipo) ?? 0) + 1);
    campos.set(ruta, c);
    // Un mapa se baja un nivel (p. ej. alertas_vistas.*), con tope de 1 nivel.
    if (tipo === 'map' && prefijo === '') contar(campos, valor, ruta + '.');
  }
}

async function inventariar(coleccion, ruta, subcolecciones) {
  const campos = new Map();
  let total = 0;
  for await (const doc of coleccion.stream()) {
    total += 1;
    contar(campos, doc.data());
    // Descubre subcolecciones a partir de los documentos (solo ruta raíz).
    if (subcolecciones) {
      for (const sub of await doc.ref.listCollections()) {
        subcolecciones.add(sub.id);
      }
    }
  }
  return { ruta, total, campos };
}

function imprimir({ ruta, total, campos }) {
  console.log(`\n=== ${ruta}  (${total} documentos) ===`);
  if (total === 0) return;
  const filas = [...campos.entries()].sort((a, b) => a[0].localeCompare(b[0]));
  for (const [campo, { n, tipos }] of filas) {
    const t = [...tipos.entries()].map(([k, v]) => `${k}:${v}`).join(', ');
    console.log(`  ${campo.padEnd(34)} ${String(n).padStart(6)}/${total}   ${t}`);
  }
}

async function main() {
  const raices = await db.listCollections();
  console.log(`Proyecto ${PROJECT_ID}: ${raices.length} colecciones en la raíz`);
  console.log(raices.map((c) => c.id).sort().join(', '));

  const subPorRaiz = new Map();
  for (const col of raices.sort((a, b) => a.id.localeCompare(b.id))) {
    const subs = new Set();
    const r = await inventariar(col, col.id, subs);
    imprimir(r);
    subPorRaiz.set(col.id, subs);
  }

  // Subcolecciones: se leen con collectionGroup (todas las rutas a la vez).
  for (const [raiz, subs] of subPorRaiz) {
    for (const nombre of [...subs].sort()) {
      const r = await inventariar(db.collectionGroup(nombre), `${raiz}/{id}/${nombre}`, null);
      imprimir(r);
    }
  }
}

main().catch((e) => {
  console.error('Error:', e.message);
  process.exit(1);
});
