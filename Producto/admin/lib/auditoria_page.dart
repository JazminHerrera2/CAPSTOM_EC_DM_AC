import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_firestore_service.dart';
import 'admin_ui.dart';

/// Tipo de acción para la etiqueta de color de la bitácora.
enum TipoAccion {
  creacion('Creación'),
  actualizacion('Actualización'),
  eliminacion('Eliminación'),
  activacion('Activación'),
  desactivacion('Desactivación'),
  configTarifa('Config. tarifa'),
  otro('Otra');

  const TipoAccion(this.etiqueta);
  final String etiqueta;
}

TipoAccion tipoDeAccion(String codigo) {
  final c = codigo.toUpperCase();
  if (c.contains('DESACT') || c.contains('DEACT')) return TipoAccion.desactivacion;
  if (c.contains('ACTIV')) return TipoAccion.activacion;
  if (c.contains('TARIFF') || c.contains('TARIFA') || c.contains('REAJUSTE')) {
    return TipoAccion.configTarifa;
  }
  if (c.contains('DELETE') || c.contains('ELIMIN')) return TipoAccion.eliminacion;
  if (c.contains('CREATE') || c.contains('CREAR') || c.contains('IMPORT')) {
    return TipoAccion.creacion;
  }
  if (c.contains('EDIT') || c.contains('UPDATE') || c.contains('RESET')) {
    return TipoAccion.actualizacion;
  }
  return TipoAccion.otro;
}

String entidadDeAccion(String codigo, String tipoEntidad) {
  if (tipoEntidad.isNotEmpty) return tipoEntidad;
  final c = codigo.toUpperCase();
  if (c.contains('CONCESION')) return 'Concesionaria';
  if (c.contains('PORTICO') || c.contains('TARIFF') || c.contains('REAJUSTE')) {
    return 'Pórtico';
  }
  if (c.contains('ADMIN')) return 'Administrador';
  if (c.contains('USER') || c.contains('PASSWORD')) return 'Usuario';
  if (c.contains('IMPORT')) return 'Carga masiva';
  if (c.contains('BENEFICIO')) return 'Beneficio';
  return '—';
}

class AuditoriaPage extends StatefulWidget {
  const AuditoriaPage({super.key, required this.service});

  final AdminFirestoreService service;

  @override
  State<AuditoriaPage> createState() => _AuditoriaPageState();
}

