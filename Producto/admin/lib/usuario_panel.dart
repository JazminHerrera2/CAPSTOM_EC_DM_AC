import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_firestore_service.dart';
import 'admin_ui.dart';
import 'usuarios_tabla.dart';

const String _sinAcceso = 'sin_acceso';
const String _operador = 'operador';
const String _superAdmin = 'super_admin';

String _claveRol(String? rol) {
  if (rol == null) return _sinAcceso;
  final r = rol.toLowerCase().trim();
  const supers = {
    'super_admin',
    'super_administrador',
    'superadmin',
    'super administrador',
  };
  return supers.contains(r) ? _superAdmin : _operador;
}

String _nombreRol(String clave) => switch (clave) {
  _superAdmin => 'Super Administrador',
  _operador => 'Administrador Operacional',
  _ => 'Sin acceso al panel',
};

String _descripcionRol(String clave) => switch (clave) {
  _superAdmin => 'Control total del sistema.',
  _operador => 'Dashboard, mapa, pórticos, tarifas y reportes.',
  _ => 'No puede entrar al panel de administración.',
};

Future<void> mostrarPanelUsuario(
  BuildContext context, {
  required FilaUsuario usuario,
  required DateTime ahora,
}) {
  return mostrarPanelLateral<void>(
    context,
    builder: (ctx) => _PanelUsuario(usuario: usuario, ahora: ahora),
  );
}

class _PanelUsuario extends StatefulWidget {
  const _PanelUsuario({required this.usuario, required this.ahora});

  final FilaUsuario usuario;
  final DateTime ahora;

  @override
  State<_PanelUsuario> createState() => _PanelUsuarioState();
}

class _PanelUsuarioState extends State<_PanelUsuario> {
  final AdminFirestoreService _service = AdminFirestoreService();
  bool get _activo => widget.usuario.activo;
  late String _rol = _claveRol(widget.usuario.rol);
  bool _guardando = false;

  bool get _esUnoMismo =>
      FirebaseAuth.instance.currentUser?.uid == widget.usuario.docId;

