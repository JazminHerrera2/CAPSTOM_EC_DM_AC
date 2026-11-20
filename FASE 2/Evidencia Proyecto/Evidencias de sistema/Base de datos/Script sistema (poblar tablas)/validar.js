'use strict';
/**
 * Revisa que los datos de ejemplo sean coherentes con el modelo:
 * existencia de las referencias (uid, vehiculo_id, referencia_id, autopista_codigo...)
 * y valores permitidos. No necesita conexión a Firebase.
 */
function validar(docs) {
  const errores = [];
  const err = (path, msg) => errores.push(`${path}: ${msg}`);

  const porColeccion = {};
  const rutas = new Set();
  for (const { path, data } of docs) {
    if (rutas.has(path)) err(path, 'ruta duplicada');
    rutas.add(path);
    const col = path.split('/').length > 2 ? path.split('/').slice(2, 3)[0] : path.split('/')[0];
    (porColeccion[col] = porColeccion[col] || []).push({ path, id: path.split('/').pop(), data });
  }
  const ids = (col) => new Set((porColeccion[col] || []).map((x) => x.id));
  const usuarios = ids('usuarios');
  const vehiculos = new Map((porColeccion.vehiculos || []).map((v) => [v.id, v]));
  const docsVeh = ids('documentos_vehiculares');
  const mant = ids('mantenciones');
  const nombresPortico = new Set((porColeccion.porticos || []).map((p) => p.data.nombre));
  const codigosConc = new Set((porColeccion.concesionarias || []).map((c) => c.data.codigo));
  const emailsAdmin = new Set((porColeccion.administradores || []).map((a) => a.data.email));
  const enumIn = (path, campo, valor, permitidos) => {
    if (valor !== undefined && valor !== null && !permitidos.includes(valor)) err(path, `${campo}="${valor}" no está en [${permitidos.join(', ')}]`);
  };
  const req = (path, data, campos) => campos.forEach((c) => { if (data[c] === undefined || data[c] === null) err(path, `falta campo obligatorio ${c}`); });
  const refUid = (path, uid) => { if (!usuarios.has(uid)) err(path, `uid inexistente ${uid}`); };
  const refVeh = (path, data, uidCampo) => {
    const v = vehiculos.get(data.vehiculo_id);
    if (!v) return err(path, `vehiculo_id inexistente ${data.vehiculo_id}`);
    const dueño = v.data.id_usuario.__ref.split('/')[1];
    if (data[uidCampo] !== dueño) err(path, `el vehículo ${data.vehiculo_id} pertenece a otro usuario`);
  };

  // UIDs de 28 caracteres
  [...usuarios, ...ids('administradores')].forEach((u) => { if (u.length !== 28) err(`uid ${u}`, `debe tener 28 caracteres (tiene ${u.length})`); });

  (porColeccion.usuarios || []).forEach(({ path, data }) => {
    req(path, data, ['email', 'fecha_creacion', 'limite_presupuesto_mensual']);
    if (data.vehiculo_principal_id && ![...vehiculos.values()].some((v) => v.data.patente === data.vehiculo_principal_id && v.data.id_usuario.__ref === `usuarios/${path.split('/')[1]}`)) {
      err(path, `vehiculo_principal_id ${data.vehiculo_principal_id} no es una patente de ese usuario`);
    }
  });
  const patentes = new Set();
  (porColeccion.vehiculos || []).forEach(({ path, data }) => {
    req(path, data, ['id_usuario', 'patente', 'marca', 'modelo', 'anio', 'tipo_vehiculo', 'tipo_combustible', 'fecha_registro', 'estado']);
    refUid(path, data.id_usuario.__ref.split('/')[1]);
    enumIn(path, 'tipo_vehiculo', data.tipo_vehiculo, ['AUTO', 'CAMIONETA', 'MOTO']);
    const k = `${data.id_usuario.__ref}|${data.patente}`;
    if (patentes.has(k)) err(path, 'patente repetida para el mismo usuario');
    patentes.add(k);
  });
  (porColeccion.documentos_vehiculares || []).forEach(({ path, data }) => {
    req(path, data, ['uid', 'vehiculo_id', 'tipo_documento', 'origen_registro', 'fecha_registro']);
    refVeh(path, data, 'uid');
    enumIn(path, 'tipo_documento', data.tipo_documento, ['permiso_circulacion', 'revision_tecnica', 'soap', 'seguro']);
    enumIn(path, 'forma_pago', data.forma_pago, ['total', 'cuota_1', 'cuota_2']);
    enumIn(path, 'origen_registro', data.origen_registro, ['manual', 'ia']);
    if (data.forma_pago && data.tipo_documento !== 'permiso_circulacion') err(path, 'forma_pago solo aplica al permiso de circulación');
    if (data.confianza_ia != null && (data.confianza_ia < 0 || data.confianza_ia > 1)) err(path, 'confianza_ia fuera de 0..1');
  });
  const vigentes = new Set();
  (porColeccion.documentos_vehiculares || []).forEach(({ path, data }) => {
    const k = `${data.vehiculo_id}|${data.tipo_documento}`;
    if (vigentes.has(k)) err(path, 'un vehículo debe tener un solo documento vigente por tipo');
    vigentes.add(k);
  });
  (porColeccion.mantenciones || []).forEach(({ path, data }) => {
    req(path, data, ['uid', 'vehiculo_id', 'estado', 'tipo', 'origen_registro']);
    refVeh(path, data, 'uid');
    enumIn(path, 'estado', data.estado, ['programada', 'realizada']);
    enumIn(path, 'tipo_comprobante', data.tipo_comprobante, ['boleta', 'factura', 'otro']);
    if (data.estado === 'realizada' && !data.fecha) err(path, 'una mantención realizada necesita fecha');
    if (data.tipo.length < 1 || data.tipo.length > 60) err(path, 'tipo debe tener 1 a 60 caracteres');
    if (data.estado === 'realizada' && Number.isFinite(data.costo) && !Number.isInteger(data.costo)) err(path, 'costo debe ser entero');
  });
  (porColeccion.estacionamientos || []).forEach(({ path, data }) => {
    req(path, data, ['uid', 'vehiculo_id', 'fecha', 'estado', 'origen_registro']);
    refVeh(path, data, 'uid');
    enumIn(path, 'estado', data.estado, ['activo', 'pendienteComprobante', 'finalizado']);
    enumIn(path, 'origen_registro', data.origen_registro, ['manual', 'ia']);
    enumIn(path, 'origen_comprobante', data.origen_comprobante, ['manual', 'ia']);
    if (data.hora_entrada && data.hora_salida) {
      if (data.hora_salida < data.hora_entrada) err(path, 'hora_salida anterior a hora_entrada');
      const min = Math.round((data.hora_salida - data.hora_entrada) / 60000);
      if (data.duracion_min != null && data.duracion_min !== min) err(path, `duracion_min=${data.duracion_min} pero entrada→salida son ${min} min`);
      if (data.duracion_app_min != null && Math.abs(data.duracion_app_min - min) > 5) err(path, 'duracion_app_min difiere demasiado');
    }
    if (data.duracion_min > 43200) err(path, 'duracion_min supera 43.200');
    if (data.observacion && data.observacion.length > 500) err(path, 'observacion supera 500 caracteres');
  });
  (porColeccion.abastecimientos || []).forEach(({ path, data }) => {
    req(path, data, ['uid', 'vehiculo_id', 'fecha', 'tipo_abastecimiento', 'origen_registro']);
    refVeh(path, data, 'uid');
    enumIn(path, 'tipo_abastecimiento', data.tipo_abastecimiento, ['combustible', 'carga_electrica']);
    enumIn(path, 'tipo_combustible', data.tipo_combustible, ['Gasolina 93', 'Gasolina 95', 'Gasolina 97', 'Diésel', 'Gas licuado (GLP)', 'Eléctrico']);
    enumIn(path, 'unidad', data.unidad, ['L', 'kWh']);
    if (data.total !== Math.round(data.cantidad * data.precio_unitario)) err(path, 'total != cantidad × precio_unitario');
    if (data.tipo_abastecimiento === 'carga_electrica' && data.unidad !== 'kWh') err(path, 'carga eléctrica debe ir en kWh');
    if (data.tipo_abastecimiento === 'combustible' && data.unidad !== 'L') err(path, 'combustible debe ir en litros');
  });
  // kilometraje no decrece en el tiempo, por vehículo (abastecimientos + mantenciones realizadas) y no supera el actual
  {
    const porVeh = {};
    [...(porColeccion.abastecimientos || []), ...(porColeccion.mantenciones || [])].forEach(({ path, data }) => {
      const f = data.fecha; const km = data.kilometraje;
      if (!f || km == null) return;
      (porVeh[data.vehiculo_id] = porVeh[data.vehiculo_id] || []).push({ path, f, km });
    });
    Object.entries(porVeh).forEach(([vid, arr]) => {
      arr.sort((a, b) => a.f - b.f);
      for (let i = 1; i < arr.length; i++) if (arr[i].km < arr[i - 1].km) err(arr[i].path, `kilometraje ${arr[i].km} menor que el registro anterior (${arr[i - 1].km})`);
      const actual = vehiculos.get(vid).data.kilometraje_actual;
      arr.forEach((a) => { if (a.km > actual) err(a.path, `kilometraje ${a.km} mayor que kilometraje_actual (${actual})`); });
    });
  }
  (porColeccion.notificaciones || []).forEach(({ path, id, data }) => {
    req(path, data, ['usuario_id', 'vehiculo_id', 'tipo', 'referencia_id', 'mensaje', 'fecha_programada', 'fecha_generacion', 'leida', 'estado']);
    refUid(path, data.usuario_id);
    refVeh(path, data, 'usuario_id');
    enumIn(path, 'tipo', data.tipo, ['vencimiento_documento', 'mantencion_programada']);
    enumIn(path, 'estado', data.estado, ['pendiente', 'leida']);
    if (data.leida !== (data.estado === 'leida')) err(path, 'leida y estado no coinciden');
    const destino = data.tipo === 'vencimiento_documento' ? docsVeh : mant;
    if (!destino.has(data.referencia_id)) err(path, `referencia_id ${data.referencia_id} no existe`);
    if (!id.startsWith(`${data.referencia_id}_`)) err(path, 'el id debe ser {referencia_id}_{momento}');
  });
  (porColeccion.auditoria || []).forEach(({ path, data }) => {
    req(path, data, ['fecha']);
    if (data.adminEmail) {
      req(path, data, ['action', 'target', 'details']);
      if (!emailsAdmin.has(data.adminEmail)) err(path, `adminEmail ${data.adminEmail} no está en administradores`);
    } else {
      req(path, data, ['usuario_id', 'accion', 'tipo_entidad', 'entidad_id', 'detalle', 'origen']);
      refUid(path, data.usuario_id);
      enumIn(path, 'accion', data.accion, ['CREAR', 'ELIMINAR']);
      enumIn(path, 'tipo_entidad', data.tipo_entidad, ['VEHICULO', 'DOCUMENTO_VEHICULAR']);
      enumIn(path, 'origen', data.origen, ['manual', 'ia', 'sistema']);
      if (data.accion === 'CREAR') {
        const destino = data.tipo_entidad === 'VEHICULO' ? vehiculos : docsVeh;
        if (!(destino.has ? destino.has(data.entidad_id) : false)) err(path, `entidad_id ${data.entidad_id} no existe`);
      }
    }
  });
  (porColeccion.porticos || []).forEach(({ path, data }) => {
    req(path, data, ['nombre', 'autopista', 'lat', 'lng']);
    enumIn(path, 'sentido', data.sentido, ['N-S', 'S-N', 'O-P', 'P-O']);
    enumIn(path, 'grupo', data.grupo, ['Anillo', 'Norte-Sur', 'Oriente-Poniente', 'Túnel']);
    if (data.autopista_codigo && !codigosConc.has(data.autopista_codigo)) err(path, `autopista_codigo ${data.autopista_codigo} no existe en concesionarias`);
  });
  (porColeccion.beneficios || []).forEach(({ path, data }) => {
    req(path, data, ['categoria', 'titulo', 'empresa', 'destacado', 'activo']);
    enumIn(path, 'categoria', data.categoria, ['Combustible', 'Talleres', 'Mantenciones', 'Estacionamientos', 'Lavado', 'Neumáticos', 'Seguros', 'Accesorios', 'Otros']);
    if (data.categoria === 'Otros' && !data.categoria_otra) err(path, 'categoria Otros requiere categoria_otra');
    if (data.fecha_inicio && data.fecha_fin && data.fecha_fin < data.fecha_inicio) err(path, 'fecha_fin anterior a fecha_inicio');
  });
  (porColeccion.administradores || []).forEach(({ path, data }) => {
    req(path, data, ['email', 'rol']);
    enumIn(path, 'rol', data.rol, ['super_admin', 'operador']);
  });
  (porColeccion.trips || []).forEach(({ path, data }) => {
    req(path, data, ['date', 'totalCost', 'distanceKm', 'duration', 'vehicleName', 'tolls']);
    refUid(path, path.split('/')[1]);
    data.tolls.forEach((t) => { if (!nombresPortico.has(t.name)) err(path, `pórtico "${t.name}" no existe en porticos`); });
    if (data.totalCost !== Math.round(data.tolls.reduce((s, t) => s + t.cost, 0))) err(path, 'totalCost != suma de tolls');
  });
  (porColeccion.audited_invoices || []).forEach(({ path, data }) => {
    req(path, data, ['concessionaire', 'period', 'patent', 'totalBilled', 'totalMatched', 'reconciliationRate', 'status', 'uploadDate', 'details', 'aiReport', 'auditedBy']);
    enumIn(path, 'status', data.status, ['Conciliado', 'Discrepancia Parcial', 'Sin Registro']);
    data.details.forEach((x) => enumIn(path, 'details.status', x.status, ['Correcto', 'Discrepancia']));
    if (data.totalBilled !== data.details.reduce((s, x) => s + x.cost, 0)) err(path, 'totalBilled != suma de details');
  });
  return { errores, conteo: Object.fromEntries(Object.entries(porColeccion).map(([k, v]) => [k, v.length])) };
}
module.exports = { validar };
