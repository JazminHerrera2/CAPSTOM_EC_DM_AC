'use strict';
/**
 * TAG OK – Fase 2
 * Datos de ejemplo para poblar Cloud Firestore.
 *
 * Todo es ficticio. Sigue el "Diccionario de datos" y las "Descripciones de las
 * colecciones": mismos nombres de campos, mismos valores permitidos y mismas
 * relaciones (uid, vehiculo_id, referencia_id, autopista_codigo, etc.).
 *
 * Este archivo NO se conecta a Firebase: solo construye la lista de documentos.
 * Los tipos que JSON no tiene se marcan así y los convierte poblar_firestore.js:
 *   { __geo: [lat, lng] }   -> GeoPoint
 *   { __ref: 'ruta/doc' }   -> DocumentReference
 * Las fechas son objetos Date (Firestore las guarda como Timestamp).
 */

// ---------------------------------------------------------------- utilidades
const d = (ymd, hm = '00:00') => new Date(`${ymd}T${hm}:00-03:00`); // hora de Chile (verano)
const addDays = (date, n) => new Date(date.getTime() + n * 86400000);
const GEO = (lat, lng) => ({ __geo: [lat, lng] });
const REF = (path) => ({ __ref: path });
const pad = (n) => String(n).padStart(2, '0');
// fecha ISO local, sin zona, como la guarda la Fase 1 (ej. 2026-10-01T12:18:29.200)
const isoLocal = (ymd, hm, addMin = 0) => {
  const t = new Date(`${ymd}T${hm}:00.000Z`).getTime() + addMin * 60000;
  return new Date(t).toISOString().slice(0, 23);
};

const docs = []; // { path, data }
const add = (path, data) => docs.push({ path, data });

// ------------------------------------------------------------------- usuarios
const U1 = 'kZ3pQ9xYv2LmN8rT4bW6cH1dF7gJ';
const U2 = 'mT7vB2nXq9LrK4eD8sW1yH5cZ3aP';
const U3 = 'jS5hN8wQ3zXc7VbL2kR9tY4mD6fG';
const ADMIN_SUPER = 'Sa9Xk3Lm7Qt2Vb5Nr8Cw1Pz4Yh6J';
const ADMIN_OPER = 'Ad7Kq2Lm9Rt4Vb1Nx8Cw3Pz6Yh5J';

const usuarios = [
  {
    uid: U1,
    data: {
      email: 'camila.rojas@example.com',
      nombre_mostrar: 'Camila Rojas',
      fecha_creacion: d('2026-09-15', '10:24'),
      vehiculo_principal_id: 'KRTP45',
      limite_presupuesto_mensual: 50000,
      notif_cobros: true,
      notif_presupuesto: false,
      alertas_vistas: { '2026-11_80': true },
    },
  },
  {
    uid: U2,
    data: {
      email: 'matias.fuentes@example.com',
      nombre_mostrar: 'Matías Fuentes',
      fecha_creacion: d('2026-09-20', '18:05'),
      vehiculo_principal_id: 'LGFM17',
      limite_presupuesto_mensual: 80000,
      // sin notif_cobros / notif_presupuesto: la alerta está activada por defecto
    },
  },
  {
    uid: U3,
    data: {
      email: 'javiera.soto@example.com',
      // sin nombre_mostrar: se registró con correo
      fecha_creacion: d('2026-10-02', '09:12'),
      vehiculo_principal_id: 'SWTN26',
      limite_presupuesto_mensual: 50000,
      notif_cobros: false,
    },
  },
];
usuarios.forEach((u) => add(`usuarios/${u.uid}`, u.data));
const emailDe = Object.fromEntries(usuarios.map((u) => [u.uid, u.data.email]));

// -------------------------------------------------------------- administradores
const ADMIN_SUPER_EMAIL = 'superadmin@example.com';
const ADMIN_OPER_EMAIL = 'admin@example.com';
add(`administradores/${ADMIN_SUPER}`, { email: ADMIN_SUPER_EMAIL, rol: 'super_admin' }); // el primero no tiene fecha_creacion
add(`administradores/${ADMIN_OPER}`, {
  email: ADMIN_OPER_EMAIL,
  rol: 'operador',
  fecha_creacion: d('2026-11-18', '00:20'),
});

// ------------------------------------------------------------- concesionarias
const CONC = {
  autopista_central: { nombre: 'Autopista Central', codigo: 'AC' },
  costanera_norte: { nombre: 'Costanera Norte', codigo: 'CN' },
  vespucio_sur: { nombre: 'Vespucio Sur', codigo: 'VS' },
  vespucio_norte: { nombre: 'Vespucio Norte', codigo: 'VN' },
};
Object.entries(CONC).forEach(([id, c]) => add(`concesionarias/${id}`, { nombre: c.nombre, codigo: c.codigo }));

