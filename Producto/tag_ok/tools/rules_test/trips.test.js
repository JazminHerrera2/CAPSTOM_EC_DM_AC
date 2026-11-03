/**
 * Viajes (usuarios/{uid}/trips) contra el EMULADOR de Firestore.
 * Proyecto "demo-tag-ok": el prefijo demo- garantiza que nunca se conecta a
 * Firebase real ni toca tag-ok-v2.
 *
 * Ejecutar (desde Producto/tag_ok, para que firebase.json encuentre firestore.rules):
 *   firebase emulators:exec --only firestore --project demo-tag-ok \
 *     "node --test tools/rules_test/trips.test.js"
 *   Requiere Java y firebase-tools (y `npm install` en tools/).
 *
 * Qué prueba: las reglas que protegen lo que escribe `HistoryService.saveTrip`
 * (que hace `.collection('usuarios').doc(uid).collection('trips').add(trip.toMap())`
 * y, sin sesión, usa el uid 'anonymous'). Las reglas solo dependen de
 * `request.auth`, por eso se simula la sesión con authenticatedContext (no hace
 * falta el emulador de Auth).
 *
 * Qué NO prueba (vive en la pantalla del mapa, no en HistoryService):
 *   - filtrar los pórticos no cruzados y sumar `totalCost`
 *   - decidir qué alerta de presupuesto se muestra
 * Ver las pruebas marcadas como skip y el refactor mínimo propuesto.
 *
 * Cada assertFails tiene una gemela de control que debe pasar: si fallaran las
 * dos, el problema sería el dato y no la regla.
 */
const { test, after, beforeEach } = require('node:test');
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
const UID_A = 'uidA_dueno';
const UID_B = 'uidB_otro';

let env;
let envListo;
const iniciarEnv = () =>
  (envListo ??= initializeTestEnvironment({
    projectId: 'demo-tag-ok',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'),
    },
  }).then((e) => (env = e)));

after(async () => env && (await env.cleanup()));

beforeEach(async () => {
  await iniciarEnv();
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const uid of [UID_A, UID_B]) {
      await db.doc(`usuarios/${uid}`).set({
        email: `${uid}@example.test`,
        fecha_creacion: Timestamp.now(),
        limite_presupuesto_mensual: 50000,
      });
    }
    await db.doc(`usuarios/${UID_A}/trips/existente`).set(viaje());
  });
});

const como = (uid) => env.authenticatedContext(uid).firestore();
const anonimo = () => env.unauthenticatedContext().firestore();
const trips = (db, uid) => db.collection('usuarios').doc(uid).collection('trips');

// Mismo formato que TripHistory.toMap() (lib/data/models/trip_history.dart):
// date/timestamp en ISO-8601 (string), costos numéricos, 6 campos.
const peaje = (name, cost, hora) => ({
  name,
  cost,
  timestamp: `2026-10-15T${hora}`,
});
const viaje = (extra = {}) => ({
  date: '2026-10-15T08:00:00.000',
  totalCost: 1000,
  tolls: [peaje('PA32 Las Acacias - Lo Blanco', 400, '08:05:00.000'),
          peaje('PA28 Río Mapocho - Ruta 5 Norte', 600, '08:20:00.000')],
  distanceKm: 12.5,
  duration: '25 min',
  vehicleName: 'Hyundai (JHGK50)',
  ...extra,
});
const nPeajes = (n) =>
  Array.from({ length: n }, (_, i) => peaje(`P${i}`, 100, '08:00:00.000'));

// --- Caso 1: el dueño guarda un viaje con 2 pórticos ------------------------
// Prueba la PERSISTENCIA (lo que hace saveTrip). La suma de totalCost la hace
// la pantalla del mapa antes de llamar a saveTrip (ver caso 2, skip).
test('1  el dueño guarda un viaje con 2 pórticos y queda tal cual en usuarios/{uid}/trips', async () => {
  const ref = await assertSucceeds(trips(como(UID_A), UID_A).add(viaje()));
  const doc = await assertSucceeds(ref.get());
  const d = doc.data();
  const suma = d.tolls.reduce((s, t) => s + t.cost, 0);
  if (d.tolls.length !== 2) throw new Error(`tolls.length=${d.tolls.length}, esperaba 2`);
  if (d.totalCost !== suma || d.totalCost !== 1000) {
    throw new Error(`totalCost=${d.totalCost}, suma de pórticos=${suma}`);
  }
});

// --- Caso 2: pórticos sin cruzar ---------------------------------------------
test('2  un viaje con pórticos sin cruzar no los incluye en tolls[] ni en totalCost',
  { skip: 'La lógica (where(isCrossed) y la suma) está en línea en live_map_screen.dart, ' +
          'no en HistoryService: se necesita el refactor mínimo propuesto (TripHistory.desdePeajes).' },
  () => {});

