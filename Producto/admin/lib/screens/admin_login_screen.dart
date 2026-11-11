import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// Pantalla de inicio de sesión del panel admin: solo presentación.
///
/// No conoce Firebase. Al enviar el formulario llama a [onLogin] con el correo
/// y la contraseña escritos; esa función devuelve `null` si el ingreso salió
/// bien o el mensaje de error que se muestra bajo los campos. Quién valida las
/// credenciales y si la cuenta es de administrador lo decide la lógica que la
/// usa (ver `LoginScreen` en `login_screen.dart`).
///
/// Ancho >= [anchoDosPaneles]: panel azul (5) y formulario (4). Más angosto:
/// solo el formulario, con el logo arriba.
class AdminLoginScreen extends StatefulWidget {
  /// Devuelve `null` si el ingreso fue correcto, o el mensaje de error.
  final Future<String?> Function(String email, String password) onLogin;

  /// Error a mostrar desde el inicio (p. ej. "Acceso denegado...").
  final String? errorMessage;

  const AdminLoginScreen({
    super.key,
    required this.onLogin,
    this.errorMessage,
  });

  static const double anchoDosPaneles = 900;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

// Azules de la pantalla de referencia.
const Color _azulClaro = Color(0xFF1F4FE0);
const Color _azulOscuro = Color(0xFF0A2C9E);
const Color _azulBoton = Color(0xFF0B3FD0);
const Color _textoPrincipal = Color(0xFF0F172A);
const Color _textoGris = Color(0xFF64748B);
const Color _campoFondo = Color(0xFFF4F5F7);

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  bool _cargando = false;
  bool _verPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.errorMessage;
    _anim.repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_cargando) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    String? error;
    try {
      error = await widget.onLogin(_emailCtrl.text, _passwordCtrl.text);
    } catch (_) {
      error = 'Ocurrió un error inesperado.';
    }
    // Si el ingreso fue correcto, la pantalla suele ser reemplazada.
    if (!mounted) return;
    setState(() {
      _error = error;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, c) {
          final dos = c.maxWidth >= AdminLoginScreen.anchoDosPaneles;
          if (!dos) return _panelFormulario(conLogo: true);
          return Row(
            children: [
              Expanded(flex: 5, child: _panelAzul()),
              Expanded(flex: 4, child: _panelFormulario(conLogo: false)),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------
  // Panel izquierdo (azul)
  // ------------------------------------------------------------------

  Widget _panelAzul() {
    return ClipRect(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [_azulClaro, _azulOscuro],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Línea punteada animada, detrás del contenido.
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (_, _) => CustomPaint(
                      painter: _LineaPunteadaPainter(_anim.value),
                    ),
                  ),
                ),
              ),
            ),
            CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(48, 40, 48, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const _Logo(ancho: 112, blanco: true),
                            Container(
                              width: 1,
                              height: 22,
                              margin: const EdgeInsets.symmetric(horizontal: 14),
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                            Text(
                              'Panel administrador',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Text(
                          'Gestiona tus peajes\ncon claridad y control.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Text(
                            'Autopistas, pórticos, tarifas y reportes en un solo '
                            'lugar. Visualiza rutas y administra la red TAG OK '
                            'de Santiago.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const _Caracteristica(
                          icono: Icons.location_on_outlined,
                          texto: 'Pórticos y tarifas geolocalizados sobre el mapa',
                        ),
                        const SizedBox(height: 14),
                        const _Caracteristica(
                          icono: Icons.bar_chart_rounded,
                          texto: 'Reportes de cruces y recaudación al instante',
                        ),
                        const Spacer(),
                        Text(
                          '© 2026 TAG OK · Santiago de Chile',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Panel derecho (formulario)
  // ------------------------------------------------------------------

  Widget _panelFormulario({required bool conLogo}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (conLogo) ...[
                const Center(child: _Logo(ancho: 120, blanco: false)),
                const SizedBox(height: 24),
              ],
              const Text(
                'Bienvenido de vuelta',
                style: TextStyle(
                  color: _textoPrincipal,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ingresa tus credenciales para acceder al panel.',
                style: TextStyle(color: _textoGris, fontSize: 14),
              ),
              const SizedBox(height: 28),
              _campo(
                controller: _emailCtrl,
                etiqueta: 'Correo electrónico',
                hint: 'correo@ejemplo.com',
                icono: Icons.mail_outline,
                tipo: TextInputType.emailAddress,
                accion: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              _campo(
                controller: _passwordCtrl,
                etiqueta: 'Contraseña',
                hint: '••••••••',
                icono: Icons.lock_outline,
                oculto: !_verPassword,
                accion: TextInputAction.done,
                alEnviar: (_) => _enviar(),
                sufijo: IconButton(
                  tooltip: _verPassword ? 'Ocultar contraseña' : 'Ver contraseña',
                  icon: Icon(
                    _verPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: _textoGris,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _verPassword = !_verPassword),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _cargando ? null : _enviar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _azulBoton,
                    disabledBackgroundColor: _azulBoton.withValues(alpha: 0.6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _cargando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campo({
    required TextEditingController controller,
    required IconData icono,
    required String etiqueta,
    required String hint,
    TextInputType? tipo,
    bool oculto = false,
    TextInputAction? accion,
    ValueChanged<String>? alEnviar,
    Widget? sufijo,
  }) {
    OutlineInputBorder borde(Color color, double ancho) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: ancho),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(
            color: _textoPrincipal,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: oculto,
          keyboardType: tipo,
          textInputAction: accion,
          onSubmitted: alEnviar,
          style: const TextStyle(color: _textoPrincipal, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _textoGris.withValues(alpha: 0.7), fontSize: 14),
            filled: true,
            fillColor: _campoFondo,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            prefixIcon: Icon(icono, color: _textoGris, size: 20),
            suffixIcon: sufijo,
            border: borde(Colors.transparent, 0),
            enabledBorder: borde(Colors.transparent, 0),
            focusedBorder: borde(_azulBoton, 1.5),
          ),
        ),
      ],
    );
  }
}

class _Caracteristica extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Caracteristica({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icono, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            texto,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// Logo de TAG OK. El archivo trae mucho margen transparente, así que se
/// recorta para que [ancho] sea casi el ancho visible del logo. Con [blanco]
/// se tiñe de blanco (para fondos azules).
class _Logo extends StatelessWidget {
  final double ancho;
  final bool blanco;
  const _Logo({required this.ancho, required this.blanco});

  @override
  Widget build(BuildContext context) {
    // El logo ocupa ~82 % del ancho y ~48 % del alto del archivo (3:2).
    final anchoImagen = ancho / 0.82;
    final altoImagen = anchoImagen * 2 / 3;
    Widget imagen = Image.asset(
      'assets/logo_tagok.png',
      width: anchoImagen,
      height: altoImagen,
      fit: BoxFit.contain,
      semanticLabel: 'TAG OK',
      errorBuilder: (_, _, _) => SizedBox(
        width: anchoImagen,
        height: altoImagen,
        child: Center(
          child: Text(
            'TAG OK',
            style: TextStyle(
              color: blanco ? Colors.white : _textoPrincipal,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
    if (blanco) {
      imagen = ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        child: imagen,
      );
    }
    return SizedBox(
      width: ancho,
      height: altoImagen * 0.5,
      child: FittedBox(
        fit: BoxFit.none,
        child: ClipRect(
          child: Align(
            widthFactor: 0.82,
            heightFactor: 0.5,
            child: imagen,
          ),
        ),
      ),
    );
  }
}

/// Curva en S de arriba a la derecha hacia abajo a la izquierda, dibujada con
/// trazos que avanzan a lo largo de ella. Con [progreso] de 0 a 1 los trazos
/// se desplazan exactamente [_ciclos] períodos, así que el bucle no se nota.
class _LineaPunteadaPainter extends CustomPainter {
  final double progreso;
  _LineaPunteadaPainter(this.progreso);

  static const double _trazo = 16;
  static const double _hueco = 14;
  static const int _ciclos = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final camino = Path()
      ..moveTo(w * 0.80, -10)
      ..cubicTo(w * 0.88, h * 0.30, w * 0.50, h * 0.34, w * 0.52, h * 0.58)
      ..cubicTo(w * 0.54, h * 0.82, w * 0.18, h * 0.78, w * 0.10, h + 10);

    final pincel = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const periodo = _trazo + _hueco;
    final desplazamiento = progreso * _ciclos * periodo;
    for (final PathMetric m in camino.computeMetrics()) {
      for (var d = desplazamiento - periodo; d < m.length; d += periodo) {
        final inicio = math.max(0.0, d);
        final fin = math.min(m.length, d + _trazo);
        if (fin > inicio) {
          canvas.drawPath(m.extractPath(inicio, fin), pincel);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_LineaPunteadaPainter old) => old.progreso != progreso;
}
