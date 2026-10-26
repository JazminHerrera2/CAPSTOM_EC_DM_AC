#!/usr/bin/env node
'use strict';

/*
 * TAG OK 2.0 - Cargador de datos de la FASE 2 a Cloud Firestore
 * ---------------------------------------------------------------------------
 * Lee EXPORTACION_BASE_DE_DATOS_FASE2.json, que usa el mismo formato que
 * EXPORTACION_BASE_DE_DATOS.json:  { "coleccion": { "idDocumento": { "datos": {...} } } }
 * Además trae dos claves reservadas:
 *   "_meta"    Qué secciones existen y qué colecciones tiene cada una.
 *   "_esquema" Campos, tipos, obligatoriedad, largos, rangos y enumeraciones
 *              (copiados de firestore.rules). El script VALIDA con esto antes de
 *              escribir, porque Firestore no valida estructura por sí solo.
 *
 * Firestore es NoSQL: no existe CREATE TABLE. Las colecciones se crean solas
 * al escribir el primer documento.
 *
 * ANTES DE CORRER ESTE SCRIPT (esto NO lo hace el script)
 *   1. La base de datos debe existir (Firebase Console > Firestore Database).
 *   2. Las reglas deben estar publicadas:
 *        firebase deploy --only firestore:rules --project tag-ok-v2
 *   3. Debe existir un usuario en Authentication (se usa su UID).
 *
 * SECCIONES
 *   base      (por defecto) administradores/{uid}: primer super_admin.
 *   catalogo  (por defecto) componentes_mantencion: catálogo de componentes.
 *   demo      (con --con-demo) vehiculos, documentos_vehiculares, mantenciones
 *             y notificaciones de ejemplo, para probar y mostrar la Fase 2.
 *
 * SEGURIDAD
 *  - Por defecto NO escribe nada: valida y muestra lo que haría. Para escribir
 *    hay que agregar --apply.
 *  - Solo escribe en el proyecto "tag-ok-v2". Si la llave de servicio es de
 *    otro proyecto (por ejemplo el antiguo "tag-ok"), se detiene.
 *  - Nunca sobrescribe: si un documento ya existe, lo omite.
 *  - Los documentos de ejemplo tienen ID "seed_..."; --clean borra solo esos.
 *    El catálogo y el administrador nunca se borran.
 *  - No crea usuarios ni contraseñas: usa un UID que YA exista.
 *  - La llave de servicio debe estar FUERA del repositorio; el script no la
 *    imprime ni la copia. El Admin SDK ignora las reglas de seguridad, por eso
 *    la validación de este script es la protección.
 *
 * USO (PowerShell, desde la carpeta del script)
 *   npm install firebase-admin
 *   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\ruta\fuera\del\repo\llave.json"
 *   $env:SEED_OWNER_UID = "<uid de un usuario existente en Authentication>"
 *   $env:SEED_ADMIN_UID = "<uid del administrador>"   # opcional
 *   node seed-firestore.js                      # valida y simula
 *   node seed-firestore.js --apply              # base + catalogo
 *   node seed-firestore.js --apply --con-demo   # agrega los datos de ejemplo
 *   node seed-firestore.js --clean --apply --con-demo   # borra solo los "seed_"
 *
 * OPCIONES
 *   --json=<archivo>             Otro archivo de datos
 *   --solo=base,catalogo,demo    Secciones exactas a procesar
 *   --con-demo                   Agrega la sección demo a las de por defecto
 *   --project=<id>               Solo para emulador (FIRESTORE_EMULATOR_HOST)
 * ---------------------------------------------------------------------------
 */

const fs = require('fs');
const path = require('path');

const EXPECTED_PROJECT = 'tag-ok-v2';
const PREFIX = 'seed_';
const NOW = new Date();

const args = process.argv.slice(2);
const has = (f) => args.includes(f);
const val = (n) => {
  const a = args.find((x) => x.startsWith('--' + n + '='));
  return a ? a.split('=').slice(1).join('=') : null;
};

