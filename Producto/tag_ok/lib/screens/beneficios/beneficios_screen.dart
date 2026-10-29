import 'package:flutter/material.dart';

import '../../data/models/beneficio_model.dart';
import '../../data/services/beneficio_service.dart';
import '../dashboard/dashboard_logica.dart';
import '../dashboard/encabezado_tag_ok.dart';
import 'detalle_beneficio_screen.dart';
import 'imagen_beneficio.dart';

/// Catálogo de beneficios (RF-030, RF-033, RF-034): solo activos y vigentes,
/// destacados primero, con filtros por categoría, ubicación y vigencia.
class BeneficiosScreen extends StatefulWidget {
  const BeneficiosScreen({super.key});

  @override
  State<BeneficiosScreen> createState() => _BeneficiosScreenState();
}

class _BeneficiosScreenState extends State<BeneficiosScreen> {
  static const Color _bgColor = Color(0xFFF1F5F9);
  static const Color _surfaceColor = Color(0xFFFFFFFF);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _primaryColor = Color(0xFF1E3A8A);

  final Stream<List<BeneficioModel>> _stream = BeneficioService().streamTodos();
  final TextEditingController _ubicacion = TextEditingController();
  CategoriaBeneficio? _categoria;
  bool _soloPorVencer = false;

  @override
  void dispose() {
    _ubicacion.dispose();
    super.dispose();
  }

  FiltroBeneficios get _filtro => FiltroBeneficios(
        categoria: _categoria,
        ubicacion: _ubicacion.text,
        vigencia:
            _soloPorVencer ? FiltroVigencia.porVencer : FiltroVigencia.cualquiera,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          // Lo único fijo es el encabezado (logo, notificaciones y perfil). Los
          // filtros y los beneficios se desplazan juntos.
          const EncabezadoTagOk(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: StreamBuilder<List<BeneficioModel>>(
                  stream: _stream,
                  builder: (context, snapshot) {
                    final List<Widget> cuerpo;
                    if (snapshot.hasError) {
                      cuerpo = [
                        _mensajeEnLista(
                          Icons.cloud_off_outlined,
                          'No se pudieron cargar los beneficios. Inténtalo más tarde.',
                        ),
                      ];
                    } else if (!snapshot.hasData) {
                      cuerpo = const [
                        Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ];
                    } else {
                      final lista = catalogoParaConductor(
                        snapshot.data!,
                        filtro: _filtro,
                      );
                      cuerpo = lista.isEmpty
                          ? [
                              _mensajeEnLista(
                                Icons.card_giftcard_outlined,
                                'No hay beneficios disponibles con estos filtros.',
                              ),
                            ]
                          : [
                              for (final b in lista)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: TarjetaBeneficio(
                                    beneficio: b,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            DetalleBeneficioScreen(beneficio: b),
                                      ),
                                    ),
                                  ),
                                ),
                            ];
                    }
                    return ListView(
                      // El botón del mapa sobresale un poco de la barra.
                      padding: const EdgeInsets.only(top: 8, bottom: 36),
                      children: [
                        // Título de la página: se desplaza con el contenido.
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 6, 16, 4),
                          child: Text(
                            'Beneficios',
                            style: TextStyle(
                              color: _textMain,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _filtros(),
                        ...cuerpo,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filtros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chipCategoria('Todas', null),
                for (final c in CategoriaBeneficio.values)
                  _chipCategoria(c.etiqueta, c),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ubicacion,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: _textMain),
                  decoration: InputDecoration(
                    hintText: 'Ubicación (ciudad o región)',
                    hintStyle: const TextStyle(color: _textMuted),
                    prefixIcon:
                        const Icon(Icons.place_outlined, color: _textMuted, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: _surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Por vencer'),
                selected: _soloPorVencer,
                onSelected: (v) => setState(() => _soloPorVencer = v),
                selectedColor: _primaryColor.withValues(alpha: 0.35),
                backgroundColor: _surfaceColor,
                labelStyle: const TextStyle(color: _textMain, fontSize: 12),
                checkmarkColor: _textMain,
                side: BorderSide.none,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipCategoria(String texto, CategoriaBeneficio? categoria) {
    final seleccionada = _categoria == categoria;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texto),
        selected: seleccionada,
        onSelected: (_) => setState(() => _categoria = categoria),
        selectedColor: _primaryColor,
        backgroundColor: _surfaceColor,
        labelStyle: TextStyle(
          color: _textMain,
          fontSize: 12,
          fontWeight: seleccionada ? FontWeight.w700 : FontWeight.normal,
        ),
        side: BorderSide.none,
        showCheckmark: false,
      ),
    );
  }

  /// Mensaje dentro de la lista desplazable (con un alto propio).
  Widget _mensajeEnLista(IconData icono, String texto) {
    return SizedBox(height: 260, child: _mensaje(icono, texto));
  }

  Widget _mensaje(IconData icono, String texto) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: _textMuted, size: 44),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de un beneficio en el catálogo.
class TarjetaBeneficio extends StatelessWidget {
  final BeneficioModel beneficio;
  final VoidCallback onTap;

  const TarjetaBeneficio({super.key, required this.beneficio, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = beneficio;
    final fin = b.fechaFin;
    return Material(
      color: const Color(0xFFFFFFFF),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.transparent),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 84,
                  height: 112,
                  child: ImagenBeneficio(beneficio: b),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (b.destacado) ...[
                          const Icon(Icons.star, color: Color(0xFFF59E0B), size: 16),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            b.etiquetaCategoria,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (b.empresa != null)
                      Text(
                        b.empresa!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    if (fin != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Hasta ${formatearFecha(fin)}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
            ],
          ),
        ),
      ),
    );
  }
}