  Future<void> _cambiarRol(String nuevo) async {
    final previo = _rol;
    setState(() {
      _rol = nuevo;
      _guardando = true;
    });
    try {
      final ref = FirebaseFirestore.instance
          .collection('administradores')
          .doc(widget.usuario.docId);
      if (nuevo == _sinAcceso) {
        await ref.delete();
      } else {
        await ref.set({
          'rol': nuevo,
          'email': widget.usuario.correo,
        }, SetOptions(merge: true));
      }
      await _service.logAction(
        action: nuevo == _sinAcceso ? 'DELETE_ADMIN' : 'EDIT_ADMIN_ROLE',
        target: widget.usuario.correo,
        details: 'Rol en el panel: ${_nombreRol(previo)} -> ${_nombreRol(nuevo)}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _rol = previo);
      avisar(
        context,
        'No se pudo cambiar el rol (solo un super administrador puede, y no sobre su propia cuenta): $e',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _restablecer() async {
    final correo = widget.usuario.correo;
    if (correo == 'Sin correo') {
      avisar(context, 'Este usuario no tiene correo registrado.', error: true);
      return;
    }
    setState(() => _guardando = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: correo);
      await _service.logAction(
        action: 'RESET_PASSWORD',
        target: correo,
        details: 'Se envió un correo de restablecimiento de contraseña.',
      );
      if (mounted) avisar(context, 'Correo de restablecimiento enviado a $correo');
    } catch (e) {
      if (mounted) avisar(context, 'Error al enviar el correo: $e', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar() async {
    final u = widget.usuario;
    final ok = await confirmar(
      context,
      titulo: 'Eliminar usuario',
      mensaje:
          '¿Eliminar el registro y los datos de ${u.correo}? Esta acción es irreversible.',
      confirmar: 'Sí, eliminar',
      peligro: true,
    );
    if (!ok || !mounted) return;
    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(u.docId).delete();
      await _service.logAction(
        action: 'DELETE_USER',
        target: u.correo,
        details: 'Se eliminó definitivamente el usuario y sus datos.',
      );
      if (!mounted) return;
      avisar(context, 'Usuario eliminado.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        avisar(context, 'No se pudo eliminar el usuario: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.usuario;
    final partes = u.correo
        .split('@')
        .first
        .split(RegExp(r'[._\-]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final iniciales = partes.length >= 2
        ? '${partes[0][0]}${partes[1][0]}'.toUpperCase()
        : u.correo.substring(0, u.correo.length >= 2 ? 2 : 1).toUpperCase();

    final contenido = ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: kBorde),
              ),
              child: Text(
                iniciales,
                style: const TextStyle(
                  color: kGris,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    u.correo,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: kTinta,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Pildora(_activo ? 'Activo' : 'Inactivo',
                          fondo: _activo
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFFFFE4E6),
                          colorTexto:
                              _activo ? kTinta : const Color(0xFFDC2626)),
                      if (_rol != _sinAcceso)
                        Pildora(
                          _nombreRol(_rol),
                          fondo: Colors.white,
                          borde: kBorde,
                          icono: Icons.verified_user_outlined,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, size: 22),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _Bloque(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rol en el panel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kTinta,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Define qué módulos del panel puede usar.',
                style: TextStyle(color: kGris, fontSize: 13.5),
              ),
              const SizedBox(height: 14),
              SelectorAcordeon(
                valor: _rol,
                opciones: const [_superAdmin, _operador, _sinAcceso],
                etiquetas: {
                  for (final c in [_superAdmin, _operador, _sinAcceso])
                    c: _nombreRol(c),
                },
                deshabilitado: _guardando || _esUnoMismo,
                onChanged: (v) {
                  if (v != _rol) _cambiarRol(v);
                },
              ),
              const SizedBox(height: 10),
              Text(
                _esUnoMismo
                    ? 'No puedes cambiar tu propio rol.'
                    : _descripcionRol(_rol),
                style: const TextStyle(color: kGris, fontSize: 13.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          'INFORMACIÓN',
          style: TextStyle(
            color: kGris,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 14),
        _DatoInfo(icono: Icons.mail_outline, etiqueta: 'Correo', valor: u.correo),
        _DatoInfo(
          icono: Icons.tag,
          etiqueta: 'ID',
          valor: u.docId,
          monoespaciado: true,
        ),
        _DatoInfo(
          icono: Icons.calendar_month_outlined,
          etiqueta: 'Registrado',
          valor: u.registrado == null ? '—' : fechaCorta(u.registrado!),
        ),
        _DatoInfo(
          icono: Icons.schedule,
          etiqueta: 'Última actividad',
          valor: u.ultimaActividad == null
              ? '—'
              : fechaHoraRelativa(u.ultimaActividad!, widget.ahora),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Divider(color: kBorde),
        ),
        Row(
          children: [
            const Expanded(
              child: Text(
                'VEHÍCULOS ASOCIADOS',
                style: TextStyle(
                  color: kGris,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            Pildora(
              '${u.vehiculos.length}',
              fondo: Colors.white,
              borde: kBorde,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (u.vehiculos.isEmpty)
          const Text(
            'Este usuario no tiene vehículos registrados.',
            style: TextStyle(color: kGris, fontSize: 14),
          )
        else
          for (final v in u.vehiculos) _TarjetaVehiculo(datos: v),
      ],
    );

    return Column(
      children: [
        Expanded(child: contenido),
        const Divider(height: 1, color: kBorde),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _guardando ? null : _restablecer,
                  icon: const Icon(Icons.lock_reset_outlined, size: 18),
                  label: const Text('Restablecer contraseña'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_guardando || _esUnoMismo) ? null : _eliminar,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(_esUnoMismo ? 'Tu cuenta' : 'Eliminar usuario'),
                  style: FilledButton.styleFrom(backgroundColor: kRojo),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kBorde),
    ),
    child: child,
  );
}

class _DatoInfo extends StatelessWidget {
  const _DatoInfo({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    this.monoespaciado = false,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final bool monoespaciado;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 20, color: kGris),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etiqueta, style: const TextStyle(color: kGris, fontSize: 13)),
              const SizedBox(height: 2),
              SelectableText(
                valor,
                style: TextStyle(
                  color: kTinta,
                  fontSize: monoespaciado ? 12 : 16,
                  fontFamily: monoespaciado ? 'monospace' : null,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TarjetaVehiculo extends StatelessWidget {
  const _TarjetaVehiculo({required this.datos});

  final Map<String, dynamic> datos;

  String _t(String k) => (datos[k] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final tipo = _t('tipo').isNotEmpty ? _t('tipo') : 'Automóvil';
    final categoria = _t('categoria').isNotEmpty
        ? _t('categoria')
        : (_t('categoria_tag').isNotEmpty ? _t('categoria_tag') : 'sin categoría');
    final modelo = [_t('marca'), _t('modelo'), _t('anio')]
        .where((e) => e.isNotEmpty)
        .join(' ');
    final alias = _t('alias').isNotEmpty ? _t('alias') : _t('apodo');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorde),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.directions_car_outlined, color: kTinta),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('patente'),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: kTinta,
                  ),
                ),
                Text(
                  '$tipo · Categoría $categoria',
                  style: const TextStyle(color: kGris, fontSize: 13.5),
                ),
                if (modelo.isNotEmpty || alias.isNotEmpty)
                  Text(
                    alias.isNotEmpty ? alias : modelo,
                    style: const TextStyle(
                      color: kGris,
                      fontSize: 13.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