// ---------------------------- carga del JSON --------------------------------
function loadJson() {
  const file = path.resolve(val('json') || path.join(__dirname, 'EXPORTACION_BASE_DE_DATOS_FASE2.json'));
  let doc;
  try {
    doc = JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (e) {
    console.error('No pude leer o interpretar el JSON: ' + file + '\n' + e.message);
    process.exit(1);
  }
  if (!doc._meta || !doc._meta.secciones || !doc._esquema) {
    console.error('El JSON debe tener las claves "_meta" (con "secciones") y "_esquema".');
    process.exit(1);
  }
  return doc;
}

function selectedSections(doc) {
  const solo = val('solo');
  const list = solo ? solo.split(',').map((s) => s.trim()).filter(Boolean) : ['base', 'catalogo'];
  if (has('--con-demo') && !list.includes('demo')) list.push('demo');
  const bad = list.filter((s) => !doc._meta.secciones[s]);
  if (bad.length) {
    console.error('Sección desconocida: ' + bad.join(', ') + '. Disponibles: ' + Object.keys(doc._meta.secciones).join(', '));
    process.exit(1);
  }
  return list;
}

// ---------------------------- marcadores ------------------------------------
function resolveString(s, ctx) {
  return s
    .split('$OWNER_UID').join(ctx.ownerUid)
    .split('$OWNER_EMAIL').join(ctx.ownerEmail)
    .split('$OWNER_NAME').join(ctx.ownerName)
    .split('$ADMIN_UID').join(ctx.adminUid || '')
    .split('$ADMIN_EMAIL').join(ctx.adminEmail);
}

// Marcadores: {"$dias":N,"h":12,"m":0}  {"$ts":"2026-10-12T10:30:00"}  {"$ref":"usuarios/$OWNER_UID"}
function resolveValue(v, ctx) {
  if (typeof v === 'string') return resolveString(v, ctx);
  if (Array.isArray(v)) return v.map((x) => resolveValue(x, ctx));
  if (v && typeof v === 'object') {
    if (Object.prototype.hasOwnProperty.call(v, '$dias')) {
      const d = new Date(NOW);
      d.setDate(d.getDate() + v.$dias);
      d.setHours(v.h === undefined ? 12 : v.h, v.m === undefined ? 0 : v.m, 0, 0);
      return { __type: 'ts', iso: d.toISOString() };
    }
    if (Object.prototype.hasOwnProperty.call(v, '$ts')) {
      const d = new Date(v.$ts);
      if (isNaN(d.getTime())) throw new Error('Fecha inválida en el JSON: ' + v.$ts);
      return { __type: 'ts', iso: d.toISOString() };
    }
    if (Object.prototype.hasOwnProperty.call(v, '$ref')) {
      return { __type: 'ref', path: resolveString(v.$ref, ctx) };
    }
    const out = {};
    for (const k of Object.keys(v)) out[k] = resolveValue(v[k], ctx);
    return out;
  }
  return v;
}

function buildEntries(doc, sections, ctx) {
  const entries = [];
  for (const s of sections) {
    for (const col of doc._meta.secciones[s]) {
      const docs = doc[col] || {};
      for (const rawId of Object.keys(docs)) {
        if (rawId.includes('$ADMIN_UID') && !ctx.adminUid) continue; // sin admin, se omite
        entries.push({
          section: s,
          col,
          id: resolveString(rawId, ctx),
          data: resolveValue(docs[rawId].datos, ctx),
        });
      }
    }
  }
  return entries;
}

// ---------------------------- validación ------------------------------------
const TYPE_CHECK = {
  string: (x) => typeof x === 'string',
  number: (x) => typeof x === 'number' && isFinite(x),
  integer: (x) => typeof x === 'number' && Number.isInteger(x),
  boolean: (x) => typeof x === 'boolean',
  timestamp: (x) => !!x && x.__type === 'ts',
  reference: (x) => !!x && x.__type === 'ref',
  list: (x) => Array.isArray(x),
};

function validate(entries, esquema) {
  const errors = [];
  const loaded = {};
  entries.forEach((e) => { (loaded[e.col] = loaded[e.col] || new Set()).add(e.id); });
  const seen = new Set();

  for (const e of entries) {
    const tag = e.col + '/' + e.id;
    if (seen.has(tag)) errors.push(tag + ': ID repetido');
    seen.add(tag);

    const sch = esquema[e.col];
    if (!sch) { errors.push(tag + ': la colección no está en el esquema'); continue; }

    for (const k of Object.keys(e.data)) {
      if (!sch.campos[k]) errors.push(tag + ': campo "' + k + '" no existe en el esquema');
    }
    for (const [campo, def] of Object.entries(sch.campos)) {
      const v = e.data[campo];
      if (v === undefined || v === null) {
        if (def.obligatorio) errors.push(tag + ': falta el campo obligatorio "' + campo + '"');
        continue;
      }
      if (!TYPE_CHECK[def.tipo] || !TYPE_CHECK[def.tipo](v)) {
        errors.push(tag + ': "' + campo + '" debe ser ' + def.tipo);
        continue;
      }
      if (def.valores && !def.valores.includes(v)) {
        errors.push(tag + ': "' + campo + '" debe ser uno de ' + def.valores.join(' | '));
      }
      if (def.min !== undefined && typeof v === 'string' && v.length < def.min) {
        errors.push(tag + ': "' + campo + '" debe tener al menos ' + def.min + ' caracteres');
      }
      if (def.max !== undefined && typeof v === 'string' && v.length > def.max) {
        errors.push(tag + ': "' + campo + '" supera ' + def.max + ' caracteres');
      }
      if (def.maxItems !== undefined && Array.isArray(v) && v.length > def.maxItems) {
        errors.push(tag + ': "' + campo + '" supera ' + def.maxItems + ' elementos');
      }
      if (def.rango && typeof v === 'number' && (v < def.rango[0] || v > def.rango[1])) {
        errors.push(tag + ': "' + campo + '" fuera de rango ' + def.rango.join(' a '));
      }
      if (def.referencia) {
        if (def.tipo === 'reference') {
          if (!v.path.startsWith(def.referencia + '/') || v.path.length <= def.referencia.length + 1) {
            errors.push(tag + ': "' + campo + '" debe apuntar a ' + def.referencia + '/{id}');
          }
        } else if (loaded[def.referencia] && !loaded[def.referencia].has(v)) {
          errors.push(tag + ': "' + campo + '" apunta a ' + def.referencia + '/' + v + ', que no está en los datos');
        }
      }
    }
    // Reglas condicionales (por ejemplo, mantenciones programadas vs realizadas)
    for (const c of sch.condiciones || []) {
      const aplica = Object.entries(c.si).every(([k, x]) => e.data[k] === x);
      if (!aplica) continue;
      for (const k of c.requiere || []) {
        if (e.data[k] === undefined || e.data[k] === null) {
          errors.push(tag + ': cuando ' + JSON.stringify(c.si) + ' se requiere "' + k + '"');
        }
      }
      if (c.alguno_de && !c.alguno_de.some((k) => e.data[k] !== undefined && e.data[k] !== null)) {
        errors.push(tag + ': cuando ' + JSON.stringify(c.si) + ' se requiere al menos uno de ' + c.alguno_de.join(', '));
      }
    }
  }
  return errors;
}

// ---------------------------- Firestore -------------------------------------
// Convierte marcadores a Timestamp / DocumentReference. "fsx" = firebase-admin/firestore.
function revive(value, fsx, db) {
  if (Array.isArray(value)) return value.map((v) => revive(v, fsx, db));
  if (value && typeof value === 'object') {
    if (value.__type === 'ts') return fsx.Timestamp.fromDate(new Date(value.iso));
    if (value.__type === 'ref') return db.doc(value.path);
    const out = {};
    for (const k of Object.keys(value)) out[k] = revive(value[k], fsx, db);
    return out;
  }
  return value;
}

function resolveProjectId(emulator) {
  if (emulator) return val('project') || EXPECTED_PROJECT;
  const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!credPath) {
    console.error('Falta GOOGLE_APPLICATION_CREDENTIALS (ruta a la llave de servicio, fuera del repo).');
    process.exit(1);
  }
  let pid;
  try {
    pid = JSON.parse(fs.readFileSync(credPath, 'utf8')).project_id;
  } catch (e) {
    console.error('No pude leer la llave de servicio en la ruta indicada.');
    process.exit(1);
  }
  if (pid !== EXPECTED_PROJECT) {
    console.error('La llave pertenece al proyecto "' + pid + '", no a "' + EXPECTED_PROJECT + '". Me detengo para no escribir en el proyecto equivocado.');
    process.exit(1);
  }
  return pid;
}