// ------------------------------------------------------------------- porticos
// [id, formato, concesionaria, codigo, nombre, sentido, lat, lng, base, punta, saturacion, grupo, secuencia]
// formato 'ini'  = carga inicial de la Fase 1 (id numérico, costo/costoPunta/..., grupo, secuencia)
// formato 'panel' = panel admin (id "{concesionaria}_{codigo}", codigo, autopista_codigo, tarifa_*)
const PORT = [
  ['11', 'ini', 'autopista_central', null, 'PA7 Las Acacias - A. Vespucio', 'S-N', -33.5512, -70.6889, 452.06, 904.14, 904.14, 'Norte-Sur', 7],
  ['12', 'ini', 'autopista_central', null, 'PA32 Las Acacias - Lo Blanco', 'N-S', -33.5130, -70.6780, 176.67, 353.34, 353.34, 'Norte-Sur', 32],
  ['21', 'ini', 'costanera_norte', null, 'CN1 Costanera Norte - Kennedy', 'O-P', -33.4010, -70.5920, 380.5, 761.0, 951.25, 'Oriente-Poniente', 1],
  ['22', 'ini', 'costanera_norte', null, 'CN3 Costanera Norte - Vitacura', 'P-O', -33.3940, -70.6010, 305.2, 610.4, 763.0, 'Oriente-Poniente', 3],
  ['31', 'ini', 'vespucio_sur', null, 'VS2 Vespucio Sur - Macul', 'N-S', -33.4900, -70.5950, 298.4, 596.8, 746.0, 'Anillo', 2],
  ['32', 'ini', 'vespucio_sur', null, 'VS5 Vespucio Sur - La Florida', 'S-N', -33.5300, -70.5850, 276.9, 553.8, 692.25, 'Anillo', 5],
  ['41', 'ini', 'vespucio_norte', null, 'VN1 Vespucio Norte - Conchalí', 'O-P', -33.3800, -70.6700, 241.3, 482.6, 603.25, 'Anillo', 1],
  ['42', 'ini', 'vespucio_norte', null, 'VN4 Vespucio Norte - Huechuraba', 'P-O', -33.3600, -70.6500, 233.8, 467.6, 584.5, 'Túnel', 4],
  ['autopista_central_PA20', 'panel', 'autopista_central', 'PA20', 'PA20 General Velásquez - Pedro Aguirre Cerda', 'N-S', -33.4720, -70.6740, 310.0, 620.0, 775.0],
  ['autopista_central_PA45', 'panel', 'autopista_central', 'PA45', 'PA45 Ruta 5 Norte - Quilicura', 'S-N', -33.3850, -70.6800, 205.5, 411.0, 513.75],
  ['costanera_norte_P05', 'panel', 'costanera_norte', 'P05', 'CN5 Costanera Norte - Los Conquistadores', 'O-P', -33.4250, -70.6150, 352.1, 704.2, 880.25],
  ['costanera_norte_P08', 'panel', 'costanera_norte', 'P08', 'CN8 Costanera Norte - Lo Saldes', 'P-O', -33.4380, -70.6480, 330.0, 660.0, 825.0],
  ['vespucio_sur_P03', 'panel', 'vespucio_sur', 'P03', 'VS3 Vespucio Sur - Peñalolén', 'S-N', -33.5050, -70.5700, 289.0, 578.0, 722.5],
  ['vespucio_sur_P06', 'panel', 'vespucio_sur', 'P06', 'VS6 Vespucio Sur - Puente Alto', 'N-S', -33.5700, -70.5780, 270.0, 540.0, 675.0],
  ['vespucio_norte_P02', 'panel', 'vespucio_norte', 'P02', 'VN2 Vespucio Norte - Independencia', 'P-O', -33.4100, -70.6620, 236.4, 472.8, 591.0],
  ['vespucio_norte_P04', 'panel', 'vespucio_norte', 'P04', 'VN6 Vespucio Norte - Renca', 'O-P', -33.3950, -70.7050, 228.0, 456.0, 570.0],
];
const porticoPorId = {};
PORT.forEach((p) => {
  const [id, formato, conc, codigo, nombre, sentido, lat, lng, base, punta, sat, grupo, secuencia] = p;
  const autopista = CONC[conc].nombre;
  let data;
  if (formato === 'ini') {
    data = {
      nombre, autopista, sentido, lat, lng, activo: true,
      tarifa_base: base, tarifa_punta: punta, tarifa_saturacion: sat,
      costo: base, costoPunta: punta, costoSaturacion: sat,
      grupo, secuencia,
    };
  } else {
    data = {
      codigo, nombre, autopista, autopista_codigo: CONC[conc].codigo, sentido, lat, lng,
      activo: id !== 'vespucio_norte_P04', // uno inactivo, para probar el filtro
      tarifa_base: base, tarifa_punta: punta, tarifa_saturacion: sat,
    };
  }
  porticoPorId[id] = data;
  add(`porticos/${id}`, data);
});

