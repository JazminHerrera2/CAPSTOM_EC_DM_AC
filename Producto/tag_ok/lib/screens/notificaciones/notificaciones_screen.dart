import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/notificacion_config_model.dart';
import '../../data/services/aviso_navegador_service.dart';
import '../../data/services/notificacion_service.dart';
import '../../utils/notificacion_navegador.dart';

/// Un aviso "ya toca" cuando su fecha programada es hoy o anterior.
bool avisoYaCorresponde(NotificacionConfigModel n, DateTime ahora) {
  final fecha = n.fechaProgramada;
  if (fecha == null) return true;
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  return !DateTime(fecha.year, fecha.month, fecha.day).isAfter(hoy);
}

/// Campana con contador de avisos sin leer. Abre la bandeja.
class CampanaNotificaciones extends StatelessWidget {
  const CampanaNotificaciones({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<NotificacionConfigModel>>(
      stream: NotificacionService().escucharDelUsuario(uid),
      builder: (context, snapshot) {
        final ahora = DateTime.now();
        final sinLeer = (snapshot.data ?? const <NotificacionConfigModel>[])
            .where((n) => !n.leida && avisoYaCorresponde(n, ahora))
            .length;

        return IconButton(
          tooltip: 'Notificaciones',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificacionesScreen()),
          ),
          icon: Badge(
            isLabelVisible: sinLeer > 0,
            label: Text(sinLeer > 9 ? '9+' : '$sinLeer'),
            child: const Icon(
              Icons.notifications_outlined,
              color: Color(0xFFF8FAFC),
              size: 28,
            ),
          ),
        );
      },
    );
  }
}

/// Bandeja de avisos: vencimiento de documentos del vehículo y recordatorios
/// de mantenciones programadas.
class NotificacionesScreen extends StatelessWidget {
  const NotificacionesScreen({super.key});

  static const Color _bgColor = Color(0xFF0F172A);
  static const Color _surfaceColor = Color(0xFF1E293B);
  static const Color _textMain = Color(0xFFF8FAFC);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _primaryColor = Color(0xFF4F46E5);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final servicio = NotificacionService();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        foregroundColor: _textMain,
        elevation: 0,
        title: const Text('Notificaciones'),
      ),
      body: uid == null
          ? const Center(
              child: Text(
                'Inicia sesión para ver tus notificaciones.',
                style: TextStyle(color: _textMuted),
              ),
            )
          : StreamBuilder<List<NotificacionConfigModel>>(
              stream: servicio.escucharDelUsuario(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'No se pudieron cargar las notificaciones.',
                      style: TextStyle(color: _textMuted),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final ahora = DateTime.now();
                // Los avisos programados a futuro no se listan aquí: siguen
                // agendados y aparecen en la bandeja cuando llega su fecha.
                final recientes = snapshot.data!
                    .where((n) => avisoYaCorresponde(n, ahora))
                    .toList();
                final sinLeer = recientes.where((n) => !n.leida).toList();

                if (recientes.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No tienes avisos. Te avisaremos 30, 15 y 7 días antes '
                        'del vencimiento de tus documentos, y 7 días antes y '
                        'el mismo día de tus mantenciones programadas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _textMuted),
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _BannerPermisoNavegador(usuarioId: uid),
                    if (sinLeer.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => servicio.marcarTodasLeidas(
                            sinLeer.map((n) => n.id),
                          ),
                          icon: const Icon(Icons.done_all, size: 18),
                          label: const Text('Marcar todas como leídas'),
                        ),
                      ),
                    const _Titulo('Recientes'),
                    for (final n in recientes)
                      _TarjetaAviso(
                        aviso: n,
                        onTap: n.leida ? null : () => servicio.marcarLeida(n.id),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

/// Invita a activar las notificaciones del navegador (solo web, y solo si
/// aún no se decidió). El permiso se pide desde el botón porque los
/// navegadores exigen un gesto del usuario.
class _BannerPermisoNavegador extends StatefulWidget {
  const _BannerPermisoNavegador({required this.usuarioId});
  final String usuarioId;

  @override
  State<_BannerPermisoNavegador> createState() =>
      _BannerPermisoNavegadorState();
}

class _BannerPermisoNavegadorState extends State<_BannerPermisoNavegador> {
  late String _permiso = permisoNotificacionNavegador;

  Future<void> _activar() async {
    final resultado = await pedirPermisoNotificacionNavegador();
    if (!mounted) return;
    setState(() => _permiso = resultado);
    if (resultado == 'granted') {
      await AvisoNavegadorService.instance.revisar(widget.usuarioId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_permiso != 'default') return const SizedBox.shrink();

    return Card(
      color: NotificacionesScreen._surfaceColor,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.notifications_active_outlined,
            color: Color(0xFFF59E0B)),
        title: const Text(
          'Activa los avisos del navegador',
          style: TextStyle(color: NotificacionesScreen._textMain),
        ),
        subtitle: const Text(
          'Te avisaremos de documentos por vencer y mantenciones programadas '
          'mientras tengas la app abierta.',
          style: TextStyle(color: NotificacionesScreen._textMuted),
        ),
        trailing: TextButton(onPressed: _activar, child: const Text('Activar')),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          color: NotificacionesScreen._textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TarjetaAviso extends StatelessWidget {
  const _TarjetaAviso({
    required this.aviso,
    this.onTap,
  });

  final NotificacionConfigModel aviso;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fecha = aviso.fechaProgramada;
    final noLeida = !aviso.leida;
    final cuando = fecha == null
        ? ''
        : DateFormat('dd/MM/yyyy').format(fecha);

    return Card(
      color: NotificacionesScreen._surfaceColor,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: noLeida
              ? NotificacionesScreen._primaryColor
              : Colors.transparent,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          aviso.tipo == tipoAvisoMantencion
              ? Icons.build_circle_outlined
              : Icons.event_busy_outlined,
          color: noLeida
              ? const Color(0xFFF59E0B)
              : NotificacionesScreen._textMuted,
        ),
        title: Text(
          aviso.mensaje,
          style: TextStyle(
            color: NotificacionesScreen._textMain,
            fontWeight: noLeida ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          cuando,
          style: const TextStyle(color: NotificacionesScreen._textMuted),
        ),
        trailing: noLeida
            ? const Icon(Icons.circle, size: 10, color: Color(0xFF4F46E5))
            : null,
      ),
    );
  }
}