async function main() {
  const apply = has('--apply');
  const clean = has('--clean');
  const doc = loadJson();
  const sections = selectedSections(doc);
  const emulator = !!process.env.FIRESTORE_EMULATOR_HOST;
  const ownerUid = process.env.SEED_OWNER_UID || (apply ? null : 'UID_DE_PRUEBA');
  const adminUid = process.env.SEED_ADMIN_UID || null;

  if (!ownerUid) {
    console.error('Falta SEED_OWNER_UID: el UID de un usuario que YA exista en Firebase Authentication.');
    process.exit(1);
  }

  const ctx = {
    ownerUid,
    ownerEmail: 'usuario@example.com',
    ownerName: process.env.SEED_OWNER_NAME || 'Usuario de prueba',
    adminUid,
    adminEmail: 'admin@example.com',
  };
  let fsx = null;

  if (apply) {
    let appMod;
    let authMod;
    try {
      appMod = require('firebase-admin/app');
      fsx = require('firebase-admin/firestore');
      authMod = require('firebase-admin/auth');
    } catch (e) {
      console.error('Falta el paquete firebase-admin. Ejecuta: npm install firebase-admin');
      process.exit(1);
    }
    const projectId = resolveProjectId(emulator);
    appMod.initializeApp(emulator
      ? { projectId }
      : { projectId, credential: appMod.applicationDefault() });
    console.log('Proyecto: ' + projectId + (emulator ? ' (emulador)' : ''));

    if (!emulator) {
      const check = async (uid, label) => {
        try {
          return await authMod.getAuth().getUser(uid);
        } catch (e) {
          console.error(label + ': el UID ' + uid + ' no existe en Authentication.');
          process.exit(1);
        }
      };
      const owner = await check(ownerUid, 'SEED_OWNER_UID');
      ctx.ownerEmail = owner.email || ctx.ownerEmail;
      ctx.ownerName = process.env.SEED_OWNER_NAME || owner.displayName || ctx.ownerName;
      console.log('Dueño de los datos: ' + (owner.email || ownerUid));
      if (adminUid) {
        const adm = await check(adminUid, 'SEED_ADMIN_UID');
        ctx.adminEmail = adm.email || ctx.adminEmail;
      }
    }
  } else {
    console.log('MODO SIMULACIÓN: no se escribe nada. Usa --apply para escribir.');
  }

  const entries = buildEntries(doc, sections, ctx);
  console.log('Secciones: ' + sections.join(', ') + ' | documentos: ' + entries.length);

  const errors = validate(entries, doc._esquema);
  if (errors.length) {
    console.error('\nLa validación contra el esquema encontró ' + errors.length + ' problema(s):');
    errors.slice(0, 40).forEach((m) => console.error('  - ' + m));
    process.exit(1);
  }
  console.log('Validación contra el esquema: OK (campos obligatorios, tipos, largos, rangos, enumeraciones y referencias).');

  if (clean) {
    const toDelete = entries.filter((e) => e.id.startsWith(PREFIX));
    console.log('Se borrarían ' + toDelete.length + ' documentos "seed_" (el catálogo y el administrador no se tocan).');
    if (!apply) {
      toDelete.forEach((e) => console.log('  - ' + e.col + '/' + e.id));
      return;
    }
    const db = fsx.getFirestore();
    for (const e of toDelete) {
      await db.collection(e.col).doc(e.id).delete();
      console.log('  borrado ' + e.col + '/' + e.id);
    }
    console.log('Listo.');
    return;
  }

  if (!apply) {
    const porColeccion = {};
    entries.forEach((e) => { porColeccion[e.col] = (porColeccion[e.col] || 0) + 1; });
    Object.keys(porColeccion).forEach((c) => console.log('  ' + c + ': ' + porColeccion[c]));
    return;
  }

  const db = fsx.getFirestore();
  let created = 0;
  let skipped = 0;
  for (const e of entries) {
    try {
      await db.collection(e.col).doc(e.id).create(revive(e.data, fsx, db));
      created++;
      console.log('  creado   ' + e.col + '/' + e.id);
    } catch (err) {
      if (err && (err.code === 6 || /ALREADY_EXISTS/.test(String(err.message)))) {
        skipped++;
        console.log('  omitido  ' + e.col + '/' + e.id + ' (ya existe)');
      } else if (err && (err.code === 5 || /NOT_FOUND/.test(String(err.message)))) {
        console.error('\nFirestore no encuentra la base de datos. Créala en Firebase Console > Firestore Database y vuelve a correr el script.');
        process.exit(1);
      } else {
        console.error('  ERROR en ' + e.col + '/' + e.id + ': ' + (err && err.message));
        process.exit(1);
      }
    }
  }
  console.log('\nListo. Creados: ' + created + ' | Omitidos (ya existían): ' + skipped);
  console.log('Las demás colecciones se crean solas cuando la app guarda el primer dato.');
}

module.exports = { main, validate, resolveValue, buildEntries, revive };

if (require.main === module) {
  main().catch((e) => {
    console.error(e && e.message ? e.message : e);
    process.exit(1);
  });
}