// ------------------------------------------------------------------ beneficios
const BEN = [
  ['ben_combustible', { categoria: 'Combustible', titulo: '10% de descuento en combustible', descripcion: 'Descuento pagando con la app en estaciones adheridas.', empresa: 'Energía Ruta', imagen_path: 'beneficios/ben_combustible.png', url_externa: 'https://www.example.com/combustible', ubicacion: 'Todo Chile', fecha_inicio: d('2026-11-01'), fecha_fin: d('2026-12-31'), condiciones: 'Válido de lunes a viernes.', destacado: true, activo: true }],
  ['ben_taller', { categoria: 'Talleres', titulo: 'Diagnóstico gratis de 20 puntos', descripcion: 'Revisión general sin costo al agendar una mantención.', empresa: 'Taller Central', imagen_path: 'beneficios/ben_taller.png', url_externa: 'https://www.example.com/taller', ubicacion: 'Santiago', fecha_inicio: d('2026-10-15'), fecha_fin: d('2027-01-31'), condiciones: 'Previa reserva. Un diagnóstico por vehículo.', destacado: true, activo: true }],
  ['ben_mantencion', { categoria: 'Mantenciones', titulo: '15% en cambio de aceite y filtro', descripcion: 'Descuento en la mantención de los 10.000 km.', empresa: 'Lubri Express', imagen_path: 'beneficios/ben_mantencion.png', url_externa: 'https://www.example.com/lubri', ubicacion: 'Región Metropolitana', fecha_inicio: d('2026-11-01'), fecha_fin: d('2027-02-28'), condiciones: 'No acumulable con otras promociones.', destacado: false, activo: true }],
  ['ben_estacionamiento', { categoria: 'Estacionamientos', titulo: 'Primera hora gratis', descripcion: 'Primera hora sin costo en estacionamientos de centros comerciales adheridos.', empresa: 'Park Seguro', imagen_path: 'beneficios/ben_estacionamiento.png', url_externa: 'https://www.example.com/park', ubicacion: 'Santiago Oriente', fecha_inicio: d('2026-11-10'), fecha_fin: d('2026-12-24'), condiciones: 'Presentar el código en la caja.', destacado: false, activo: true }],
  ['ben_lavado', { categoria: 'Lavado', titulo: 'Lavado completo con 25% de descuento', descripcion: 'Lavado exterior e interior.', empresa: 'AutoLavado Brillo', imagen_path: 'beneficios/ben_lavado.png', url_externa: 'https://www.example.com/lavado', ubicacion: 'Providencia y Las Condes', fecha_inicio: d('2026-11-05'), fecha_fin: d('2026-12-15'), condiciones: 'Solo autos y motos.', destacado: false, activo: true }],
  ['ben_neumaticos', { categoria: 'Neumáticos', titulo: 'Alineación y balanceo gratis', descripcion: 'Al comprar cuatro neumáticos.', empresa: 'Neumáticos Sur', imagen_path: 'beneficios/ben_neumaticos.png', url_externa: 'https://www.example.com/neumaticos', ubicacion: 'Todo Chile', fecha_inicio: d('2026-10-01'), fecha_fin: d('2026-12-31'), condiciones: 'Válido en sucursales adheridas.', destacado: false, activo: true }],
  ['ben_seguro', { categoria: 'Seguros', titulo: '20% de descuento en seguro automotriz', descripcion: 'Cotiza tu seguro y obtén descuento el primer año.', empresa: 'Seguros Ruta Segura', imagen_path: 'beneficios/ben_seguro.png', url_externa: 'https://www.example.com/seguros', ubicacion: 'Todo Chile', fecha_inicio: d('2026-11-01'), fecha_fin: d('2027-03-31'), condiciones: 'Sujeto a evaluación de la compañía.', destacado: true, activo: true }],
  ['ben_otros', { categoria: 'Otros', categoria_otra: 'Asistencia en ruta', titulo: 'Grúa y asistencia 24/7 con 30% de descuento', descripcion: 'Plan anual de asistencia en ruta.', empresa: 'RutaSOS', imagen_path: 'beneficios/ben_otros.png', url_externa: 'https://www.example.com/asistencia', ubicacion: 'Todo Chile', fecha_inicio: d('2026-09-01'), fecha_fin: d('2026-10-31'), condiciones: 'Beneficio vencido, se deja inactivo.', destacado: false, activo: false }],
];
BEN.forEach(([id, data]) => add(`beneficios/${id}`, data));

// ------------------------------------------------------------------- vehiculos
const VEH = [
  { id: 'veh_krtp45', uid: U1, patente: 'KRTP45', marca: 'Toyota', modelo: 'Yaris', anio: 2021, tipo_vehiculo: 'AUTO', tipo_combustible: 'Gasolina', kilometraje_actual: 79300, alias: 'Auto de Camila', foto: true, reg: d('2026-10-17', '15:02') },
  { id: 'veh_hbwx32', uid: U1, patente: 'HBWX32', marca: 'Suzuki', modelo: 'Burgman 200', anio: 2023, tipo_vehiculo: 'MOTO', tipo_combustible: 'Gasolina', kilometraje_actual: 12400, alias: 'La moto', foto: false, reg: d('2026-10-18', '09:40') },
  { id: 'veh_pdlc88', uid: U2, patente: 'PDLC88', marca: 'Chevrolet', modelo: 'D-Max', anio: 2020, tipo_vehiculo: 'CAMIONETA', tipo_combustible: 'Diésel', kilometraje_actual: 96200, alias: 'Camioneta del trabajo', foto: true, reg: d('2026-09-21', '19:15') },
  { id: 'veh_lgfm17', uid: U2, patente: 'LGFM17', marca: 'Mazda', modelo: 'CX-5', anio: 2022, tipo_vehiculo: 'AUTO', tipo_combustible: 'Gasolina', kilometraje_actual: 41300, alias: null, foto: false, reg: d('2026-09-21', '19:40') },
  { id: 'veh_swtn26', uid: U3, patente: 'SWTN26', marca: 'Hyundai', modelo: 'Accent', anio: 2019, tipo_vehiculo: 'AUTO', tipo_combustible: 'Gasolina', kilometraje_actual: 88900, alias: 'Accent', foto: false, reg: d('2026-10-03', '11:20') },
  { id: 'veh_zxrk09', uid: U3, patente: 'ZXRK09', marca: 'BYD', modelo: 'Dolphin', anio: 2024, tipo_vehiculo: 'AUTO', tipo_combustible: 'Eléctrico', kilometraje_actual: 9800, alias: 'Eléctrico', foto: true, reg: d('2026-10-03', '11:45') },
];
VEH.forEach((v) => {
  const data = {
    id_usuario: REF(`usuarios/${v.uid}`),
    patente: v.patente, marca: v.marca, modelo: v.modelo, anio: v.anio,
    tipo_vehiculo: v.tipo_vehiculo, tipo_combustible: v.tipo_combustible,
    kilometraje_actual: v.kilometraje_actual,
    fecha_registro: v.reg, estado: 'activo',
  };
  if (v.alias) data.alias = v.alias;
  if (v.foto) data.foto_path = `usuarios/${v.uid}/vehiculos/${v.id}.jpg`;
  add(`vehiculos/${v.id}`, data);
});
const vehPorPatente = Object.fromEntries(VEH.map((v) => [v.patente, v]));

