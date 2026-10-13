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
    await db.doc('mantenciones/manB').set({
      uid: UID_B, vehiculo_id: 'vehB', estado: 'realizada', tipo: 'frenos',
      origen_registro: 'manual', fecha: Timestamp.now(), kilometraje: 1000,
    });
    await db.doc('mantenciones/manA').set({
      uid: UID_A, vehiculo_id: 'vehA', estado: 'realizada', tipo: 'frenos',
      origen_registro: 'manual', fecha: Timestamp.now(), kilometraje: 1000,
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


// --- Prueba 8: mantenciones ---------------------------------------------------
const nuevaMantencion = (uid, extra = {}) => ({
  uid, vehiculo_id: 'vehA', estado: 'realizada', tipo: 'cambio_aceite',
  origen_registro: 'manual', fecha: Timestamp.now(), kilometraje: 72450,
  taller: 'Taller X', costo: 45000, descripcion: null, observaciones: null,
  tipo_otro: null, proxima_fecha: null, proximo_kilometraje: null,
  fecha_captura: null, confianza_ia: null, ...extra,
});
test('8a A NO lee una mantención de B', async () => {
  await assertFails(como(UID_A).doc('mantenciones/manB').get());
});
test('8a control: el dueño SÍ lee la suya', async () => {
  await assertSucceeds(como(UID_A).doc('mantenciones/manA').get());
});
test('8b listar sin filtro de uid falla; filtrando por uid propio pasa', async () => {
  await assertFails(como(UID_A).collection('mantenciones').get());
  await assertSucceeds(
    como(UID_A).collection('mantenciones').where('uid', '==', UID_A).where('vehiculo_id', '==', 'vehA').get());
});
test('8c sin sesión no lee ni lista', async () => {
  await assertFails(anonimo().doc('mantenciones/manA').get());
  await assertFails(anonimo().collection('mantenciones').get());
});
test('8d crear con uid de OTRO falla; con el propio pasa', async () => {
  await assertFails(como(UID_A).doc('mantenciones/n1').set(nuevaMantencion(UID_B)));
  await assertSucceeds(como(UID_A).doc('mantenciones/n1').set(nuevaMantencion(UID_A)));
});
test('8e crear en un vehículo AJENO falla', async () => {
  await assertFails(como(UID_A).doc('mantenciones/n2').set(nuevaMantencion(UID_A, { vehiculo_id: 'vehB' })));
});
test('8f campo no permitido (archivo_path) falla', async () => {
  await assertFails(como(UID_A).doc('mantenciones/n3').set(nuevaMantencion(UID_A, { archivo_path: 'x/y.jpg' })));
});
test('8g tipo inválido, costo negativo y "otra" sin texto fallan', async () => {
  const db = como(UID_A);
  await assertFails(db.doc('mantenciones/n4').set(nuevaMantencion(UID_A, { tipo: 'inventado' })));
  await assertFails(db.doc('mantenciones/n5').set(nuevaMantencion(UID_A, { costo: -1 })));
  await assertFails(db.doc('mantenciones/n6').set(nuevaMantencion(UID_A, { tipo: 'otra' })));
  await assertSucceeds(db.doc('mantenciones/n7').set(nuevaMantencion(UID_A, { tipo: 'otra', tipo_otro: 'Lavado de motor' })));
});
test('8h programada: pasa con fecha o km; sin ninguno falla', async () => {
  const base = { estado: 'programada', fecha: null, kilometraje: null };
  const db = como(UID_A);
  await assertSucceeds(db.doc('mantenciones/p1').set(nuevaMantencion(UID_A, { ...base, proxima_fecha: Timestamp.now() })));
  await assertSucceeds(db.doc('mantenciones/p2').set(nuevaMantencion(UID_A, { ...base, proximo_kilometraje: 80000 })));
  await assertFails(db.doc('mantenciones/p3').set(nuevaMantencion(UID_A, base)));
});
test('8i realizada sin fecha falla', async () => {
  await assertFails(como(UID_A).doc('mantenciones/n8').set(nuevaMantencion(UID_A, { fecha: null })));
});
test('8j actualizar uid o vehiculo_id falla; actualizar el taller pasa', async () => {
  const ref = como(UID_A).doc('mantenciones/manA');
  await assertFails(ref.update({ uid: UID_B }));
  await assertFails(ref.update({ vehiculo_id: 'vehB' }));
  await assertSucceeds(ref.update({ taller: 'Otro taller' }));
});
test('8k actualizar o borrar la de B falla; borrar la propia pasa', async () => {
  await assertFails(como(UID_A).doc('mantenciones/manB').update({ taller: 'x' }));
  await assertFails(como(UID_A).doc('mantenciones/manB').delete());
  await assertSucceeds(como(UID_A).doc('mantenciones/manA').delete());
});
