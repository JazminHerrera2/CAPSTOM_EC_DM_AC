/**
 * Pobla con datos de prueba el EMULADOR de Firebase (Auth + Firestore) con las
 * colecciones que la app usa hoy, en el mismo formato en que la app las guarda.
 *
 * SEGURIDAD: solo funciona contra el emulador local y el proyecto ficticio
 * "demo-tag-ok". Nunca se conecta a tag-ok-v2 ni a ningún proyecto real: si
 * detecta otro proyecto u otro host, se detiene sin escribir nada.
 *
 * Uso (desde Producto/tag_ok/tools/poblar_bd, con `npm install` hecho en tools/):
 *   firebase emulators:start --project demo-tag-ok      (terminal 1)
 *   node poblar_bd.js                                    (terminal 2)
 * Ver los datos en http://127.0.0.1:4000 (Emulator UI). Más detalle en README.md.
 *
 * Cada ejecución BORRA los datos del emulador y vuelve a crearlos, así el
 * resultado es siempre el mismo.
 *
 * Colecciones que crea: usuarios (+ subcolecciones trips y audited_invoices),
 * vehiculos, documentos_vehiculares, mantenciones, notificaciones, auditoria,
 * administradores y porticos. No crea estacionamientos, abastecimientos ni
 * beneficios (módulos aún no implementados) ni tarifas (ningún código la
 * escribe). Todos los datos son ficticios, salvo los pórticos, que son datos
 * públicos de las autopistas tomados de Base de datos/EXPORTACION_BASE_DE_DATOS.json.
 */

const path = require('node:path');
const fs = require('node:fs');

// --- Seguridad: forzar emulador y proyecto demo ANTES de inicializar Firebase.
const PROJECT_ID = 'demo-tag-ok';
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';

function esLocal(host) {
  return /^(127\.0\.0\.1|localhost|\[::1\]):\d+$/.test(host);
}
for (const variable of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST']) {
  if (!esLocal(process.env[variable])) {
    console.error(`Detenido: ${variable}=${process.env[variable]} no es un emulador local.`);
    process.exit(1);
  }
}
const proyectoEnv = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
if (proyectoEnv && !proyectoEnv.startsWith('demo-')) {
  console.error(`Detenido: el proyecto "${proyectoEnv}" no es un proyecto demo.`);
  process.exit(1);
}

const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

initializeApp({ projectId: PROJECT_ID });
const db = getFirestore();

/**
 * Crea una cuenta en el emulador de Authentication con un uid fijo, usando su
 * API REST (la misma que usa firebase-admin). Se evita el módulo
 * firebase-admin/auth porque en Node 22.0.0 no carga (depende de un módulo ESM).
 */