// ------------------------------------------------------ documentos_vehiculares
const NOMBRE_DOC = { permiso_circulacion: 'Permiso de circulación', revision_tecnica: 'Revisión técnica', soap: 'SOAP', seguro: 'Seguro' };
// [clave, patente, tipo, numero, emision, vencimiento, compania, poliza, forma_pago, origen, confianza, registro, emisionEstimada]
const DOCS = [
  ['krtp45_permiso', 'KRTP45', 'permiso_circulacion', 'PC-2026-117845', '2026-03-12', '2027-03-31', 'Municipalidad de Providencia', null, 'total', 'manual', null, d('2026-10-17', '15:30')],
  ['krtp45_revision', 'KRTP45', 'revision_tecnica', 'RT-2026-558312', '2026-01-28', '2027-01-31', 'Planta de Revisión Técnica Santiago Centro', null, null, 'ia', 0.9, d('2026-10-17', '15:40')],
  ['krtp45_soap', 'KRTP45', 'soap', 'SOAP-2026-004589', '2026-03-01', '2027-03-31', 'HDI Seguros', null, null, 'ia', 0.83, d('2026-11-20', '08:14')],
  ['krtp45_seguro', 'KRTP45', 'seguro', 'SEG-2025-90412', '2025-12-19', '2026-12-18', 'Seguros Ruta Segura', 'POL-77412903', null, 'manual', null, d('2026-10-17', '16:00')],
  ['hbwx32_permiso', 'HBWX32', 'permiso_circulacion', 'PC-2026-220871', '2026-03-20', '2027-03-31', 'Municipalidad de Providencia', null, 'cuota_1', 'manual', null, d('2026-10-18', '10:00')],
  ['hbwx32_soap', 'HBWX32', 'soap', null, '2026-04-01', '2027-03-31', 'Consorcio Seguros', null, null, 'ia', 0.72, d('2026-10-18', '10:10'), true],
  ['pdlc88_permiso', 'PDLC88', 'permiso_circulacion', 'PC-2026-330190', '2026-03-05', '2027-03-31', 'Municipalidad de Las Condes', null, 'cuota_2', 'manual', null, d('2026-09-22', '08:30')],
  ['pdlc88_revision', 'PDLC88', 'revision_tecnica', 'RT-2025-331207', '2025-12-06', '2026-12-05', 'Planta de Revisión Técnica Maipú', null, null, 'ia', 0.9, d('2026-09-22', '08:45')],
  ['pdlc88_soap', 'PDLC88', 'soap', 'SOAP-2026-118820', '2026-03-02', '2027-03-31', 'HDI Seguros', null, null, 'ia', 1, d('2026-09-22', '08:55')],
  ['pdlc88_seguro', 'PDLC88', 'seguro', 'SEG-2026-55120', '2026-07-01', '2027-06-30', 'Seguros Ruta Segura', 'POL-55120988', null, 'manual', null, d('2026-09-22', '09:10')],
  ['lgfm17_permiso', 'LGFM17', 'permiso_circulacion', 'PC-2026-448120', '2026-03-10', '2027-03-31', 'Municipalidad de Ñuñoa', null, 'total', 'manual', null, d('2026-09-22', '09:30')],
  ['lgfm17_soap', 'LGFM17', 'soap', 'SOAP-2026-224410', '2026-03-03', '2027-03-31', 'HDI Seguros', null, null, 'ia', 0.94, d('2026-09-22', '09:40')],
  ['swtn26_permiso', 'SWTN26', 'permiso_circulacion', 'PC-2026-559033', '2026-03-15', '2027-03-31', 'Municipalidad de Santiago', null, 'total', 'manual', null, d('2026-10-03', '12:00')],
  ['swtn26_revision', 'SWTN26', 'revision_tecnica', 'RT-2026-771245', '2026-08-31', '2027-08-31', 'Planta de Revisión Técnica Quilicura', null, null, 'ia', 0.88, d('2026-10-03', '12:10')],
  ['swtn26_soap', 'SWTN26', 'soap', 'SOAP-2026-336512', '2026-03-04', '2027-03-31', 'Consorcio Seguros', null, null, 'manual', null, d('2026-10-03', '12:20')],
  ['zxrk09_permiso', 'ZXRK09', 'permiso_circulacion', 'PC-2026-660442', '2026-03-18', '2027-03-31', 'Municipalidad de Santiago', null, 'total', 'manual', null, d('2026-10-03', '12:40')],
  ['zxrk09_soap', 'ZXRK09', 'soap', 'SOAP-2026-447781', '2026-03-05', '2027-03-31', 'HDI Seguros', null, null, 'ia', 1, d('2026-10-03', '12:50')],
  ['zxrk09_seguro', 'ZXRK09', 'seguro', 'SEG-2026-90233', '2026-10-16', '2027-10-15', 'Seguros Ruta Segura', 'POL-90233417', null, 'manual', null, d('2026-10-03', '13:05')],
];
const docsInfo = []; // para notificaciones y auditoría
DOCS.forEach(([clave, pat, tipo, numero, emision, venc, compania, poliza, forma, origen, conf, registro, estimada]) => {
  const v = vehPorPatente[pat];
  const id = `doc_${clave}`;
  const data = {
    uid: v.uid, vehiculo_id: v.id, tipo_documento: tipo,
    fecha_emision: d(emision), fecha_vencimiento: d(venc),
    compania, origen_registro: origen, fecha_registro: registro,
  };
  if (numero) data.numero = numero;
  if (poliza) data.numero_poliza = poliza;
  if (forma) data.forma_pago = forma; // solo permiso de circulación
  if (estimada) data.fecha_emision_estimada = true;
  if (origen === 'ia') {
    data.archivo_path = `usuarios/${v.uid}/documentos/${id}.pdf`;
    data.fecha_captura = new Date(registro.getTime() - 2 * 60000);
    data.confianza_ia = conf;
  }
  add(`documentos_vehiculares/${id}`, data);
  docsInfo.push({ id, uid: v.uid, veh: v, tipo, venc, registro, origen });
});

