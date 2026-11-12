import 'package:flutter/material.dart';

import 'dashboard_page.dart' show haceCuanto;

const Color _tinta = Color(0xFF0F172A);
const Color _gris = Color(0xFF64748B);
const Color _borde = Color(0xFFE2E8F0);

/// Datos de un usuario ya combinados (perfil, rol de admin, vehículos y
/// actividad) para dibujar una fila del listado.
class FilaUsuario {
  const FilaUsuario({
    required this.docId,
    required this.nombre,
    required this.correo,
    required this.presupuesto,
    required this.rol,
    required this.patentes,
    required this.registrado,
    required this.ultimaActividad,
    required this.activo,
    this.vehiculos = const [],
  });

  final String docId;
  final String nombre;
  final String correo;
  final int presupuesto;

  /// Rol de administrador si el correo está en `administradores`; si no, null.
  final String? rol;
  final List<String> patentes;
  final DateTime? registrado;

  /// Fecha del último viaje del usuario.
  final DateTime? ultimaActividad;
  final bool activo;

  /// Documentos completos de los vehículos del usuario (para el panel).
  final List<Map<String, dynamic>> vehiculos;
}

class TablaUsuarios extends StatelessWidget {
  const TablaUsuarios({
    super.key,
    required this.filas,
    required this.ahora,
    required this.onAbrir,
  });

  final void Function(FilaUsuario) onAbrir;
  final List<FilaUsuario> filas;
  final DateTime ahora;

  static const double _wEstado = 110;
  static const double _wRol = 210;
  static const double _wVehiculos = 200;
  static const double _wRegistrado = 130;
  static const double _wActividad = 150;
  static const double _wAcciones = 70;
  static const double _minUsuario = 260;

  static const double _minTotal =
      _minUsuario +
      _wEstado +
      _wRol +
      _wVehiculos +
      _wRegistrado +
      _wActividad +
      _wAcciones;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final ancho = c.maxWidth < _minTotal ? _minTotal : c.maxWidth;
        final tabla = SizedBox(
          width: ancho,
          child: Column(
            children: [
              _fila(
                esEncabezado: true,
                usuario: const _Encabezado('Usuario'),
                estado: const _Encabezado('Estado'),
                rol: const _Encabezado('Rol'),
                vehiculos: const _Encabezado('Vehículos'),
                registrado: const _Encabezado('Registrado'),
                actividad: const _Encabezado('Última actividad'),
                acciones: const SizedBox.shrink(),
              ),
              for (final f in filas)
                InkWell(onTap: () => onAbrir(f), child: _filaDe(f)),
            ],
          ),
        );
        if (c.maxWidth >= _minTotal) return tabla;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: tabla,
        );
      },
    );
  }

  Widget _fila({
    required bool esEncabezado,
    required Widget usuario,
    required Widget estado,
    required Widget rol,
    required Widget vehiculos,
    required Widget registrado,
    required Widget actividad,
    required Widget acciones,
  }) {
    Widget celda(double w, Widget child) =>
        SizedBox(width: w, child: Align(alignment: Alignment.centerLeft, child: child));
    return Container(
      padding: EdgeInsets.symmetric(vertical: esEncabezado ? 10 : 9, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _borde, width: esEncabezado ? 1 : 0.8),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: usuario),
          celda(_wEstado, estado),
          celda(_wRol, rol),
          celda(_wVehiculos, vehiculos),
          celda(_wRegistrado, registrado),
          celda(_wActividad, actividad),
          celda(_wAcciones, acciones),
        ],
      ),
    );
  }

  Widget _filaDe(FilaUsuario f) {
    return _fila(
      esEncabezado: false,
      usuario: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFFF1F5F9),
            child: Text(
              _iniciales(f.correo),
              style: const TextStyle(
                color: _gris,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              f.correo,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _tinta,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      estado: _PildoraEstado(activo: f.activo),
      rol: _PildoraRol(rol: f.rol),
      vehiculos: _CeldaVehiculos(patentes: f.patentes),
      registrado: Text(
        f.registrado == null ? '—' : haceCuanto(f.registrado, ahora),
        style: const TextStyle(color: _gris, fontSize: 14),
      ),
      actividad: Text(
        f.ultimaActividad == null ? '—' : haceCuanto(f.ultimaActividad, ahora),
        style: const TextStyle(color: _tinta, fontSize: 14),
      ),
      acciones: IconButton(
        tooltip: 'Ver detalle',
        icon: const Icon(Icons.visibility_outlined, color: _tinta, size: 20),
        onPressed: () => onAbrir(f),
      ),
    );
  }
}

String _iniciales(String correo) {
  final local = correo.split('@').first;
  final partes = local
      .split(RegExp(r'[._\-]+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (partes.length >= 2) {
    return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
  }
  if (local.length >= 2) return local.substring(0, 2).toUpperCase();
  return local.isEmpty ? 'U' : local.toUpperCase();
}

class _Encabezado extends StatelessWidget {
  const _Encabezado(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: const TextStyle(
      color: _tinta,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _PildoraEstado extends StatelessWidget {
  const _PildoraEstado({required this.activo});

  final bool activo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: activo ? const Color(0xFFF1F5F9) : const Color(0xFFFFE4E6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        activo ? 'Activo' : 'Inactivo',
        style: TextStyle(
          color: activo ? _tinta : const Color(0xFFDC2626),
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PildoraRol extends StatelessWidget {
  const _PildoraRol({required this.rol});

  final String? rol;

  @override
  Widget build(BuildContext context) {
    if (rol == null) {
      return const Text('—', style: TextStyle(color: _gris, fontSize: 14));
    }
    final r = rol!.toLowerCase().trim();
    final esSuper =
        r == 'super_admin' ||
        r == 'super_administrador' ||
        r == 'superadmin' ||
        r == 'super administrador';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: esSuper ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_user_outlined, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            esSuper ? 'Super Administrador' : 'Administrador Operacional',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CeldaVehiculos extends StatelessWidget {
  const _CeldaVehiculos({required this.patentes});

  final List<String> patentes;

  @override
  Widget build(BuildContext context) {
    if (patentes.isEmpty) {
      return const Text('—', style: TextStyle(color: _gris, fontSize: 14));
    }
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borde),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_car_outlined, size: 14, color: _tinta),
              const SizedBox(width: 5),
              Text(
                '${patentes.length}',
                style: const TextStyle(
                  color: _tinta,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            patentes.join(', '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _gris,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
