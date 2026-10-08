/**
 * Pruebas de firestore.rules.borrador contra el EMULADOR local.
 * Proyecto "demo-tag-ok": el prefijo demo- garantiza que nunca se conecta a
 * Firebase real ni toca tag-ok-v2.
 *
 * Ejecutar (desde Producto/tag_ok/tools/rules_test):
 *   firebase emulators:exec --only firestore --project demo-tag-ok "node --test rules.test.js"
 *
 * Requiere Java (para el emulador) y las dependencias de tools/ (npm install).
 * Cada prueba que debe fallar (assertFails) tiene una "gemela de control" que
 * debe pasar: si fallaran las dos, el problema sería el dato, no la regla.
 */
const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const firebase = require('firebase/compat/app');
require('firebase/compat/firestore');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');

const Timestamp = firebase.firestore.Timestamp;
const ADMIN = 'gL8jsnKxg7e2YokJW4RQ8SeLgsv2';
const UID_A = 'uidA_dueno';
const UID_B = 'uidB_otro';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-tag-ok',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules.borrador'), 'utf8'),
    },
  });
});
after(async () => env && (await env.cleanup()));

// Datos base (se cargan sin reglas) antes de cada prueba.
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`administradores/${ADMIN}`).set({ rol: 'super_admin', email: 'admin@example.test' });
    for (const uid of [UID_A, UID_B]) {
      await db.doc(`usuarios/${uid}`).set({
        email: `${uid}@example.test`,
        fecha_creacion: Timestamp.now(),
        limite_presupuesto_mensual: 50000,
      });
    }
    await db.doc(`usuarios/${UID_A}/trips/t1`).set({ date: '2026-10-01T10:00:00', totalCost: 1000, tolls: [] });
    await db.doc('vehiculos/vehA').set({
      id_usuario: db.doc(`usuarios/${UID_A}`), patente: 'AAAA11', marca: 'Toyota', estado: 'activo',
    });
    await db.doc('vehiculos/vehB').set({
      id_usuario: db.doc(`usuarios/${UID_B}`), patente: 'BBBB22', estado: 'activo',
    });
    await db.doc('documentos_vehiculares/docB').set({
      uid: UID_B, vehiculo_id: 'vehB', tipo_documento: 'soap',
      origen_registro: 'manual', fecha_registro: Timestamp.now(),
    });
  });
});

const como = (uid) => env.authenticatedContext(uid).firestore();
const anonimo = () => env.unauthenticatedContext().firestore();

// --- Prueba 1: A no puede leer documento de B -------------------------------
test('1  usuario A NO lee un documento de B', async () => {
  await assertFails(como(UID_A).doc('documentos_vehiculares/docB').get());
});
test('1c control: el dueño real SÍ lee su documento', async () => {
  await assertSucceeds(como(UID_B).doc('documentos_vehiculares/docB').get());
});

// --- Prueba 2: crear documento con uid ajeno --------------------------------
const nuevoDoc = (uid) => ({
  uid, vehiculo_id: 'vehA', tipo_documento: 'soap', origen_registro: 'manual',
  fecha_registro: Timestamp.now(), numero: '12345',
});
test('2  crear documento con uid de OTRO usuario falla', async () => {
  await assertFails(como(UID_A).doc('documentos_vehiculares/nuevo1').set(nuevoDoc(UID_B)));
});
test('2c control: crear con su propio uid pasa', async () => {
  await assertSucceeds(como(UID_A).doc('documentos_vehiculares/nuevo1').set(nuevoDoc(UID_A)));
});
test('2d crear documento en un vehículo AJENO falla (uid propio)', async () => {
  const d = { ...nuevoDoc(UID_A), vehiculo_id: 'vehB' };
  await assertFails(como(UID_A).doc('documentos_vehiculares/nuevo2').set(d));
});

// --- Prueba 3: admin lee todo lo que necesita el panel ----------------------
test('3  admin lee usuarios (get y list), trips y vehiculos de todos', async () => {
  const db = como(ADMIN);
  await assertSucceeds(db.doc(`usuarios/${UID_A}`).get());
  await assertSucceeds(db.collection('usuarios').get());
  await assertSucceeds(db.doc(`usuarios/${UID_A}/trips/t1`).get());
  await assertSucceeds(db.collectionGroup('trips').get());
  await assertSucceeds(db.collection('vehiculos').get());
});
test('3c control: usuario normal NO hace list de usuarios ni collectionGroup trips', async () => {
  const db = como(UID_A);
  await assertFails(db.collection('usuarios').get());
  await assertFails(db.collectionGroup('trips').get());
});

// --- Prueba 4: administradores ----------------------------------------------
test('4  usuario normal NO lee administradores/{admin}', async () => {
  await assertFails(como(UID_A).doc(`administradores/${ADMIN}`).get());
});
test('4c control: el admin SÍ lee su documento', async () => {
  await assertSucceeds(como(ADMIN).doc(`administradores/${ADMIN}`).get());
});

// --- Prueba 5: sin sesión ----------------------------------------------------
test('5  sin sesión no se lee documentos_vehiculares, vehiculos ni usuarios (get y list)', async () => {
  const db = anonimo();
  await assertFails(db.doc('documentos_vehiculares/docB').get());
  await assertFails(db.doc('vehiculos/vehA').get());
  await assertFails(db.doc(`usuarios/${UID_A}`).get());
  await assertFails(db.collection('documentos_vehiculares').get());
  await assertFails(db.collection('vehiculos').get());
  await assertFails(db.collection('usuarios').get());
});

// --- Prueba 6: creación normal de vehículo -----------------------------------
test('6a crear vehículo (flujo Mi Vehículo) pasa', async () => {
  const db = como(UID_A);
  await assertSucceeds(db.doc('vehiculos/nuevo1').set({
    id_usuario: db.doc(`usuarios/${UID_A}`), patente: 'ABCD12', marca: 'Toyota', modelo: 'Yaris',
    anio: 2020, tipo_vehiculo: 'Sedán', tipo_combustible: 'Bencina',
    kilometraje_actual: 45000, alias: 'Auto', estado: 'activo', fecha_registro: Timestamp.now(),
  }));
});
test('6b crear vehículo (flujo Fase 1) pasa', async () => {
  const db = como(UID_A);
  await assertSucceeds(db.doc('vehiculos/nuevo2').set({
    id_usuario: db.doc(`usuarios/${UID_A}`), patente: 'ABCD12', categoria: 'AUTO',
    marca: 'Toyota', fecha_ingreso: '08/10/2026',
  }));
});
test('6c crear vehículo a nombre de OTRO usuario falla', async () => {
  const db = como(UID_A);
  await assertFails(db.doc('vehiculos/nuevo3').set({
    id_usuario: db.doc(`usuarios/${UID_B}`), patente: 'ABCD12', estado: 'activo',
  }));
});

// --- Prueba 7: cambiar id_usuario ----------------------------------------------
test('7  cambiar id_usuario de su propio vehículo falla', async () => {
  const db = como(UID_A);
  await assertFails(db.doc('vehiculos/vehA').update({ id_usuario: db.doc(`usuarios/${UID_B}`) }));
});
test('7c control: cambiar solo el alias pasa', async () => {
  await assertSucceeds(como(UID_A).doc('vehiculos/vehA').update({ alias: 'Mi auto' }));
});