// ----------------------------------------------------------------- mantenciones
const MAN = []; // para notificaciones y auditoría
const manId = (clave) => `man_${clave}`;
// Realizadas
// [clave, patente, tipo, fecha, km, taller, costo, descripcion, comprobante, folio, origen, confianza]
[
  ['krtp45_frenos', 'KRTP45', 'Cambio de pastillas de freno', '2026-05-20', 69800, 'Frenos y Más', 86500, 'Cambio de pastillas delanteras y rectificado de discos', 'factura', '10432', 'manual', null],
  ['krtp45_aceite', 'KRTP45', 'Cambio de aceite y filtro', '2026-08-15', 72500, 'Taller Central', 129900, 'Cambio de aceite y filtro de aceite', 'boleta', '458123', 'ia', 1],
  ['hbwx32_aceite', 'HBWX32', 'Cambio de aceite y filtro', '2026-09-18', 11800, 'Moto Service Norte', 38000, 'Aceite 10W-40 y filtro', 'boleta', '120987', 'ia', 0.9],
  ['pdlc88_neumaticos', 'PDLC88', 'Rotación de neumáticos', '2026-09-05', 94800, 'Neumáticos Sur', 45000, 'Rotación y balanceo de las cuatro ruedas', 'boleta', '88231', 'manual', null],
  ['lgfm17_40000', 'LGFM17', 'Mantención de los 40.000 km', '2026-10-02', 40100, 'Servicio Oficial Mazda', 189900, 'Cambio de aceite, filtros y revisión general', 'factura', '55120', 'ia', 0.94],
  ['swtn26_bateria', 'SWTN26', 'Cambio de batería', '2026-07-12', 85200, 'Baterías del Sur', 74990, 'Batería de 60 Ah con instalación', 'boleta', '33401', 'manual', null],
  ['zxrk09_electrico', 'ZXRK09', 'Revisión del sistema eléctrico', '2026-10-25', 9050, 'Servicio Oficial BYD', 35000, 'Diagnóstico de batería y frenos regenerativos', 'boleta', '70215', 'ia', 0.88],
].forEach(([clave, pat, tipo, fecha, km, taller, costo, desc, comp, folio, origen, conf]) => {
  const v = vehPorPatente[pat];
  const data = {
    uid: v.uid, vehiculo_id: v.id, estado: 'realizada', tipo, tipo_otro: null,
    fecha: d(fecha), kilometraje: km, taller, costo, descripcion: desc, observaciones: null,
    componentes: [], proxima_fecha: null, proximo_kilometraje: null,
    tipo_comprobante: comp, numero_comprobante: folio, origen_registro: origen,
  };
  if (origen === 'ia') {
    data.fecha_captura = d(fecha, '12:40');
    data.confianza_ia = conf;
  }
  add(`mantenciones/${manId(clave)}`, data);
  MAN.push({ id: manId(clave), uid: v.uid, veh: v, estado: 'realizada' });
});
// Programadas
// [clave, patente, tipo, proxima_fecha, proximo_km, taller, creada]
[
  ['krtp45_prog', 'KRTP45', 'Cambio de aceite y filtro', '2027-02-15', 82500, 'Taller Central', d('2026-08-15', '12:45')],
  ['hbwx32_prog', 'HBWX32', 'Cambio de aceite y filtro', '2027-03-18', 16800, 'Moto Service Norte', d('2026-09-18', '12:00')],
  ['pdlc88_prog', 'PDLC88', 'Cambio de correa de distribución', '2026-11-27', 100000, 'Taller Diésel Maipú', d('2026-09-05', '17:30')],
  ['lgfm17_prog', 'LGFM17', 'Mantención de los 50.000 km', '2027-04-02', 50000, 'Servicio Oficial Mazda', d('2026-10-02', '13:00')],
  ['swtn26_prog', 'SWTN26', 'Alineación y balanceo', '2027-01-10', 93000, 'Neumáticos Sur', d('2026-07-12', '16:00')],
].forEach(([clave, pat, tipo, prox, kmProx, taller, creada]) => {
  const v = vehPorPatente[pat];
  add(`mantenciones/${manId(clave)}`, {
    uid: v.uid, vehiculo_id: v.id, estado: 'programada', tipo, taller,
    proxima_fecha: d(prox), proximo_kilometraje: kmProx, origen_registro: 'manual',
  });
  MAN.push({ id: manId(clave), uid: v.uid, veh: v, estado: 'programada', tipo, prox, creada });
});

