import 'package:flutter/material.dart';

import 'admin_ui.dart';
import 'porticos_paneles.dart';

const String _super = 'super_admin';
const String _operador = 'operador';

const Map<String, String> _nombres = {
  _super: 'Super Administrador',
  _operador: 'Administrador Operacional',
};

String _descripcion(String rol) => rol == _super
    ? 'Control total del sistema: usuarios, concesionarios, administradores y beneficios.'
    : 'Dashboard, mapa, pórticos, tarifas y reportes.';

// ---------------------------------------------------------------------------
// Nuevo administrador
// ---------------------------------------------------------------------------

typedef DatosNuevoAdmin = ({String email, String password, String rol});

Future<DatosNuevoAdmin?> mostrarPanelNuevoAdmin(BuildContext context) {
  return mostrarPanelLateral<DatosNuevoAdmin>(
    context,
    ancho: 460,
    builder: (_) => const _PanelNuevoAdmin(),
  );
}

class _PanelNuevoAdmin extends StatefulWidget {
  const _PanelNuevoAdmin();

  @override
  State<_PanelNuevoAdmin> createState() => _PanelNuevoAdminState();
}

class _PanelNuevoAdminState extends State<_PanelNuevoAdmin> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  String _rol = _operador;
  String? _errorEmail;
  String? _errorPass;
  bool _ver = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _crear() {
    final email = _email.text.trim();
    setState(() {
      if (email.isEmpty) {
        _errorEmail = 'El correo es obligatorio.';
      } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
        _errorEmail = 'Ingresa un correo electrónico válido.';
      } else {
        _errorEmail = null;
      }
      if (_pass.text.isEmpty) {
        _errorPass = 'La contraseña es obligatoria.';
      } else if (_pass.text.length < 6) {
        _errorPass = 'Mínimo 6 caracteres.';
      } else {
        _errorPass = null;
      }
    });
    if (_errorEmail != null || _errorPass != null) return;
    Navigator.of(context).pop((email: email, password: _pass.text, rol: _rol));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CabeceraPanel(
          titulo: 'Nuevo administrador',
          subtitulo: Text(
            'Crea una cuenta con acceso al panel de administración.',
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            children: [
              CampoEtiquetado(
                etiqueta: 'Correo electrónico',
                controller: _email,
                hint: 'Ej: nombre@tagok.cl',
                teclado: TextInputType.emailAddress,
                error: _errorEmail,
                autofocus: true,
                onChanged: (_) {
                  if (_errorEmail != null) setState(() => _errorEmail = null);
                },
              ),
              const SizedBox(height: 18),
              Stack(
                alignment: Alignment.topRight,
                children: [
                  CampoEtiquetado(
                    etiqueta: 'Contraseña',
                    controller: _pass,
                    hint: 'Mínimo 6 caracteres',
                    oculto: !_ver,
                    error: _errorPass,
                    onChanged: (_) {
                      if (_errorPass != null) setState(() => _errorPass = null);
                    },
                  ),
                  TextButton(
                    onPressed: () => setState(() => _ver = !_ver),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(10, 22),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(_ver ? 'Ocultar' : 'Mostrar'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Rol',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kTinta,
                ),
              ),
              const SizedBox(height: 6),
              SelectorAcordeon(
                valor: _rol,
                opciones: const [_super, _operador],
                etiquetas: _nombres,
                compacto: true,
                onChanged: (v) => setState(() => _rol = v),
              ),
              const SizedBox(height: 8),
              Text(
                _descripcion(_rol),
                style: const TextStyle(color: kGris, fontSize: 13),
              ),
            ],
          ),
        ),
        PiePanel(
          textoPrincipal: 'Crear administrador',
          iconoPrincipal: Icons.person_add_alt_1_outlined,
          onPrincipal: _crear,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Cambiar rol
// ---------------------------------------------------------------------------

Future<String?> mostrarPanelRolAdmin(
  BuildContext context, {
  required String email,
  required String rolActual,
}) {
  return mostrarPanelLateral<String>(
    context,
    ancho: 460,
    builder: (_) => _PanelRolAdmin(email: email, rolActual: rolActual),
  );
}

class _PanelRolAdmin extends StatefulWidget {
  const _PanelRolAdmin({required this.email, required this.rolActual});

  final String email;
  final String rolActual;

  @override
  State<_PanelRolAdmin> createState() => _PanelRolAdminState();
}

class _PanelRolAdminState extends State<_PanelRolAdmin> {
  late String _rol = widget.rolActual;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CabeceraPanel(
          titulo: 'Cambiar rol',
          subtitulo: Text('Define qué puede hacer ${widget.email} en el panel.'),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            children: [
              const Text(
                'Rol',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kTinta,
                ),
              ),
              const SizedBox(height: 6),
              SelectorAcordeon(
                valor: _rol,
                opciones: const [_super, _operador],
                etiquetas: _nombres,
                compacto: true,
                onChanged: (v) => setState(() => _rol = v),
              ),
              const SizedBox(height: 8),
              Text(
                _descripcion(_rol),
                style: const TextStyle(color: kGris, fontSize: 13),
              ),
            ],
          ),
        ),
        PiePanel(
          textoPrincipal: 'Guardar cambios',
          iconoPrincipal: Icons.save_outlined,
          onPrincipal: _rol == widget.rolActual
              ? null
              : () => Navigator.of(context).pop(_rol),
        ),
      ],
    );
  }
}