async function crearCuenta({ uid, email, nombre }) {
  const r = await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}/accounts`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer owner' },
      body: JSON.stringify({ localId: uid, email, password: CONTRASENA_DEMO, displayName: nombre }),
    });
  if (!r.ok) throw new Error(`No se pudo crear la cuenta ${email}: ${await r.text()}`);
}

// --- Utilidades de fechas (relativas al día en que se ejecuta el script) ---
const HOY = new Date();
HOY.setHours(0, 0, 0, 0);

/** Fecha a medianoche local, desplazada [n] días desde hoy. */
function dia(n) {
  const d = new Date(HOY);
  d.setDate(d.getDate() + n);
  return d;
}
const ts = (fecha) => Timestamp.fromDate(fecha);

/** Fecha ISO local sin zona horaria ("2026-10-20T08:15:00"), como trips. */
function isoLocal(fecha) {
  const p = (x) => String(x).padStart(2, '0');
  return `${fecha.getFullYear()}-${p(fecha.getMonth() + 1)}-${p(fecha.getDate())}` +
    `T${p(fecha.getHours())}:${p(fecha.getMinutes())}:${p(fecha.getSeconds())}`;
}

// --- Etiquetas (las mismas que muestra la app) ---
const ETIQUETA_DOCUMENTO = {
  permiso_circulacion: 'Permiso de Circulación',
  revision_tecnica: 'Revisión Técnica',
  soap: 'SOAP',
  seguro: 'Seguro Automotriz',
};
const ETIQUETA_MANTENCION = {
  cambio_aceite: 'Cambio de aceite',
  revision_general: 'Revisión general',
  cambio_filtros: 'Cambio de filtros',
  frenos: 'Frenos',
  neumaticos: 'Neumáticos',
  alineacion_balanceo: 'Alineación y balanceo',
  bateria: 'Batería',
  sistema_electrico: 'Sistema eléctrico',
  motor: 'Motor',
  preventiva: 'Preventiva',
  otra: 'Otra',
};

// --- Usuarios ficticios (uid de 28 caracteres, como Firebase Authentication) ---
const CONTRASENA_DEMO = 'Demo1234!';
const USUARIOS = [
  { uid: 'Ab12Cd34Ef56Gh78Ij90Kl12Mn34', email: 'camila.rojas@example.com', nombre: 'Camila Rojas', limite: 60000 },
  { uid: 'Op56Qr78St90Uv12Wx34Yz56Ab78', email: 'matias.soto@example.com', nombre: 'Matías Soto', limite: 40000 },
];
const ADMIN = { uid: 'Ad90Mn12Bv34Cx56Zl78Kj90Hg12', email: 'admin.tagok@example.com', nombre: 'Administración TAG OK' };
for (const u of [...USUARIOS, ADMIN]) {
  if (u.uid.length !== 28) throw new Error(`uid de ${u.email} debe tener 28 caracteres`);
}
const [CAMILA, MATIAS] = USUARIOS;

// --- Vehículos ---
const VEHICULOS = [
  { clave: 'yaris', dueno: CAMILA, patente: 'KXLR45', marca: 'Toyota', modelo: 'Yaris', anio: 2019,
    tipo_vehiculo: 'AUTO', tipo_combustible: 'Bencina', kilometraje_actual: 64500, alias: 'Mi Yaris', registro: -150 },
  { clave: 'cx5', dueno: CAMILA, patente: 'HJKL21', marca: 'Mazda', modelo: 'CX-5', anio: 2022,
    tipo_vehiculo: 'CAMIONETA', tipo_combustible: 'Bencina', kilometraje_actual: 31000, alias: null, registro: -90 },
  { clave: 'accent', dueno: MATIAS, patente: 'PRTB88', marca: 'Hyundai', modelo: 'Accent', anio: 2018,
    tipo_vehiculo: 'AUTO', tipo_combustible: 'Bencina', kilometraje_actual: 98000, alias: 'El Accent', registro: -60 },
];

// --- Documentos vehiculares (vencimientos relativos a hoy) ---
const DOCUMENTOS = [
  { vehiculo: 'yaris', tipo: 'permiso_circulacion', numero: 'PC-2026-118204', emision: -345, vence: 20,
    compania: 'Municipalidad de Ñuñoa', poliza: null, origen: 'ia' },
  { vehiculo: 'yaris', tipo: 'soap', numero: 'SOAP-2026-004589', emision: -320, vence: 45,
    compania: 'HDI Seguros', poliza: null, origen: 'manual' },
  { vehiculo: 'yaris', tipo: 'revision_tecnica', numero: 'B134800000067871', emision: -165, vence: 200,
    compania: 'Planta Revisión Técnica Los Leones', poliza: null, origen: 'ia' },
  { vehiculo: 'yaris', tipo: 'seguro', numero: null, emision: -245, vence: 120,
    compania: 'Seguros Ejemplo', poliza: 'POL-984512', origen: 'manual' },
  { vehiculo: 'cx5', tipo: 'soap', numero: 'SOAP-2025-007712', emision: -370, vence: -5,
    compania: 'Seguros Ejemplo', poliza: null, origen: 'manual' },
  { vehiculo: 'cx5', tipo: 'permiso_circulacion', numero: 'PC-2026-220871', emision: -65, vence: 300,
    compania: 'Municipalidad de Providencia', poliza: null, origen: 'manual' },
  { vehiculo: 'accent', tipo: 'revision_tecnica', numero: 'B134800000091230', emision: -355, vence: 10,
    compania: 'Planta Revisión Técnica Maipú', poliza: null, origen: 'ia' },
  { vehiculo: 'accent', tipo: 'soap', numero: 'SOAP-2026-010233', emision: -300, vence: 60,
    compania: 'HDI Seguros', poliza: null, origen: 'manual' },
];

// --- Mantenciones (realizadas y programadas) ---
const MANTENCIONES = [
  { vehiculo: 'yaris', estado: 'realizada', tipo: 'cambio_aceite', fecha: -90, km: 60000,
    taller: 'Lubricentro Los Leones', costo: 45000, descripcion: 'Aceite 5W-30 sintético y filtro de aceite',
    observaciones: 'Próximo cambio a los 70.000 km', comprobante: ['boleta', '458123'], origen: 'ia' },
  { vehiculo: 'yaris', estado: 'realizada', tipo: 'otra', tipo_otro: 'Cambio de parabrisas', fecha: -60, km: 62000,
    taller: 'Vidrios Automotrices Sur', costo: 150000, descripcion: 'Reemplazo de parabrisas delantero',
    observaciones: null, comprobante: ['otro', null], origen: 'manual' },
  { vehiculo: 'yaris', estado: 'realizada', tipo: 'frenos', fecha: -30, km: 63800,
    taller: 'Frenos Express Ñuñoa', costo: 89990, descripcion: 'Pastillas delanteras y rectificado de discos',
    observaciones: null, comprobante: ['factura', '10234'], origen: 'ia' },
  { vehiculo: 'yaris', estado: 'programada', tipo: 'revision_general', proxima_fecha: 7, origen: 'manual' },
  { vehiculo: 'yaris', estado: 'programada', tipo: 'cambio_aceite', proximo_km: 70000, origen: 'manual' },
  { vehiculo: 'cx5', estado: 'realizada', tipo: 'neumaticos', fecha: -120, km: 28000,
    taller: 'Neumáticos del Sur', costo: 380000, descripcion: 'Cambio de 4 neumáticos',
    observaciones: 'Pagado por transferencia, sin boleta', comprobante: [null, null], origen: 'manual' },
  { vehiculo: 'cx5', estado: 'programada', tipo: 'preventiva', proxima_fecha: 40, proximo_km: 35000, origen: 'manual' },
  { vehiculo: 'accent', estado: 'realizada', tipo: 'bateria', fecha: -15, km: 97500,
    taller: 'Baterías Express', costo: 79990, descripcion: 'Batería 12V 60Ah',
    observaciones: null, comprobante: ['boleta', '77801'], origen: 'manual' },
  { vehiculo: 'accent', estado: 'programada', tipo: 'alineacion_balanceo', proxima_fecha: 2, origen: 'manual' },
];

// --- Escritura en lotes ---
const lotes = [];
let loteActual = db.batch();
let opsEnLote = 0;
function escribir(ref, datos) {
  loteActual.set(ref, datos);
  if (++opsEnLote === 400) {
    lotes.push(loteActual);
    loteActual = db.batch();
    opsEnLote = 0;
  }
}
async function confirmarLotes() {
  if (opsEnLote > 0) lotes.push(loteActual);
  for (const lote of lotes) await lote.commit();
}

const resumen = {};
const contar = (coleccion) => { resumen[coleccion] = (resumen[coleccion] || 0) + 1; };

/** Crea los avisos de un registro igual que NotificacionService: los de días ya pasados no se crean. */
function crearAvisos({ usuarioId, vehiculoId, tipo, referenciaId, avisos }) {
  for (const aviso of avisos) {
    if (aviso.fecha < HOY) continue;
    escribir(db.doc(`notificaciones/${aviso.id}`), {
      usuario_id: usuarioId,
      vehiculo_id: vehiculoId,
      tipo,
      referencia_id: referenciaId,
      mensaje: aviso.mensaje,
      fecha_programada: ts(aviso.fecha),
      fecha_generacion: Timestamp.now(),
      leida: false,
      estado: 'pendiente',
    });
    contar('notificaciones');
  }
}

async function limpiarEmulador() {
  const fsHost = process.env.FIRESTORE_EMULATOR_HOST;
  const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const r1 = await fetch(
    `http://${fsHost}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: 'DELETE' });
  const r2 = await fetch(
    `http://${authHost}/emulator/v1/projects/${PROJECT_ID}/accounts`,
    { method: 'DELETE' });
  if (!r1.ok || !r2.ok) throw new Error('No se pudo limpiar el emulador');
}