// ------------------------------------------------------------- estacionamientos
// estacionamientos_activos queda vacía (ningún cronómetro corriendo), igual que la base real.
// [clave, patente, lugar, direccion, nivel, sector, entrada, salida, duracion_min, duracion_app, costo, geo, observacion, estado, origen, origen_comprobante, conf]
const EST = [
  ['krtp45_1', 'KRTP45', 'Costanera Center', 'Av. Andrés Bello 2425, Providencia', '-2', 'B14', ['2026-11-12', '10:30'], ['2026-11-12', '12:05'], 95, 93, 3500, [-33.4175, -70.6067], null, 'finalizado', 'manual', 'ia', 0.9],
  ['krtp45_2', 'KRTP45', 'Mall Plaza Vespucio', 'Av. Vicuña Mackenna 7110, La Florida', '-1', 'C02', ['2026-11-05', '16:10'], ['2026-11-05', '18:40'], 150, 148, 2200, [-33.5190, -70.5990], null, 'finalizado', 'manual', 'manual', null],
  ['krtp45_3', 'KRTP45', 'Parque Arauco', 'Av. Presidente Kennedy 5413, Las Condes', '1', 'A21', ['2026-11-18', '13:00'], ['2026-11-18', '14:20'], null, 80, null, [-33.4017, -70.5774], 'Falta subir la boleta', 'pendienteComprobante', 'manual', null, null],
  ['hbwx32_1', 'HBWX32', 'Estacionamiento Bellas Artes', 'Av. José Miguel de la Barra 480, Santiago', null, null, ['2026-11-11', '09:00'], ['2026-11-11', '13:30'], 270, null, 1800, null, null, 'finalizado', 'ia', null, 0.9],
  ['pdlc88_1', 'PDLC88', 'Edificio Corporativo Apoquindo', 'Av. Apoquindo 4500, Las Condes', '-3', 'D08', ['2026-11-09', '08:20'], ['2026-11-09', '18:05'], 585, 583, 7800, [-33.4167, -70.5810], 'Reunión de trabajo', 'finalizado', 'manual', 'manual', null],
  ['lgfm17_1', 'LGFM17', 'Estacionamiento Plaza de Armas', 'Monjitas 805, Santiago', null, null, ['2026-11-14', '11:15'], ['2026-11-14', '12:45'], 90, null, 2900, null, null, 'finalizado', 'ia', null, 0.92],
  ['swtn26_1', 'SWTN26', 'Mall Costanera Center', 'Av. Andrés Bello 2447, Providencia', '-1', 'A10', ['2026-10-30', '19:00'], ['2026-10-30', '21:10'], 130, 128, 3100, [-33.4180, -70.6070], null, 'finalizado', 'manual', 'ia', 0.88],
  ['zxrk09_1', 'ZXRK09', 'Mall Alto Las Condes', 'Av. Presidente Kennedy 9001, Las Condes', '-2', 'E31', ['2026-11-15', '15:45'], ['2026-11-15', '17:00'], 75, 74, 1500, [-33.3903, -70.5445], 'Mientras cargaba el auto', 'finalizado', 'manual', 'manual', null],
];
EST.forEach(([clave, pat, lugar, dir, nivel, sector, ent, sal, dur, durApp, costo, geo, obs, estado, origen, origenComp, conf]) => {
  const v = vehPorPatente[pat];
  const data = {
    uid: v.uid, vehiculo_id: v.id, fecha: d(ent[0], ent[1]), lugar, direccion: dir,
    hora_entrada: d(ent[0], ent[1]), hora_salida: d(sal[0], sal[1]),
    estado, origen_registro: origen,
  };
  if (nivel) data.nivel = nivel;
  if (sector) data.sector = sector;
  if (dur != null) data.duracion_min = dur;
  if (durApp != null) data.duracion_app_min = durApp;
  if (costo != null) data.costo = costo;
  if (geo) data.ubicacion = GEO(geo[0], geo[1]);
  if (obs) data.observacion = obs;
  if (origenComp) data.origen_comprobante = origenComp;
  if (conf != null) {
    data.fecha_captura = new Date(data.hora_salida.getTime() + 2 * 60000);
    data.confianza_ia = conf;
  }
  add(`estacionamientos/est_${clave}`, data);
});

// ---------------------------------------------------------------- abastecimientos
// [clave, patente, fecha, hora, km, estacion, tipo_abast, combustible, cantidad, unidad, precio, origen, confianza]
[
  ['krtp45_1', 'KRTP45', '2026-10-24', '18:10', 78050, 'Shell', 'combustible', 'Gasolina 95', 32.1, 'L', 1285, 'manual', null],
  ['krtp45_2', 'KRTP45', '2026-11-10', '19:20', 78900, 'Copec', 'combustible', 'Gasolina 95', 34.8, 'L', 1298, 'ia', 0.9],
  ['krtp45_3', 'KRTP45', '2026-11-17', '08:05', 79300, 'Copec', 'combustible', 'Gasolina 95', 30.5, 'L', 1302, 'ia', 1],
  ['hbwx32_1', 'HBWX32', '2026-11-03', '17:30', 12350, 'Copec', 'combustible', 'Gasolina 95', 9.2, 'L', 1296, 'manual', null],
  ['pdlc88_1', 'PDLC88', '2026-10-26', '07:45', 95100, 'Copec', 'combustible', 'Diésel', 55.4, 'L', 1032, 'manual', null],
  ['pdlc88_2', 'PDLC88', '2026-11-08', '07:50', 96000, 'Petrobras', 'combustible', 'Diésel', 60.0, 'L', 1040, 'ia', 0.83],
  ['lgfm17_1', 'LGFM17', '2026-11-13', '20:15', 41250, 'Shell', 'combustible', 'Gasolina 93', 38.0, 'L', 1252, 'manual', null],
  ['swtn26_1', 'SWTN26', '2026-11-06', '12:40', 88800, 'Copec', 'combustible', 'Gasolina 93', 28.6, 'L', 1255, 'ia', 0.92],
  ['zxrk09_1', 'ZXRK09', '2026-11-01', '23:10', 9200, 'Carga domiciliaria', 'carga_electrica', 'Eléctrico', 41.0, 'kWh', 165, 'manual', null],
  ['zxrk09_2', 'ZXRK09', '2026-11-15', '17:05', 9750, 'Punto de carga Mall Alto Las Condes', 'carga_electrica', 'Eléctrico', 32.5, 'kWh', 238, 'ia', 0.9],
  ['hbwx32_2', 'HBWX32', '2026-11-16', '09:20', 12400, 'Shell', 'combustible', 'Gasolina 93', 8.4, 'L', 1253, 'manual', null],
].forEach(([clave, pat, fecha, hora, km, estacion, tipo, comb, cant, unidad, precio, origen, conf]) => {
  const v = vehPorPatente[pat];
  const data = {
    uid: v.uid, vehiculo_id: v.id, fecha: d(fecha, hora), kilometraje: km,
    estacion_servicio: estacion, tipo_abastecimiento: tipo, tipo_combustible: comb,
    cantidad: cant, unidad, precio_unitario: precio, total: Math.round(cant * precio),
    origen_registro: origen,
  };
  if (origen === 'ia') {
    data.fecha_captura = new Date(data.fecha.getTime() + 2 * 60000);
    data.confianza_ia = conf;
  }
  add(`abastecimientos/aba_${clave}`, data);
});

