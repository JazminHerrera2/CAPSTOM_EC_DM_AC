import 'package:flutter/material.dart';

import '../../data/models/beneficio_model.dart';
import '../../data/services/beneficio_service.dart';
import '../dashboard/dashboard_logica.dart';
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
  static const Color _bgColor = Color(0xFF0F172A);
  static const Color _surfaceColor = Color(0xFF1E293B);
  static const Color _textMain = Color(0xFFF8FAFC);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _primaryColor = Color(0xFF4F46E5);

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
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textMain),
        title: const Text('Beneficios', style: TextStyle(color: _textMain)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                _filtros(),
                Expanded(
                  child: StreamBuilder<List<BeneficioModel>>(
                    stream: _stream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _mensaje(
                          Icons.cloud_off_outlined,
                          'No se pudieron cargar los beneficios. Inténtalo más tarde.',
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final lista = catalogoParaConductor(
                        snapshot.data!,
                        filtro: _filtro,
                      );
                      if (lista.isEmpty) {
                        return _mensaje(
                          Icons.card_giftcard_outlined,
                          'No hay beneficios disponibles con estos filtros.',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: lista.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => TarjetaBeneficio(
                          beneficio: lista[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DetalleBeneficioScreen(beneficio: lista[i]),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
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
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
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
                              color: Color(0xFF94A3B8),
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
                        color: Color(0xFFF8FAFC),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (b.empresa != null)
                      Text(
                        b.empresa!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    if (fin != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Hasta ${formatearFecha(fin)}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}
