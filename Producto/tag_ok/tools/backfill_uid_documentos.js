/**
 * Backfill: agrega `uid` a los documentos_vehiculares antiguos, copiándolo
 * desde el dueño del vehículo asociado (vehiculos/{vehiculo_id}.id_usuario).
 *
 * Por defecto es DRY-RUN: no escribe nada, solo informa. Para escribir hay que
 * pasar --apply de forma explícita.
 *
 * Uso (desde Producto/tag_ok/tools):
 *   npm install firebase-admin
 *   set GOOGLE_APPLICATION_CREDENTIALS=C:\ruta\fuera-del-repo\service-account.json
 *   node backfill_uid_documentos.js            (dry-run)
 *   node backfill_uid_documentos.js --apply    (escribe)
 *
 * La llave de service account NO debe guardarse dentro del repositorio.
 *
 * Seguridad del script:
 *  - Solo toca documentos que NO tienen `uid`; nunca sobrescribe uno existente.
 *  - Solo agrega el campo `uid` (update parcial); no modifica nada más.
 *  - Si el vehículo no existe o su dueño no se puede determinar, NO adivina:
 *    deja el documento sin tocar y lo lista en el informe.
 *  - Es idempotente: se puede ejecutar varias veces.
 */
// API modular (firebase-admin >= 10): el namespace `admin.firestore()` ya no existe.
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const PROJECT_ID = 'tag-ok-v2';
const APPLY = process.argv.includes('--apply');
const BATCH_SIZE = 400;

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

/** Devuelve el uid del dueño según el formato de id_usuario, o null. */
function resolverUid(idUsuario) {
  if (!idUsuario) return null;
  // DocumentReference (formato normal de Fase 1 y 2): usuarios/{uid}
  if (typeof idUsuario === 'object' && idUsuario.path !== undefined) {
    const partes = idUsuario.path.split('/');
    return partes.length === 2 && partes[0] === 'usuarios' ? partes[1] : null;
  }
  if (typeof idUsuario === 'string') {
    const s = idUsuario.trim();
    const m = s.match(/^\/?usuarios\/([^/]+)$/); // '/usuarios/{uid}'
    if (m) return m[1];
    return s.length > 0 && !s.includes('/') ? s : null; // uid a secas
  }
  return null;
}

async function main() {
  console.log(`Proyecto: ${PROJECT_ID} | modo: ${APPLY ? 'APPLY (ESCRIBE)' : 'DRY-RUN'}`);

  const docs = await db.collection('documentos_vehiculares').get();
  const cache = new Map(); // vehiculo_id -> uid | null (dueño no resuelto)
  const aActualizar = [];
  const informe = { total: docs.size, yaTenianUid: 0, sinVehiculoId: [], vehiculoInexistente: [], duenoNoResuelto: [] };

  for (const doc of docs.docs) {
    const data = doc.data();
    if (typeof data.uid === 'string' && data.uid.length > 0) {
      informe.yaTenianUid++;
      continue;
    }
    const vehiculoId = data.vehiculo_id;
    if (typeof vehiculoId !== 'string' || vehiculoId.trim() === '') {
      informe.sinVehiculoId.push(doc.id);
      continue;
    }
    if (!cache.has(vehiculoId)) {
      const v = await db.collection('vehiculos').doc(vehiculoId).get();
      cache.set(vehiculoId, v.exists ? { uid: resolverUid(v.data().id_usuario) } : { inexistente: true });
    }
    const r = cache.get(vehiculoId);
    if (r.inexistente) informe.vehiculoInexistente.push(`${doc.id} (vehiculo ${vehiculoId})`);
    else if (!r.uid) informe.duenoNoResuelto.push(`${doc.id} (vehiculo ${vehiculoId})`);
    else aActualizar.push({ ref: doc.ref, uid: r.uid });
  }

  console.log('\n--- Informe ---');
  console.log(`Documentos totales:                 ${informe.total}`);
  console.log(`Ya tenían uid (no se tocan):        ${informe.yaTenianUid}`);
  console.log(`Se les agregará uid:                ${aActualizar.length}`);
  console.log(`Sin vehiculo_id válido:             ${informe.sinVehiculoId.length}`);
  console.log(`Vehículo inexistente (huérfanos):   ${informe.vehiculoInexistente.length}`);
  console.log(`Dueño del vehículo no resuelto:     ${informe.duenoNoResuelto.length}`);
  for (const [titulo, lista] of [
    ['Sin vehiculo_id válido', informe.sinVehiculoId],
    ['Vehículo inexistente', informe.vehiculoInexistente],
    ['Dueño no resuelto', informe.duenoNoResuelto],
  ]) {
    if (lista.length) console.log(`\n${titulo}:\n  ` + lista.join('\n  '));
  }

  if (!APPLY) {
    console.log('\nDRY-RUN: no se escribió nada. Revisa el informe y ejecuta con --apply.');
    return;
  }

  for (let i = 0; i < aActualizar.length; i += BATCH_SIZE) {
    const batch = db.batch();
    for (const { ref, uid } of aActualizar.slice(i, i + BATCH_SIZE)) {
      batch.update(ref, { uid });
    }
    await batch.commit();
    console.log(`Escritos ${Math.min(i + BATCH_SIZE, aActualizar.length)}/${aActualizar.length}`);
  }
  console.log('\nBackfill terminado. Vuelve a ejecutar en dry-run: "Se les agregará uid" debe ser 0.');
}

main().catch((e) => { console.error(e); process.exit(1); });