// ---------------------------------------------------------------- notificaciones
const HOY = d('2026-11-20', '08:15');
const LEIDAS_ANTES_DE = d('2026-11-15');
const notif = (id, uid, vehiculo_id, tipo, referencia_id, mensaje, programada, generacion) => {
  const leida = programada < LEIDAS_ANTES_DE;
  add(`notificaciones/${id}`, {
    usuario_id: uid, vehiculo_id, tipo, referencia_id, mensaje,
    fecha_programada: programada, fecha_generacion: generacion,
    leida, estado: leida ? 'leida' : 'pendiente',
  });
};
// Vencimiento de documentos: avisos a 30, 15 y 7 días. id = {referencia_id}_{momento}
docsInfo.forEach((x) => {
  [30, 15, 7].forEach((n) => {
    const programada = addDays(d(x.venc, '09:00'), -n);
    if (programada < x.registro) return; // no se avisa hacia el pasado del registro
    notif(`${x.id}_${n}dias`, x.uid, x.veh.id, 'vencimiento_documento', x.id,
      `Tu ${NOMBRE_DOC[x.tipo]} (${x.veh.patente}) vence en ${n} días.`, programada, x.registro);
  });
});
// Mantenciones programadas: avisos a 7 días y el mismo día.
MAN.filter((m) => m.estado === 'programada').forEach((m) => {
  [['7dias', -7, `Tu mantención «${m.tipo}» (${m.veh.patente}) es en 7 días.`],
   ['dia', 0, `Hoy corresponde tu mantención «${m.tipo}» (${m.veh.patente}).`]].forEach(([momento, off, msg]) => {
    const programada = addDays(d(m.prox, '09:00'), off);
    if (programada < m.creada) return;
    notif(`${m.id}_${momento}`, m.uid, m.veh.id, 'mantencion_programada', m.id, msg, programada, m.creada);
  });
});

// --------------------------------------------------- viajes TAG (subcolección trips)
const costoPortico = (id, hhmm) => {
  const p = porticoPorId[id];
  const h = Number(hhmm.slice(0, 2));
  const punta = (h >= 7 && h < 9) || (h >= 18 && h < 20);
  return punta ? p.tarifa_punta : p.tarifa_base;
};
// [clave, uid, patente, fecha, hora, duracionMin, km, [[porticoId, minutosDesdeInicio], ...]]
const TRIPS = [
  ['t1', U1, 'KRTP45', '2026-10-01', '07:50', 63, 24.6, [['11', 5], ['12', 30]]],
  ['t2', U1, 'KRTP45', '2026-10-08', '18:10', 55, 19.8, [['11', 8], ['autopista_central_PA20', 30]]],
  ['t3', U1, 'KRTP45', '2026-10-22', '13:00', 48, 17.2, [['12', 10], ['autopista_central_PA45', 35]]],
  ['t4', U2, 'LGFM17', '2026-10-05', '08:15', 70, 28.4, [['21', 6], ['22', 25], ['costanera_norte_P05', 45]]],
  ['t5', U2, 'PDLC88', '2026-10-19', '19:00', 52, 21.0, [['21', 7], ['costanera_norte_P08', 30]]],
  ['t6', U3, 'SWTN26', '2026-10-14', '09:30', 66, 26.3, [['31', 8], ['32', 28], ['vespucio_sur_P03', 50]]],
  ['t7', U3, 'SWTN26', '2026-10-28', '17:45', 41, 14.9, [['41', 5], ['vespucio_norte_P02', 25]]],
];
const tripsInfo = {};
TRIPS.forEach(([clave, uid, pat, fecha, hora, dur, km, pasos]) => {
  const v = vehPorPatente[pat];
  const tolls = pasos.map(([pid, off]) => {
    const ts = isoLocal(fecha, hora, off);
    return { name: porticoPorId[pid].nombre, cost: costoPortico(pid, ts.slice(11, 16)), timestamp: ts, autopista: porticoPorId[pid].autopista };
  });
  const total = Math.round(tolls.reduce((s, t) => s + t.cost, 0));
  add(`usuarios/${uid}/trips/trip_${clave}`, {
    date: isoLocal(fecha, hora, dur),
    totalCost: total, distanceKm: km,
    duration: `${Math.floor(dur / 60) ? Math.floor(dur / 60) + 'h ' : ''}${dur % 60}m`,
    vehicleName: `${v.marca} ${v.modelo}`,
    tolls: tolls.map(({ name, cost, timestamp }) => ({ name, cost, timestamp })),
  });
  tripsInfo[clave] = { tolls };
});