class _AuditoriaPageState extends State<AuditoriaPage> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      widget.service.streamAuditLogs();
  String _filtro = 'Todas';
  int _pagina = 0;
  int _porPagina = 20;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 820;
    return SafeArea(
      child: PaginaConEncabezado(
            compact: compact,
            encabezado: EncabezadoPagina(
              titulo: 'Auditoría',
              icono: Icons.shield_outlined,
              subtitulo:
                  'Bitácora de cambios administrativos: qué se modificó y qué usuario lo hizo.',
              acciones: [
                BotonContorno(
                  texto: 'Actualizar',
                  icono: Icons.refresh,
                  onPressed: () => setState(
                    () => _stream = widget.service.streamAuditLogs(),
                  ),
                ),
              ],
            ),
            children: [

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text('Error al leer Firestore: ${snap.error}');
                }
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                // Acepta el formato del panel (action/details/adminEmail) y el
                // de la app móvil (accion/detalle/usuario_id).
                final registros = snap.data!.docs.map((d) {
                  final m = d.data();
                  final codigo = (m['action'] ?? m['accion'] ?? '').toString();
                  return _Registro(
                    fecha: fechaDe(m['fecha']),
                    usuario: (m['adminEmail'] ?? m['usuario_id'] ?? '—').toString(),
                    tipo: tipoDeAccion(codigo),
                    codigo: codigo,
                    entidad: entidadDeAccion(
                      codigo,
                      (m['tipo_entidad'] ?? '').toString(),
                    ),
                    detalle: (m['details'] ?? m['detalle'] ?? m['target'] ?? '')
                        .toString(),
                  );
                }).toList();

                final filtrados = _filtro == 'Todas'
                    ? registros
                    : registros.where((r) => r.tipo.etiqueta == _filtro).toList();
                final paginas = (filtrados.length / _porPagina).ceil();
                if (_pagina >= paginas && paginas > 0) _pagina = paginas - 1;
                final desde = _pagina * _porPagina;
                final hasta = (desde + _porPagina).clamp(0, filtrados.length);
                final pagina = filtrados.sublist(desde, hasta);

                return TarjetaBlanca(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CabeceraListado(
                        titulo: 'Registros recientes',
                        subtitulo: '${filtrados.length} registros',
                        controles: [
                          DesplegableFiltro(
                            valor: _filtro,
                            opciones: [
                              'Todas',
                              ...TipoAccion.values.map((e) => e.etiqueta),
                            ],
                            etiquetas: const {'Todas': 'Todas las acciones'},
                            ancho: 200,
                            onChanged: (v) => setState(() {
                              _filtro = v;
                              _pagina = 0;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (filtrados.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No hay registros.')),
                        )
                      else
                        TablaSimple(
                          encabezados: const [
                            'Fecha',
                            'Usuario',
                            'Acción',
                            'Entidad',
                            'Detalle',
                          ],
                          anchos: const [250, 150, 130, 420],
                          filas: [
                            for (final r in pagina)
                              [
                                Text(
                                  r.fecha == null ? '—' : fechaHora(r.fecha!),
                                  style: const TextStyle(color: kGris, fontSize: 13),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _siglas(r.usuario),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: kTinta,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        r.usuario,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: kTinta,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                _EtiquetaAccion(tipo: r.tipo, codigo: r.codigo),
                                Text(
                                  r.entidad,
                                  style: const TextStyle(color: kTinta, fontSize: 14.5),
                                ),
                                Text(
                                  r.detalle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: kGris, fontSize: 14),
                                ),
                              ],
                          ],
                        ),
                      const Divider(),
                      Paginador(
                        pagina: _pagina,
                        porPagina: _porPagina,
                        total: filtrados.length,
                        etiqueta: 'registros',
                        onPagina: (n) => setState(() => _pagina = n),
                        onPorPagina: (n) => setState(() {
                          _porPagina = n;
                          _pagina = 0;
                        }),
                      ),
                    ],
                  ),
                );
              },
            ),
          
            ],
          ),
    );
  }

  static String _siglas(String correo) {
    final local = correo.split('@').first;
    final p = local.split(RegExp(r'[._\-]+')).where((e) => e.isNotEmpty).toList();
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return local.length >= 2 ? local.substring(0, 2).toUpperCase() : local.toUpperCase();
  }
}

class _Registro {
  const _Registro({
    required this.fecha,
    required this.usuario,
    required this.tipo,
    required this.codigo,
    required this.entidad,
    required this.detalle,
  });

  final DateTime? fecha;
  final String usuario;
  final TipoAccion tipo;
  final String codigo;
  final String entidad;
  final String detalle;
}

class _EtiquetaAccion extends StatelessWidget {
  const _EtiquetaAccion({required this.tipo, required this.codigo});

  final TipoAccion tipo;
  final String codigo;

  @override
  Widget build(BuildContext context) {
    final texto = tipo == TipoAccion.otro && codigo.isNotEmpty
        ? codigo.toLowerCase().replaceAll('_', ' ')
        : tipo.etiqueta;
    switch (tipo) {
      case TipoAccion.creacion:
        return Pildora(texto, fondo: kAzul, colorTexto: Colors.white);
      case TipoAccion.eliminacion:
        return Pildora(
          texto,
          fondo: const Color(0xFFFFE4E6),
          colorTexto: const Color(0xFFDC2626),
        );
      case TipoAccion.desactivacion:
        return Pildora(texto, fondo: Colors.white, borde: kBorde);
      default:
        return Pildora(texto);
    }
  }
}