// --- Caso 3: otro usuario no lee ni escribe los trips del primero -----------
test('3  otro usuario NO lee (get ni list) los trips de A', async () => {
  await assertFails(trips(como(UID_B), UID_A).doc('existente').get());
  await assertFails(trips(como(UID_B), UID_A).get());
});
test('3b otro usuario NO crea, edita ni borra trips de A', async () => {
  await assertFails(trips(como(UID_B), UID_A).add(viaje()));
  await assertFails(trips(como(UID_B), UID_A).doc('existente').update({ totalCost: 1 }));
  await assertFails(trips(como(UID_B), UID_A).doc('existente').delete());
});
test('3c control: el dueño SÍ lee, lista, edita y borra sus trips', async () => {
  const db = como(UID_A);
  await assertSucceeds(trips(db, UID_A).doc('existente').get());
  await assertSucceeds(trips(db, UID_A).get());
  await assertSucceeds(trips(db, UID_A).doc('existente').update({ totalCost: 2000 }));
  await assertSucceeds(trips(db, UID_A).doc('existente').delete());
});

// --- Caso 4: sin sesión -------------------------------------------------------
test('4  sin sesión la escritura es rechazada (también en usuarios/anonymous, el uid de reserva)', async () => {
  const db = anonimo();
  await assertFails(trips(db, UID_A).add(viaje()));
  // HistoryService usa 'anonymous' cuando no hay sesión: tampoco debe pasar.
  await assertFails(trips(db, 'anonymous').add(viaje()));
  await assertFails(trips(db, UID_A).get());
});
test('4c control: con sesión la misma escritura pasa', async () => {
  await assertSucceeds(trips(como(UID_A), UID_A).add(viaje()));
});
test('4d un usuario con sesión tampoco puede escribir en usuarios/anonymous', async () => {
  await assertFails(trips(como(UID_A), 'anonymous').add(viaje()));
});

// --- Caso 5: tripValido (máx. 12 campos, máx. 500 pórticos) ------------------
test('5  más de 500 pórticos es rechazado', async () => {
  await assertFails(trips(como(UID_A), UID_A).add(viaje({ tolls: nPeajes(501) })));
});
test('5c control: exactamente 500 pórticos pasa', async () => {
  await assertSucceeds(trips(como(UID_A), UID_A).add(viaje({ tolls: nPeajes(500) })));
});
test('5b más de 12 campos es rechazado', async () => {
  // viaje() trae 6 campos; con 7 extra son 13.
  const extra = Object.fromEntries(Array.from({ length: 7 }, (_, i) => [`extra${i}`, i]));
  await assertFails(trips(como(UID_A), UID_A).add(viaje(extra)));
});
test('5d control: exactamente 12 campos pasa', async () => {
  const extra = Object.fromEntries(Array.from({ length: 6 }, (_, i) => [`extra${i}`, i]));
  await assertSucceeds(trips(como(UID_A), UID_A).add(viaje(extra)));
});
test('5e la regla también aplica al editar: no se puede pasar de 500 pórticos con update', async () => {
  await assertFails(trips(como(UID_A), UID_A).doc('existente').update({ tolls: nPeajes(501) }));
});

test('5f control: editar con exactamente 500 pórticos pasa', async () => {
  await assertSucceeds(trips(como(UID_A), UID_A).doc('existente').update({ tolls: nPeajes(500) }));
});

// --- Caso 6: alerta de presupuesto -------------------------------------------
// Parte probable hoy: la persistencia que usan las alertas (límite mensual y
// "alertas_vistas", con la que HistoryService evita repetir una alerta).
test('6a el dueño actualiza limite_presupuesto_mensual y alertas_vistas (merge), como HistoryService', async () => {
  const ref = como(UID_A).doc(`usuarios/${UID_A}`);
  await assertSucceeds(ref.set({ limite_presupuesto_mensual: 80000 }, { merge: true }));
  await assertSucceeds(ref.set({ alertas_vistas: { '2026-10_50': true } }, { merge: true }));
  await assertSucceeds(ref.set({ alertas_vistas: { '2026-10_75': true } }, { merge: true }));
  const d = (await assertSucceeds(ref.get())).data();
  if (d.limite_presupuesto_mensual !== 80000) throw new Error('límite no actualizado');
  if (!d.alertas_vistas['2026-10_50'] || !d.alertas_vistas['2026-10_75']) {
    throw new Error('alertas_vistas no conservó las dos claves del mes');
  }
});
test('6b otro usuario NO puede cambiar el límite ni marcar alertas de A', async () => {
  const ref = como(UID_B).doc(`usuarios/${UID_A}`);
  await assertFails(ref.set({ limite_presupuesto_mensual: 1 }, { merge: true }));
  await assertFails(ref.set({ alertas_vistas: { '2026-10_100': true } }, { merge: true }));
});
test('6  si el gasto del mes supera limite_presupuesto_mensual se dispara la alerta',
  { skip: 'La decisión (porcentaje → umbral 50/75/90/100) está en _checkAndShowLimitAlert, un método ' +
          'privado de la pantalla del mapa que además muestra un diálogo: se necesita el refactor ' +
          'mínimo propuesto (función pura umbralDeAlerta).' },
  () => {});
