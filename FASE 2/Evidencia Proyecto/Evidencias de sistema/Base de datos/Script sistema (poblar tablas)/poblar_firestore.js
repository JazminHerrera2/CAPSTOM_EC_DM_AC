#!/usr/bin/env node
'use strict';
/**
 * TAG OK – Fase 2 · Script de sistema: poblar tablas (colecciones de Cloud Firestore)
 *
 * Uso:
 *   node poblar_firestore.js --dry-run            Valida los datos y muestra el resumen. No se conecta a Firebase.
 *   node poblar_firestore.js                      Escribe los datos en Firestore (pide confirmar el proyecto).
 *   node poblar_firestore.js --auth               Además crea las cuentas en Firebase Authentication.
 *   node poblar_firestore.js --limpiar            Borra SOLO los documentos que este script crea.
 *   node poblar_firestore.js --proyecto mi-id     Fuerza el id del proyecto.
 *   node poblar_firestore.js --yes                No pregunta confirmación.
 *
 * Credenciales: variable GOOGLE_APPLICATION_CREDENTIALS apuntando a la clave de
 * cuenta de servicio (JSON). Con el emulador (FIRESTORE_EMULATOR_HOST) no hace falta.
 * El script es idempotente: usa ids fijos y set(), así que se puede ejecutar varias veces.
 */
const fs = require('fs');
const readline = require('readline');
const { docs } = require('./datos');
const { validar } = require('./validar');

const args = new Set(process.argv.slice(2));
const valorDe = (flag) => { const i = process.argv.indexOf(flag); return i >= 0 ? process.argv[i + 1] : undefined; };
const PASSWORD_DEMO = 'TagOk2026!';

function resumen() {
  const { errores, conteo } = validar(docs);
  console.log('Documentos a escribir por colección:');
  Object.entries(conteo).forEach(([k, n]) => console.log(`  ${k.padEnd(24)} ${n}`));
  console.log(`  ${'TOTAL'.padEnd(24)} ${docs.length}`);
  if (errores.length) {
    console.error(`\n✗ ${errores.length} problema(s) de coherencia:`);
    errores.forEach((e) => console.error('  - ' + e));
    process.exit(1);
  }
  console.log('\n✓ Datos coherentes: todas las referencias y valores permitidos son válidos.');
}

function detectarProyecto() {
  const f = valorDe('--proyecto');
  if (f) return f;
  if (process.env.GCLOUD_PROJECT) return process.env.GCLOUD_PROJECT;
  if (process.env.GOOGLE_CLOUD_PROJECT) return process.env.GOOGLE_CLOUD_PROJECT;
  const cred = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (cred && fs.existsSync(cred)) {
    try { return JSON.parse(fs.readFileSync(cred, 'utf8')).project_id; } catch (_) { /* sigue */ }
  }
  return undefined;
}

const preguntar = (q) => new Promise((res) => {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  rl.question(q, (a) => { rl.close(); res(a.trim()); });
});

// Convierte los marcadores de datos.js en tipos reales de Firestore.
function convertir(valor, admin, db) {
  if (valor === null || valor === undefined) return valor;
  if (valor instanceof Date) return valor; // el SDK lo guarda como Timestamp
  if (Array.isArray(valor)) return valor.map((v) => convertir(v, admin, db));
  if (typeof valor === 'object') {
    if (valor.__geo) return new admin.firestore.GeoPoint(valor.__geo[0], valor.__geo[1]);
    if (valor.__ref) return db.doc(valor.__ref);
    return Object.fromEntries(Object.entries(valor).map(([k, v]) => [k, convertir(v, admin, db)]));
  }
  return valor;
}

async function enLotes(db, items, accion) {
  for (let i = 0; i < items.length; i += 400) {
    const batch = db.batch();
    items.slice(i, i + 400).forEach((x) => accion(batch, x));
    await batch.commit();
  }
}

async function main() {
  resumen();
  if (args.has('--dry-run')) return;

  const admin = require('firebase-admin');
  const emulador = !!process.env.FIRESTORE_EMULATOR_HOST;
  const proyecto = detectarProyecto();
  if (!proyecto) {
    console.error('\nNo se pudo detectar el proyecto. Define GOOGLE_APPLICATION_CREDENTIALS o usa --proyecto <id>.');
    process.exit(1);
  }
  admin.initializeApp(emulador ? { projectId: proyecto } : { projectId: proyecto, credential: admin.credential.applicationDefault() });
  const db = admin.firestore();

  const accion = args.has('--limpiar') ? 'BORRAR los documentos de ejemplo de' : 'ESCRIBIR datos de ejemplo en';
  console.log(`\nProyecto: ${proyecto}${emulador ? ' (emulador)' : ''}`);
  if (!emulador && !args.has('--yes')) {
    const r = await preguntar(`Vas a ${accion} este proyecto. Escribe el id del proyecto para confirmar: `);
    if (r !== proyecto) { console.log('Cancelado.'); process.exit(0); }
  }

  if (args.has('--limpiar')) {
    await enLotes(db, docs, (b, x) => b.delete(db.doc(x.path)));
    console.log(`✓ ${docs.length} documentos de ejemplo eliminados.`);
    return;
  }

  await enLotes(db, docs, (b, x) => b.set(db.doc(x.path), convertir(x.data, admin, db)));
  console.log(`✓ ${docs.length} documentos escritos en Firestore.`);

  if (args.has('--auth')) {
    const cuentas = docs
      .filter((x) => /^(usuarios|administradores)\/[^/]+$/.test(x.path))
      .map((x) => ({ uid: x.path.split('/')[1], email: x.data.email, displayName: x.data.nombre_mostrar }));
    for (const c of cuentas) {
      const props = { email: c.email, password: PASSWORD_DEMO, emailVerified: true };
      if (c.displayName) props.displayName = c.displayName;
      try { await admin.auth().updateUser(c.uid, props); } catch (e) {
        if (e.code === 'auth/user-not-found') await admin.auth().createUser({ uid: c.uid, ...props });
        else throw e;
      }
    }
    console.log(`✓ ${cuentas.length} cuentas en Firebase Authentication (contraseña de prueba: ${PASSWORD_DEMO}).`);
  }
}

if (require.main === module) {
  main().catch((e) => { console.error('\n✗ Error:', e.message); process.exit(1); });
}
module.exports = { convertir };
