import 'package:flutter/material.dart';
import 'revisar_ia_mantenimiento_screen.dart';

class ProcesandoIaMantenimientoScreen extends StatelessWidget {
  const ProcesandoIaMantenimientoScreen({super.key});

  static const Color bgColor = Color(0xFF0F172A);
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Analizando documento',
          style: TextStyle(
            color: textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Spacer(),

              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(
                      color: Color(0xFF8B5CF6),
                      strokeWidth: 4,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Procesando comprobante',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textMain,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Estamos identificando la información de la mantención.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 30),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
                child: const Column(
                  children: [
                    _ProcessRow(
                      icon: Icons.receipt_long_outlined,
                      text: 'Leyendo comprobante',
                    ),
                    SizedBox(height: 16),
                    _ProcessRow(
                      icon: Icons.manage_search_rounded,
                      text: 'Identificando información',
                    ),
                    SizedBox(height: 16),
                    _ProcessRow(
                      icon: Icons.auto_awesome_outlined,
                      text: 'Clasificando mantención',
                    ),
                  ],
                ),
              ),

              const Spacer(),

              const Text(
                'Este proceso puede tardar unos segundos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textMuted,
                  fontSize: 11,
                ),
              ),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const RevisarIaMantenimientoScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Continuar a revisión',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Cancelar',
                  style: TextStyle(
                    color: textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProcessRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ProcessRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFA78BFA),
            size: 20,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: ProcesandoIaMantenimientoScreen.textMain,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF8B5CF6),
          ),
        ),
      ],
    );
  }
}