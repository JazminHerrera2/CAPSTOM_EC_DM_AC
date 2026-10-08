/**
 * Verifica que cada documento de administradores/{id} tenga como ID el uid
 * real de una cuenta de Firebase Auth. SOLO LECTURA: no escribe nada ni en
 * Firestore ni en Auth.
 *
 * Uso (desde Producto/tag_ok/tools, mismo entorno que el backfill):
 *   set GOOGLE_APPLICATION_CREDENTIALS=C:\ruta\fuera-del-repo\service-account.json
 *   node verificar_admins.js
 *
 * El resultado se imprime SOLO en la consola (incluye uids y emails de
 * administradores): no lo guardes dentro del repo.
 *
 * Estados:
 *   OK            el id del documento es el uid de una cuenta existente
 *   ID_INCORRECTO el id NO es un uid, pero el email del documento sí
 *                 pertenece a una cuenta (se muestra el uid correcto)
 *   SIN_CUENTA    ni el id ni el email corresponden a una cuenta de Auth
 *   SIN_EMAIL     el id no es un uid y el documento no tiene campo email
 *   EMAIL_DISTINTO el id es un uid válido, pero el email del documento no
 *                 coincide con el de la cuenta (revisar a mano)
 */
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

const PROJECT_ID = 'tag-ok-v2';

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();
const auth = getAuth();

async function buscarCuenta(uid) {
  try {
    return await auth.getUser(uid);
  } catch (e) {
    if (e.code === 'auth/user-not-found' || e.code === 'auth/invalid-uid') return null;
    throw e;
  }
}

async function buscarPorEmail(email) {
  try {
    return await auth.getUserByEmail(email);
  } catch (e) {
    if (e.code === 'auth/user-not-found' || e.code === 'auth/invalid-email') return null;
    throw e;
  }
}

async function main() {
  console.log(`Proyecto: ${PROJECT_ID} | SOLO LECTURA\n`);
  const snap = await db.collection('administradores').get();
  console.log(`Documentos en administradores: ${snap.size}\n`);

  const filas = [];
  for (const doc of snap.docs) {
    const data = doc.data();
    const emailDoc = typeof data.email === 'string' ? data.email.trim() : null;
    const rol = data.rol ?? data.role ?? '(sin rol)';
    const cuenta = await buscarCuenta(doc.id);

    let estado, detalle = '';
    if (cuenta) {
      const mismo = !emailDoc || (cuenta.email || '').toLowerCase() === emailDoc.toLowerCase();
      estado = mismo ? 'OK' : 'EMAIL_DISTINTO';
      detalle = mismo ? '' : `email de la cuenta: ${cuenta.email}`;
    } else if (emailDoc) {
      const porEmail = await buscarPorEmail(emailDoc);
      if (porEmail) {
        estado = 'ID_INCORRECTO';
        detalle = `uid correcto: ${porEmail.uid}`;
      } else {
        estado = 'SIN_CUENTA';
      }
    } else {
      estado = 'SIN_EMAIL';
    }
    filas.push({ estado, id: doc.id, email: emailDoc ?? '(sin email)', rol: String(rol), detalle });
  }

  for (const f of filas) {
    console.log(`[${f.estado}] id=${f.id} | email=${f.email} | rol=${f.rol}${f.detalle ? ' | ' + f.detalle : ''}`);
  }

  const resumen = {};
  for (const f of filas) resumen[f.estado] = (resumen[f.estado] || 0) + 1;
  console.log('\nResumen:', resumen);
  console.log('Solo los [OK] funcionarán como admin con las reglas nuevas.');
}

main().catch((e) => { console.error(e); process.exit(1); });