// ----------------------------------- boletas auditadas (subcolección audited_invoices)
const detalleDe = (tolls) => tolls.map((t) => ({
  date: t.timestamp.slice(0, 10), time: t.timestamp.slice(11, 16), portico: t.name, cost: Math.round(t.cost), status: 'Correcto',
}));
const suma = (arr) => arr.reduce((s, x) => s + x.cost, 0);
const factura = (uid, clave, concesionaria, period, patent, details, subido, informe) => {
  const totalBilled = suma(details);
  const totalMatched = suma(details.filter((x) => x.status === 'Correcto'));
  const rate = totalBilled ? Math.round((totalMatched / totalBilled) * 10000) / 100 : 0;
  const status = totalMatched === 0 ? 'Sin Registro' : totalMatched === totalBilled ? 'Conciliado' : 'Discrepancia Parcial';
  add(`usuarios/${uid}/audited_invoices/inv_${clave}`, {
    concessionaire: concesionaria, period, patent, totalBilled, totalMatched,
    reconciliationRate: rate, status, uploadDate: subido, details, aiReport: informe, auditedBy: 'OpenAI',
  });
};
{
  const d1 = detalleDe([...tripsInfo.t1.tolls, ...tripsInfo.t2.tolls, ...tripsInfo.t3.tolls]);
  factura(U1, 'ac_oct', 'Autopista Central', 'Oct 2026', 'KRTP45', d1, '2026-11-02T18:40:12.000',
    '### Auditoría Autopista Central – Oct 2026\n\nTodos los cobros de la boleta coinciden con tus viajes registrados. **Sin diferencias.**');
  const d2 = [...detalleDe(tripsInfo.t4.tolls),
    { date: '2026-10-26', time: '21:14', portico: 'CN3 Costanera Norte - Vitacura', cost: 611, status: 'Discrepancia' }];
  factura(U2, 'cn_oct', 'Costanera Norte', 'Oct 2026', 'LGFM17', d2, '2026-11-04T10:12:45.000',
    '### Auditoría Costanera Norte – Oct 2026\n\nSe encontró **1 cobro sin viaje registrado** (26-oct, 21:14, CN3 Vitacura, $611). Revisa si recorriste ese tramo; si no, puedes reclamar a la concesionaria.');
  const d3 = [
    { date: '2026-09-09', time: '08:02', portico: 'VN1 Vespucio Norte - Conchalí', cost: 482, status: 'Discrepancia' },
    { date: '2026-09-23', time: '18:31', portico: 'VN6 Vespucio Norte - Renca', cost: 456, status: 'Discrepancia' },
  ];
  factura(U3, 'vn_sep', 'Vespucio Norte', 'Sep 2026', 'SWTN26', d3, '2026-11-08T20:03:10.000',
    '### Auditoría Vespucio Norte – Sep 2026\n\nNinguno de los cobros tiene viajes registrados en la app durante septiembre. Estado: **Sin registro**.');
}

// ------------------------------------------------------------------- auditoria
// Formato de la app: usuario_id, accion, tipo_entidad, entidad_id, detalle, origen, fecha
const logsApp = [];
VEH.forEach((v) => logsApp.push({ fecha: v.reg, usuario_id: v.uid, accion: 'CREAR', tipo_entidad: 'VEHICULO', entidad_id: v.id, detalle: `Vehículo ${v.patente} registrado`, origen: 'manual' }));
docsInfo.forEach((x) => logsApp.push({ fecha: x.registro, usuario_id: x.uid, accion: 'CREAR', tipo_entidad: 'DOCUMENTO_VEHICULAR', entidad_id: x.id, detalle: `Documento ${NOMBRE_DOC[x.tipo]} registrado`, origen: x.origen }));
logsApp.push({ fecha: d('2026-10-10', '14:00'), usuario_id: U3, accion: 'ELIMINAR', tipo_entidad: 'VEHICULO', entidad_id: 'veh_eliminado_demo', detalle: 'Vehículo de prueba eliminado', origen: 'manual' });
logsApp.push({ fecha: d('2026-10-20', '12:30'), usuario_id: U2, accion: 'ELIMINAR', tipo_entidad: 'DOCUMENTO_VEHICULAR', entidad_id: 'doc_eliminado_demo', detalle: 'Documento duplicado eliminado', origen: 'manual' });
logsApp.sort((a, b) => a.fecha - b.fecha).forEach((l, i) => add(`auditoria/log_app_${String(i + 1).padStart(3, '0')}`, l));

// Formato del panel admin: adminEmail, action, target, details, fecha
const logsPanel = [
  { fecha: d('2026-09-02', '10:00'), adminEmail: ADMIN_SUPER_EMAIL, action: 'IMPORT_PORTICOS', target: 'porticos', details: `${PORT.length} pórticos importados` },
  ...Object.values(CONC).map((c, i) => ({ fecha: d('2026-09-02', `10:${10 + i}`), adminEmail: ADMIN_SUPER_EMAIL, action: 'CREATE_CONCESIONARIA', target: c.nombre, details: `Concesionaria ${c.codigo} creada` })),
  ...BEN.map(([id, b], i) => ({ fecha: d('2026-11-01', `11:${pad(i * 5)}`), adminEmail: ADMIN_SUPER_EMAIL, action: 'CREATE_BENEFICIO', target: b.titulo, details: `Beneficio de ${b.empresa} (${b.categoria}) creado` })),
  { fecha: d('2026-11-18', '00:20'), adminEmail: ADMIN_SUPER_EMAIL, action: 'CREATE_ADMIN', target: ADMIN_OPER_EMAIL, details: 'Administrador creado con rol operador' },
  { fecha: d('2026-11-19', '09:30'), adminEmail: ADMIN_OPER_EMAIL, action: 'EDIT_USER_NAME', target: emailDe[U3], details: 'Se editó nombre_mostrar' },
];
logsPanel.sort((a, b) => a.fecha - b.fecha).forEach((l, i) => add(`auditoria/log_panel_${String(i + 1).padStart(3, '0')}`, l));

module.exports = { docs, HOY, helpers: { porticoPorId } };