async function main() {
  try {
    await limpiarEmulador();
  } catch (e) {
    console.error('No se pudo conectar con el emulador. ¿Está corriendo "firebase emulators:start --project demo-tag-ok"?');
    console.error(e.message);
    process.exit(1);
  }

  // 1. Cuentas (Authentication) y documentos de usuarios / administradores.
  for (const u of [...USUARIOS, ADMIN]) {
    await crearCuenta(u);
  }
  for (const u of USUARIOS) {
    const principal = VEHICULOS.find((v) => v.dueno === u);
    escribir(db.doc(`usuarios/${u.uid}`), {
      email: u.email,
      nombre_mostrar: u.nombre,
      fecha_creacion: ts(dia(-180)),
      vehiculo_principal_id: principal ? principal.patente : null,
      limite_presupuesto_mensual: u.limite,
      notif_cobros: true,
      notif_presupuesto: true,
    });
    contar('usuarios');
  }
  escribir(db.doc(`administradores/${ADMIN.uid}`), {
    email: ADMIN.email,
    rol: 'super_admin',
    fecha_creacion: ts(dia(-200)),
  });
  contar('administradores');

  // 2. Vehículos (id_usuario es una referencia a usuarios/{uid}, como en la app).
  const idVehiculo = {};
  for (const v of VEHICULOS) {
    const ref = db.collection('vehiculos').doc();
    idVehiculo[v.clave] = ref.id;
    const datos = {
      id_usuario: db.doc(`usuarios/${v.dueno.uid}`),
      patente: v.patente,
      marca: v.marca,
      modelo: v.modelo,
      anio: v.anio,
      tipo_vehiculo: v.tipo_vehiculo,
      tipo_combustible: v.tipo_combustible,
      kilometraje_actual: v.kilometraje_actual,
      estado: 'activo',
      fecha_registro: ts(dia(v.registro)),
    };
    if (v.alias) datos.alias = v.alias;
    escribir(ref, datos);
    contar('vehiculos');
  }
  const vehiculoPorClave = Object.fromEntries(VEHICULOS.map((v) => [v.clave, v]));

  // 3. Documentos vehiculares + avisos de vencimiento (30, 15 y 7 días) + auditoría.
  for (const d of DOCUMENTOS) {
    const v = vehiculoPorClave[d.vehiculo];
    const ref = db.collection('documentos_vehiculares').doc();
    const registro = dia(d.emision + 2);
    const vence = dia(d.vence);
    escribir(ref, {
      uid: v.dueno.uid,
      vehiculo_id: idVehiculo[d.vehiculo],
      tipo_documento: d.tipo,
      numero: d.numero,
      fecha_emision: ts(dia(d.emision)),
      fecha_vencimiento: ts(vence),
      compania: d.compania,
      numero_poliza: d.poliza,
      archivo_path: null, // el emulador no incluye Supabase Storage
      origen_registro: d.origen,
      fecha_captura: d.origen === 'ia' ? ts(registro) : null,
      confianza_ia: null, // la app aún no calcula este valor
      fecha_registro: ts(registro),
    });
    contar('documentos_vehiculares');

    const etiqueta = ETIQUETA_DOCUMENTO[d.tipo];
    crearAvisos({
      usuarioId: v.dueno.uid,
      vehiculoId: idVehiculo[d.vehiculo],
      tipo: 'vencimiento_documento',
      referenciaId: ref.id,
      avisos: [30, 15, 7].map((n) => ({
        id: `${ref.id}_${n}dias`,
        fecha: dia(d.vence - n),
        mensaje: `Recordatorio: ${etiqueta} vence en ${n} días.`,
      })),
    });

    escribir(db.collection('auditoria').doc(), {
      usuario_id: v.dueno.uid,
      accion: 'CREAR',
      tipo_entidad: 'DOCUMENTO_VEHICULAR',
      entidad_id: ref.id,
      detalle: d.origen === 'ia'
        ? 'Documento confirmado después de revisión (Registro Inteligente)'
        : 'Documento registrado manualmente',
      origen: d.origen,
      fecha: ts(registro),
    });
    contar('auditoria');
  }

  // 4. Mantenciones + recordatorios de las programadas con fecha (7 días antes y el mismo día).
  //    (La app todavía no registra auditoría de mantenciones, así que no se crea.)
  for (const m of MANTENCIONES) {
    const v = vehiculoPorClave[m.vehiculo];
    const ref = db.collection('mantenciones').doc();
    const realizada = m.estado === 'realizada';
    const [tipoComprobante, numeroComprobante] = m.comprobante || [null, null];
    const proximaFecha = m.proxima_fecha != null ? dia(m.proxima_fecha) : null;
    escribir(ref, {
      uid: v.dueno.uid,
      vehiculo_id: idVehiculo[m.vehiculo],
      estado: m.estado,
      fecha: realizada ? ts(dia(m.fecha)) : null,
      kilometraje: m.km ?? null,
      tipo: m.tipo,
      tipo_otro: m.tipo_otro ?? null,
      taller: m.taller ?? null,
      costo: m.costo ?? null,
      descripcion: m.descripcion ?? null,
      observaciones: m.observaciones ?? null,
      proxima_fecha: proximaFecha ? ts(proximaFecha) : null,
      proximo_kilometraje: m.proximo_km ?? null,
      tipo_comprobante: tipoComprobante,
      numero_comprobante: numeroComprobante,
      origen_registro: m.origen,
      fecha_captura: m.origen === 'ia' ? ts(dia(m.fecha)) : null,
      confianza_ia: null,
    });
    contar('mantenciones');

    if (!realizada && proximaFecha) {
      const nombre = m.tipo === 'otra' && m.tipo_otro ? m.tipo_otro : ETIQUETA_MANTENCION[m.tipo];
      const que = `${nombre} (${v.patente})`;
      crearAvisos({
        usuarioId: v.dueno.uid,
        vehiculoId: idVehiculo[m.vehiculo],
        tipo: 'mantencion_programada',
        referenciaId: ref.id,
        avisos: [
          { id: `${ref.id}_7dias`, fecha: dia(m.proxima_fecha - 7), mensaje: `Mantención programada en 7 días: ${que}.` },
          { id: `${ref.id}_dia`, fecha: proximaFecha, mensaje: `Hoy tienes una mantención programada: ${que}.` },
        ],
      });
    }
  }

  // 5. Auditoría: un vehículo eliminado (app) y acciones del panel admin.
  escribir(db.collection('auditoria').doc(), {
    usuario_id: MATIAS.uid,
    accion: 'ELIMINAR',
    tipo_entidad: 'VEHICULO',
    entidad_id: db.collection('vehiculos').doc().id,
    detalle: 'Vehículo eliminado (ZZXY99)',
    origen: 'manual',
    fecha: ts(dia(-20)),
  });
  contar('auditoria');
  for (const a of [
    { action: 'CREATE_ADMIN', target: ADMIN.email, details: 'Cuenta de administración creada.', fecha: -200 },
    { action: 'EDIT_USER', target: CAMILA.nombre, details: 'Presupuesto: $50.000 -> $60.000.', fecha: -10 },
  ]) {
    escribir(db.collection('auditoria').doc(), {
      adminEmail: ADMIN.email,
      action: a.action,
      target: a.target,
      details: a.details,
      fecha: ts(dia(a.fecha)),
    });
    contar('auditoria');
  }

  // 6. Pórticos (datos públicos de las autopistas, formato real con el mapa "datos").
  const exportacion = path.join(__dirname, '../../../Base de datos/EXPORTACION_BASE_DE_DATOS.json');
  const porticos = JSON.parse(fs.readFileSync(exportacion, 'utf8')).porticos;
  for (const [id, doc] of Object.entries(porticos)) {
    escribir(db.doc(`porticos/${id}`), doc);
    contar('porticos');
  }
  const listaPorticos = Object.values(porticos).map((p) => p.datos);

  // 7. Viajes TAG de Camila (subcolección trips, formato de Fase 1) y una factura auditada.
  const viajes = [];
  for (const [diasAtras, hora, distancia, duracion, indices] of [
    [-12, 8, 24.6, '38 min', [0, 5, 9]],
    [-9, 18, 19.2, '29 min', [12, 20]],
    [-5, 7, 31.0, '45 min', [3, 7, 15, 30]],
    [-2, 19, 12.4, '21 min', [40, 41]],
  ]) {
    const inicio = dia(diasAtras);
    inicio.setHours(hora, 10, 0);
    const tolls = indices.map((i, n) => {
      const p = listaPorticos[i % listaPorticos.length];
      const cruce = new Date(inicio.getTime() + n * 6 * 60000);
      return { name: p.nombre, cost: p.tarifa_base, timestamp: isoLocal(cruce) };
    });
    const totalCost = Math.round(tolls.reduce((s, t) => s + t.cost, 0) * 100) / 100;
    viajes.push({ inicio, tolls });
    escribir(db.collection(`usuarios/${CAMILA.uid}/trips`).doc(), {
      date: isoLocal(inicio),
      totalCost,
      distanceKm: distancia,
      duration: duracion,
      vehicleName: 'Toyota (KXLR45)',
      tolls,
    });
    contar('usuarios/{uid}/trips');
  }

  const cruces = viajes.flatMap((v) => v.tolls);
  const meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
  const totalFacturado = Math.round(cruces.reduce((s, c) => s + c.cost, 0) * 100) / 100;
  escribir(db.collection(`usuarios/${CAMILA.uid}/audited_invoices`).doc(), {
    concessionaire: 'Costanera Norte',
    period: `${meses[HOY.getMonth()]} ${HOY.getFullYear()}`,
    patent: 'KXLR45',
    totalBilled: totalFacturado,
    totalMatched: totalFacturado,
    status: 'Conciliado',
    reconciliationRate: 100,
    uploadDate: isoLocal(new Date()),
    details: cruces.map((c) => ({
      date: c.timestamp.slice(0, 10),
      time: c.timestamp.slice(11, 16),
      portico: c.name,
      cost: c.cost,
      status: 'Correcto',
    })),
    aiReport: '### ¡Conciliación Perfecta! 🛡️\n\nTodos los cobros de la factura coinciden con los viajes registrados.',
    auditedBy: 'OpenAI',
  });
  contar('usuarios/{uid}/audited_invoices');

  await confirmarLotes();

  console.log('Emulador poblado (proyecto demo-tag-ok):');
  console.log(`  Authentication: ${USUARIOS.length + 1} cuentas (contraseña de todas: ${CONTRASENA_DEMO})`);
  for (const [coleccion, n] of Object.entries(resumen)) {
    console.log(`  ${coleccion}: ${n}`);
  }
}

main().catch((e) => {
  console.error('Error al poblar el emulador:', e);
  process.exit(1);
});
