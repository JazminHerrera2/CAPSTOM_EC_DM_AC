import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';


import 'login_screen.dart';
import 'admin_firestore_service.dart';
import 'beneficios_page.dart';
import 'admin_ui.dart';
import 'auditoria_page.dart';
import 'carga_masiva_page.dart';
import 'admin_paneles.dart';
import 'concesionarios_page.dart';
import 'dashboard_page.dart';
import 'mapa_page.dart';
import 'porticos_page.dart';
import 'reportes_page.dart';
import 'tarifas_page.dart';
import 'usuario_panel.dart';
import 'usuarios_tabla.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno desde el archivo .env local
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    debugPrint('TAG_OK_ADMIN: no se pudo cargar variables de entorno');
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const TagOkAdminApp());
}

class TagOkAdminApp extends StatelessWidget {
  const TagOkAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TAG OK Admin',
      // Idioma del panel: calendarios, relojes y diálogos de Material en
      // español (Chile), sin depender del idioma del navegador o del sistema.
      locale: const Locale('es', 'CL'),
      supportedLocales: const [
        Locale('es', 'CL'),
        Locale('es'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAzul,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kBorde),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kBorde),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kAzul, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kRojo),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kRojo, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kAzul,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kTinta,
            side: const BorderSide(color: kBorde),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: kAzul),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (st) => st.contains(WidgetState.selected) ? Colors.white : null,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (st) => st.contains(WidgetState.selected) ? kAzul : null,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
      home: const AdminAuthGate(),
    );
  }
}

/// Ancho (en px) por debajo del cual el panel pasa a la vista de celular:
/// menú en cajón con botón de hamburguesa y espaciados reducidos.
const double kAnchoCelular = 820;

bool isCompactLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kAnchoCelular;

class SidebarItem {
  final String title;
  final IconData icon;

  /// Encabezado del grupo del menú ("General", "Administración").
  final String section;
  final Widget Function(AdminFirestoreService service) pageBuilder;

  const SidebarItem({
    required this.title,
    required this.icon,
    required this.section,
    required this.pageBuilder,
  });
}

class AdminShell extends StatefulWidget {
  final String role;
  const AdminShell({super.key, required this.role});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final AdminFirestoreService _service = AdminFirestoreService();
  int _selectedIndex = 0;
  late final List<SidebarItem> _sidebarItems;
  final ScrollController _menuScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _sidebarItems = _getSidebarItems(widget.role);
  }

  @override
  void dispose() {
    _menuScroll.dispose();
    super.dispose();
  }

  /// Navega a otra sección por su título (si el rol no la ve, avisa).
  void _irA(String titulo) {
    final i = _sidebarItems.indexWhere((e) => e.title == titulo);
    if (i < 0) {
      avisar(context, 'Tu rol no tiene acceso a "$titulo".', error: true);
      return;
    }
    setState(() => _selectedIndex = i);
  }

  VoidCallback? get _irAAuditoria {
    final i = _sidebarItems.indexWhere((e) => e.title == 'Auditoría');
    if (i < 0) return null;
    return () => setState(() => _selectedIndex = i);
  }

  List<SidebarItem> _getSidebarItems(String role) {
    final String r = role.toLowerCase().trim();
    final bool isSuper =
        r == 'super_admin' ||
        r == 'super_administrador' ||
        r == 'superadmin' ||
        r == 'super administrador';

    final List<SidebarItem> all = [
      SidebarItem(
        title: 'Dashboard',
        section: 'General',
        icon: Icons.dashboard_outlined,
        pageBuilder: (s) => DashboardPage(
          service: s,
          // "Ver todo" de Actividad reciente: solo si el rol ve Auditoría.
          onVerActividad: _irAAuditoria,
        ),
      ),
      SidebarItem(
        title: 'Mapa',
        section: 'General',
        icon: Icons.map_outlined,
        pageBuilder: (s) => MapaPage(service: s),
      ),
      SidebarItem(
        title: 'Usuarios',
        section: 'Administración',
        icon: Icons.people_alt_outlined,
        pageBuilder: (s) => UsersPage(service: s),
      ),
      SidebarItem(
        title: 'Concesionarios',
        section: 'Administración',
        icon: Icons.apartment_outlined,
        pageBuilder: (s) => ConcesionariosPage(service: s, onIrA: _irA),
      ),
      SidebarItem(
        title: 'Pórticos',
        section: 'Administración',
        icon: Icons.location_on_outlined,
        pageBuilder: (s) => PorticosPage(service: s, onIrA: _irA),
      ),
      SidebarItem(
        title: 'Tarifas',
        section: 'Administración',
        icon: Icons.payments_outlined,
        pageBuilder: (s) => TarifasPage(service: s),
      ),
      SidebarItem(
        title: 'Reportes',
        section: 'Administración',
        icon: Icons.bar_chart_outlined,
        pageBuilder: (s) => ReportesPage(service: s),
      ),
      SidebarItem(
        title: 'Auditoría',
        section: 'Administración',
        icon: Icons.receipt_long_outlined,
        pageBuilder: (s) => AuditoriaPage(service: s),
      ),
      SidebarItem(
        title: 'Carga masiva',
        section: 'Administración',
        icon: Icons.upload_file_outlined,
        pageBuilder: (s) => CargaMasivaPage(service: s),
      ),
      SidebarItem(
        title: 'Beneficios',
        section: 'Administración',
        icon: Icons.card_giftcard_outlined,
        pageBuilder: (s) => BeneficiosPage(service: s),
      ),
      SidebarItem(
        title: 'Admins',
        section: 'Administración',
        icon: Icons.admin_panel_settings_outlined,
        pageBuilder: (s) => AdminsManagementPage(service: s),
      ),
    ];

    if (isSuper) {
      return all;
    } else {
      // Operador: Dashboard, Mapa, Pórticos, Tarifas, Reportes
      return all
          .where(
            (item) =>
                item.title == 'Dashboard' ||
                item.title == 'Mapa' ||
                item.title == 'Pórticos' ||
                item.title == 'Tarifas' ||
                item.title == 'Reportes',
          )
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedIndex >= _sidebarItems.length) {
      _selectedIndex = 0;
    }

    final item = _sidebarItems[_selectedIndex];
    final Widget content = item.pageBuilder(_service);

    final bool compact = isCompactLayout(context);

    // Menú agrupado por secciones, con el ítem activo en azul claro.
    final List<Widget> entradas = [];
    String? seccionActual;
    for (int index = 0; index < _sidebarItems.length; index++) {
      final sidebarItem = _sidebarItems[index];
      if (sidebarItem.section != seccionActual) {
        seccionActual = sidebarItem.section;
        entradas.add(
          Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              entradas.isEmpty ? 4 : 22,
              12,
              8,
            ),
            child: Text(
              seccionActual,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
      final bool selected = _selectedIndex == index;
      entradas.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: selected ? const Color(0xFFDBEAFE) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() => _selectedIndex = index);
                // En móvil el menú es un cajón: se cierra al elegir.
                if (compact) Navigator.of(context).pop();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Icon(
                      sidebarItem.icon,
                      size: 20,
                      color: selected
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF0F172A),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        sidebarItem.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selected
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final Widget sidebar = Container(
      width: compact ? null : 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Center(child: _BrandBlock()),
            ),
            const Text(
              'Panel Administrador',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 22),
            Expanded(
              // Barra de desplazamiento siempre visible: indica que hay más
              // opciones abajo cuando el menú no cabe en pantalla.
              child: Scrollbar(
                controller: _menuScroll,
                thumbVisibility: true,
                trackVisibility: true,
                child: ListView(
                  controller: _menuScroll,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: entradas,
                ),
              ),
            ),
            const Divider(color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: _UserProfileCard(role: widget.role),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (compact) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          toolbarHeight: 64,
          title: const _LogoMark(ancho: 150),
          centerTitle: false,
        ),
        drawer: Drawer(
          width: 280,
          backgroundColor: Colors.white,
          child: sidebar,
        ),
        body: content,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          sidebar,
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    return const _LogoMark();
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({this.ancho = 230});

  /// Ancho de la imagen completa (el PNG es 3:2 con mucho margen vacío).
  final double ancho;

  @override
  Widget build(BuildContext context) {
    // El logo ocupa solo la franja central del PNG: se recorta el margen para
    // que el tamaño visible sea grande y no quede aire arriba ni abajo.
    return ClipRect(
      child: Align(
        alignment: const Alignment(0, -0.04),
        heightFactor: 0.5,
        widthFactor: 0.86,
        child: Image.asset(
          'assets/logo_tagok.png',
          width: ancho,
          height: ancho / 1.5,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _UserProfileCard extends StatelessWidget {
  final String role;
  const _UserProfileCard({required this.role});

  @override
  Widget build(BuildContext context) {
    final String email =
        FirebaseAuth.instance.currentUser?.email ?? 'admin@tagok.cl';
    final String r = role.toLowerCase().trim();
    final bool isSuper =
        r == 'super_admin' ||
        r == 'super_administrador' ||
        r == 'superadmin' ||
        r == 'super administrador';

    final String roleLabel = isSuper
        ? 'Super Administrador'
        : 'Administrador Operacional';
    final Color badgeBg = isSuper
        ? const Color(0xFF0EA5E9).withValues(alpha: 0.12)
        : const Color(0xFFF59E0B).withValues(alpha: 0.12);
    final Color badgeText = isSuper
        ? const Color(0xFF0369A1)
        : const Color(0xFFB45309);

    // Al tocar la tarjeta del usuario se despliega "Cerrar sesión".
    // El menú se abre al costado de la tarjeta (a su derecha), con el correo,
    // el rol y la opción de cerrar sesión; su borde inferior queda alineado
    // con el de la tarjeta.
    return LayoutBuilder(
      builder: (context, constraints) => PopupMenuButton<String>(
      tooltip: 'Opciones de la cuenta',
      position: PopupMenuPosition.over,
      offset: Offset(constraints.maxWidth + 8, -96),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onSelected: (valor) async {
        if (valor == 'cerrar_sesion') {
          await FirebaseAuth.instance.signOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                email,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSuper
                          ? Icons.verified_user_outlined
                          : Icons.person_outline,
                      size: 14,
                      color: const Color(0xFF0F172A),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      roleLabel,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem<String>(
          value: 'cerrar_sesion',
          child: Row(
            children: [
              Icon(Icons.logout, color: Color(0xFF0F172A), size: 20),
              SizedBox(width: 12),
              Text(
                'Cerrar sesión',
                style: TextStyle(color: Color(0xFF0F172A), fontSize: 15),
              ),
            ],
          ),
        ),
      ],
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: badgeBg,
            radius: 16,
            child: Icon(
              isSuper ? Icons.admin_panel_settings : Icons.person_outline,
              color: badgeText,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  email,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  roleLabel,
                  style: TextStyle(
                    color: badgeText,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.unfold_more, color: Color(0xFF64748B), size: 18),
        ],
      ),
      ),
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  DonutChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final double total = values.fold(0.0, (acc, val) => acc + val);
    final center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 12;

    if (total == 0) {
      final Paint paint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    double startAngle = -3.14159 / 2;
    for (int i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final sweepAngle = (values[i] / total) * 2 * 3.14159;
      final Paint paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle - 0.05,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DonutChart extends StatelessWidget {
  final Map<String, double> costByHighway;
  final double totalCost;

  const DonutChart({
    super.key,
    required this.costByHighway,
    required this.totalCost,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> highways = costByHighway.keys.toList();
    final List<double> values = costByHighway.values.toList();

    final List<Color> colors = [
      const Color(0xFF2563EB),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF1E3A8A),
      const Color(0xFF64748B),
    ];

    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: DonutChartPainter(
                    values: values,
                    colors: colors,
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Total Peajes',
                      style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${totalCost.round()}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(highways.length, (index) {
              if (index >= colors.length) return const SizedBox.shrink();
              final double cost = values[index];
              final double pct = totalCost > 0 ? (cost / totalCost) * 100 : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors[index],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        highways[index],
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class BarChart extends StatelessWidget {
  final Map<String, int> dailyCounts;
  final List<DateTime> last7Days;

  const BarChart({
    super.key,
    required this.dailyCounts,
    required this.last7Days,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> weekdays = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    final List<int> counts = last7Days.map((day) {
      final key = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
      return dailyCounts[key] ?? 0;
    }).toList();

    final int maxCount = counts.fold(0, (max, val) => val > max ? val : max);
    final double chartHeight = 95.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        final day = last7Days[index];
        final count = counts[index];
        final String dayLabel = weekdays[day.weekday % 7];
        final double barHeight = maxCount > 0 ? (count / maxCount) * chartHeight : 0.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 14,
              height: barHeight > 4 ? barHeight : 4.0,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              dayLabel,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class HighwayProgressBars extends StatelessWidget {
  final Map<String, double> costByHighway;
  final double totalCost;

  const HighwayProgressBars({
    super.key,
    required this.costByHighway,
    required this.totalCost,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = costByHighway.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final displayList = sorted.take(4).toList();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(displayList.length, (index) {
        final entry = displayList[index];
        final double cost = entry.value;
        final double pct = totalCost > 0 ? (cost / totalCost) : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '\$${cost.round()} (${(pct * 100).toStringAsFixed(1)}%)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: const Color(0xFFF1F5F9),
                  color: const Color(0xFF2563EB),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.service});

  final AdminFirestoreService service;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _estadoFiltro = 'Todos'; // Todos | Activos | Inactivos
  String _vehiculoFiltro = 'Todos'; // Todos | Con vehículo | Sin vehículo
  int _currentPage = 0;
  int _rowsPerPage = 10;

  late Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _adminsStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _vehiclesStream;
  late Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _tripsStream;

  /// Un usuario cuenta como activo si tuvo algún viaje en los últimos 30 días.
  static const Duration _ventanaActividad = Duration(days: 30);

  void _crearStreams() {
    _usersStream = widget.service.streamUsers();
    _adminsStream = widget.service.streamAdministradores();
    _vehiclesStream = widget.service.streamVehicles();
    _tripsStream = widget.service.streamUserTrips();
  }

  @override
  void initState() {
    super.initState();
    _crearStreams();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.toLowerCase().trim();
        _currentPage = 0;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _usersStream,
      builder: (context, usersSnap) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _adminsStream,
        builder: (context, adminsSnap) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _vehiclesStream,
          builder: (context, vehSnap) => StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: _tripsStream,
            builder: (context, tripsSnap) {
              final error =
                  usersSnap.error ??
                  adminsSnap.error ??
                  vehSnap.error ??
                  tripsSnap.error;
              if (error != null) {
                return Center(child: Text('Error al leer Firestore: $error'));
              }
              if (!usersSnap.hasData ||
                  !adminsSnap.hasData ||
                  !vehSnap.hasData ||
                  !tripsSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _construir(
                context,
                usersSnap.data!.docs,
                adminsSnap.data!.docs,
                vehSnap.data!.docs,
                tripsSnap.data!,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _construir(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> userDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> adminDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> vehDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> tripDocs,
  ) {
    final ahora = DateTime.now();

    // Rol de administrador por correo.
    String rolDe(QueryDocumentSnapshot<Map<String, dynamic>> a) =>
        (a.data()['rol'] ?? a.data()['role'] ?? 'operador').toString();
    final Map<String, String> rolPorCorreo = {
      for (final a in adminDocs)
        (a.data()['email'] ?? '').toString().toLowerCase().trim(): rolDe(a),
    };
    final Map<String, String> rolPorUid = {
      for (final a in adminDocs) a.id: rolDe(a),
    };

    // Patentes por usuario.
    final Map<String, List<String>> patentes = {};
    final Map<String, List<Map<String, dynamic>>> vehiculosDe = {};
    for (final v in vehDocs) {
      final d = v.data();
      final ref = d['id_usuario'];
      final String? uid = ref is DocumentReference
          ? ref.id
          : ref?.toString().split('/').last;
      if (uid == null || uid.isEmpty) continue;
      patentes.putIfAbsent(uid, () => []).add((d['patente'] ?? '').toString());
      vehiculosDe.putIfAbsent(uid, () => []).add(d);
    }

    // Última actividad (último viaje) por usuario.
    final Map<String, DateTime> ultimaActividad = {};
    for (final t in tripDocs) {
      final uid = t.reference.parent.parent?.id;
      if (uid == null) continue;
      final raw = t.data()['date'];
      final f = raw is Timestamp ? raw.toDate() : DateTime.tryParse('$raw');
      if (f == null) continue;
      final previo = ultimaActividad[uid];
      if (previo == null || f.isAfter(previo)) ultimaActividad[uid] = f;
    }

    final filas = userDocs.map((doc) {
      final d = doc.data();
      final correo = (d['email'] ?? 'Sin correo').toString();
      final f = d['fecha_creacion'];
      final actividad = ultimaActividad[doc.id];
      return FilaUsuario(
        docId: doc.id,
        nombre: (d['nombre_mostrar'] ?? 'Sin nombre').toString(),
        correo: correo,
        presupuesto:
            int.tryParse(d['limite_presupuesto_mensual']?.toString() ?? '0') ??
            0,
        rol: rolPorUid[doc.id] ?? rolPorCorreo[correo.toLowerCase().trim()],
        patentes: patentes[doc.id] ?? const [],
        registrado: f is Timestamp ? f.toDate() : null,
        ultimaActividad: actividad,
        // El interruptor "Cuenta activa" del panel manda; si nunca se usó,
        // se infiere de la actividad reciente.
        activo: d['activo'] is bool
            ? d['activo'] as bool
            : (actividad != null &&
                  ahora.difference(actividad) <= _ventanaActividad),
        vehiculos: vehiculosDe[doc.id] ?? const [],
      );
    }).toList();

    final total = filas.length;
    final activos = filas.where((f) => f.activo).length;
    final conVehiculo = filas.where((f) => f.patentes.isNotEmpty).length;

    final filtradas = filas.where((f) {
      if (_searchQuery.isNotEmpty) {
        final enPatente = f.patentes.any(
          (p) => p.toLowerCase().contains(_searchQuery),
        );
        if (!f.correo.toLowerCase().contains(_searchQuery) &&
            !f.nombre.toLowerCase().contains(_searchQuery) &&
            !enPatente) {
          return false;
        }
      }
      if (_estadoFiltro == 'Activos' && !f.activo) return false;
      if (_estadoFiltro == 'Inactivos' && f.activo) return false;
      if (_vehiculoFiltro == 'Con vehículo' && f.patentes.isEmpty) return false;
      if (_vehiculoFiltro == 'Sin vehículo' && f.patentes.isNotEmpty) {
        return false;
      }
      return true;
    }).toList();

    final int totalPages = (filtradas.length / _rowsPerPage).ceil();
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }
    final int startIndex = _currentPage * _rowsPerPage;
    final int endIndex = (startIndex + _rowsPerPage) > filtradas.length
        ? filtradas.length
        : (startIndex + _rowsPerPage);
    final pagina = filtradas.sublist(startIndex, endIndex);

    final bool compact = isCompactLayout(context);

    return SafeArea(
      child: PaginaConEncabezado(
            compact: compact,
            encabezado: EncabezadoPagina(
              titulo: 'Usuarios',
              subtitulo:
                  'Administra los usuarios registrados en la plataforma TAG OK.',
              acciones: [
                BotonContorno(
                  texto: 'Actualizar',
                  icono: Icons.refresh,
                  onPressed: () => setState(_crearStreams),
                ),
              ],
            ),
            children: [

            GrillaTarjetas(
              tarjetas: [
                TarjetaDato(
                  etiqueta: 'Total',
                  valor: '$total',
                  icono: Icons.people_outline,
                ),
                TarjetaDato(
                  etiqueta: 'Activos',
                  valor: '$activos',
                  icono: Icons.how_to_reg_outlined,
                  valorColor: const Color(0xFF059669),
                ),
                TarjetaDato(
                  etiqueta: 'Inactivos',
                  valor: '${total - activos}',
                  icono: Icons.person_off_outlined,
                  valorColor: const Color(0xFFE11D48),
                ),
                TarjetaDato(
                  etiqueta: 'Con vehículo',
                  valor: '$conVehiculo',
                  icono: Icons.directions_car_outlined,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CabeceraListado(
                    titulo: 'Listado',
                    subtitulo: '${filtradas.length} de $total usuarios',
                    controles: [
                      CampoBusqueda(
                        controller: _searchCtrl,
                        hint: 'Buscar email o patente…',
                      ),
                      DesplegableFiltro(
                        valor: _estadoFiltro,
                        opciones: const ['Todos', 'Activos', 'Inactivos'],
                        ancho: 140,
                        onChanged: (v) => setState(() {
                          _estadoFiltro = v;
                          _currentPage = 0;
                        }),
                      ),
                      DesplegableFiltro(
                        valor: _vehiculoFiltro,
                        opciones: const ['Todos', 'Con vehículo', 'Sin vehículo'],
                        etiquetas: const {'Todos': 'Todos los vehículos'},
                        ancho: 200,
                        onChanged: (v) => setState(() {
                          _vehiculoFiltro = v;
                          _currentPage = 0;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (filtradas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No se encontraron usuarios con los filtros aplicados.',
                        ),
                      ),
                    )
                  else
                    TablaUsuarios(
                      filas: pagina,
                      ahora: ahora,
                      onAbrir: (f) => mostrarPanelUsuario(
                        context,
                        usuario: f,
                        ahora: ahora,
                      ),
                      onReset: (f) => _enviarResetPassword(context, f.correo),
                      onEliminar: (f) =>
                          _mostrarDialogoEliminar(context, f.docId, f.nombre),
                    ),
                  const Divider(),
                  Paginador(
                    pagina: _currentPage,
                    porPagina: _rowsPerPage,
                    total: filtradas.length,
                    etiqueta: 'usuarios',
                    onPagina: (n) => setState(() => _currentPage = n),
                    onPorPagina: (n) => setState(() {
                      _rowsPerPage = n;
                      _currentPage = 0;
                    }),
                  ),
                ],
              ),
            ),
          
            ],
          ),
    );
  }

  void _enviarResetPassword(BuildContext context, String correo) async {
    if (correo == 'Sin correo') return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: correo);
      widget.service.logAction(
        action: 'RESET_PASSWORD',
        target: correo,
        details: 'Se envió un correo de restablecimiento de contraseña.',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Correo de restablecimiento enviado a $correo'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar correo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarDialogoEliminar(
    BuildContext context,
    String docId,
    String nombre,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Eliminar Usuario'),
        content: Text(
          '¿Estás seguro que deseas eliminar el registro y los datos de $nombre? Esta acción es irreversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
            ),
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(docId)
                  .delete();
              widget.service.logAction(
                action: 'DELETE_USER',
                target: nombre,
                details: 'Se eliminó definitivamente el usuario y sus datos.',
              );
              Navigator.pop(context);
            },
            child: const Text(
              'Sí, Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminsManagementPage extends StatefulWidget {
  const AdminsManagementPage({super.key, required this.service});

  final AdminFirestoreService service;

  @override
  State<AdminsManagementPage> createState() => _AdminsManagementPageState();
}

class _AdminsManagementPageState extends State<AdminsManagementPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedRoleFilter = 'Todos';
  int _currentPage = 0;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.toLowerCase().trim();
        _currentPage = 0;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesFilters(Map<String, dynamic> data) {
    final String email = (data['email'] ?? '').toString().toLowerCase();
    final String role = (data['rol'] ?? data['role'] ?? 'operador').toString().toLowerCase();

    if (_searchQuery.isNotEmpty && !email.contains(_searchQuery)) {
      return false;
    }

    if (_selectedRoleFilter != 'Todos') {
      if (_selectedRoleFilter == 'super_admin' &&
          role != 'super_admin' &&
          role != 'super_administrador' &&
          role != 'superadmin' &&
          role != 'super administrador') {
        return false;
      }
      if (_selectedRoleFilter == 'operador' &&
          role != 'operador' &&
          role != 'operario' &&
          role != 'operator') {
        return false;
      }
    }

    return true;
  }

  Future<void> _createAdminAccount(String email, String password, String role) async {
    FirebaseApp? tempApp;
    try {
      final String tempAppName = 'creator_app_${DateTime.now().millisecondsSinceEpoch}';
      tempApp = await Firebase.initializeApp(
        name: tempAppName,
        options: Firebase.app().options,
      );

      final FirebaseAuth tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final UserCredential creds = await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String uid = creds.user!.uid;

      await FirebaseFirestore.instance.collection('administradores').doc(uid).set({
        'email': email,
        'rol': role,
        'fecha_creacion': FieldValue.serverTimestamp(),
      });

      await widget.service.logAction(
        action: 'CREATE_ADMIN',
        target: email,
        details: 'Admin creado exitosamente. UID: $uid. Rol: $role.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Administrador $email creado correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear administrador: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (tempApp != null) {
        await tempApp.delete();
      }
    }
  }

  Future<void> _changeAdminRole(String docId, String email, String newRole) async {
    try {
      await widget.service.updateAdminRole(docId, newRole);
      await widget.service.logAction(
        action: 'EDIT_ADMIN_ROLE',
        target: email,
        details: 'Rol modificado a: $newRole',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rol de $email actualizado a $newRole.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar rol: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _revokeAdminAccess(String docId, String email) async {
    try {
      await widget.service.deleteAdmin(docId);
      await widget.service.logAction(
        action: 'DELETE_ADMIN',
        target: email,
        details: 'Acceso revocado (eliminado de Firestore)',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Acceso para $email revocado correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al revocar acceso: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetAdminPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      await widget.service.logAction(
        action: 'RESET_ADMIN_PASSWORD',
        target: email,
        details: 'Enviado enlace de recuperación de contraseña',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enlace para restablecer contraseña enviado a $email.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar restablecimiento de contraseña: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddAdminDialog() async {
    final r = await mostrarPanelNuevoAdmin(context);
    if (r == null) return;
    await _createAdminAccount(r.email, r.password, r.rol);
  }

  Future<void> _showEditRoleDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final String email = (data['email'] ?? '').toString();
    final String currentRole = (data['rol'] ?? data['role'] ?? 'operador').toString();
    final nuevo = await mostrarPanelRolAdmin(
      context,
      email: email,
      rolActual: currentRole == 'super_admin' ? 'super_admin' : 'operador',
    );
    if (nuevo == null) return;
    await _changeAdminRole(doc.id, email, nuevo);
  }

  void _showDeleteConfirmDialog(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final String email = (data['email'] ?? '').toString();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Confirmar Revocación'),
              content: Text(
                '¿Está seguro de que desea revocar el acceso de administrador para $email? '
                'Esta acción le impedirá el ingreso al panel inmediatamente.',
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() {
                            isSaving = true;
                          });
                          await _revokeAdminAccess(doc.id, email);
                          if (context.mounted) {
                            Navigator.of(ctx).pop();
                          }
                        },
                  child: const Text('Revocar Acceso', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentAdminEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final bool compact = isCompactLayout(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.service.streamAdministradores(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error al leer Firestore: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        bool esSuper(String r) {
          final x = r.toLowerCase().trim();
          return x == 'super_admin' ||
              x == 'super_administrador' ||
              x == 'superadmin' ||
              x == 'super administrador';
        }

        final docs = snapshot.data!.docs;
        String rolDe(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
            (d.data()['rol'] ?? d.data()['role'] ?? 'operador').toString();
        final supers = docs.where((d) => esSuper(rolDe(d))).length;
        final filteredDocs = docs
            .where((doc) => _matchesFilters(doc.data()))
            .toList();

        final int totalPages = (filteredDocs.length / _rowsPerPage).ceil();
        if (_currentPage >= totalPages && totalPages > 0) {
          _currentPage = totalPages - 1;
        }
        final int startIndex = _currentPage * _rowsPerPage;
        final int endIndex = (startIndex + _rowsPerPage) > filteredDocs.length
            ? filteredDocs.length
            : (startIndex + _rowsPerPage);
        final pageDocs = filteredDocs.sublist(startIndex, endIndex);

        String iniciales(String email) {
          final partes = email
              .split('@')
              .first
              .split(RegExp(r'[._\-]+'))
              .where((p) => p.isNotEmpty)
              .toList();
          if (partes.length >= 2) return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
          return email.length >= 2 ? email.substring(0, 2).toUpperCase() : 'AD';
        }

        return SafeArea(
          child: PaginaConEncabezado(
            compact: compact,
            encabezado: EncabezadoPagina(
                  titulo: 'Administradores',
                  subtitulo:
                      'Administra los roles y accesos al panel backoffice de TAG OK.',
                  acciones: [
                    BotonContorno(
                      texto: 'Actualizar',
                      icono: Icons.refresh,
                      onPressed: () => setState(() {}),
                    ),
                    BotonPrimario(
                      texto: 'Agregar admin',
                      icono: Icons.add,
                      onPressed: _showAddAdminDialog,
                    ),
                  ],
                ),
            children: [

                GrillaTarjetas(
                  tarjetas: [
                    TarjetaDato(
                      etiqueta: 'Total',
                      valor: '${docs.length}',
                      icono: Icons.admin_panel_settings_outlined,
                    ),
                    TarjetaDato(
                      etiqueta: 'Super administradores',
                      valor: '$supers',
                      icono: Icons.verified_user_outlined,
                    ),
                    TarjetaDato(
                      etiqueta: 'Operacionales',
                      valor: '${docs.length - supers}',
                      icono: Icons.person_outline,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TarjetaBlanca(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CabeceraListado(
                        titulo: 'Listado',
                        subtitulo:
                            '${filteredDocs.length} de ${docs.length} administradores',
                        controles: [
                          CampoBusqueda(
                            controller: _searchCtrl,
                            hint: 'Buscar por correo…',
                          ),
                          DesplegableFiltro(
                            valor: _selectedRoleFilter,
                            opciones: const ['Todos', 'super_admin', 'operador'],
                            etiquetas: const {
                              'Todos': 'Todos los roles',
                              'super_admin': 'Super Administrador',
                              'operador': 'Administrador Operacional',
                            },
                            ancho: 230,
                            onChanged: (v) => setState(() {
                              _selectedRoleFilter = v;
                              _currentPage = 0;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (filteredDocs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'No hay administradores que coincidan con los filtros.',
                            ),
                          ),
                        )
                      else
                        TablaSimple(
                          encabezados: const ['Administrador', 'Rol', 'Acciones'],
                          anchos: const [240, 150],
                          filas: [
                            for (final doc in pageDocs)
                              () {
                                final String email = (doc.data()['email'] ?? '').toString();
                                final String role = rolDe(doc);
                                final bool isCurrentUser =
                                    email.toLowerCase() == currentAdminEmail.toLowerCase();
                                return <Widget>[
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 17,
                                        backgroundColor: const Color(0xFFF1F5F9),
                                        child: Text(
                                          iniciales(email),
                                          style: const TextStyle(
                                            color: kGris,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Flexible(
                                        child: Text(
                                          email,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: kTinta,
                                          ),
                                        ),
                                      ),
                                      if (isCurrentUser) ...[
                                        const SizedBox(width: 8),
                                        const Pildora('Tú'),
                                      ],
                                    ],
                                  ),
                                  esSuper(role)
                                      ? const Pildora(
                                          'Super Administrador',
                                          fondo: kAzul,
                                          colorTexto: Colors.white,
                                          icono: Icons.verified_user_outlined,
                                        )
                                      : const Pildora(
                                          'Administrador Operacional',
                                          fondo: Color(0xFF475569),
                                          colorTexto: Colors.white,
                                          icono: Icons.verified_user_outlined,
                                        ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                        tooltip: isCurrentUser ? 'No puedes cambiar tu propio rol' : 'Cambiar Rol',
                                        onPressed: isCurrentUser ? null : () => _showEditRoleDialog(doc),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.lock_reset, color: Colors.orange, size: 20),
                                        tooltip: 'Restablecer Contraseña',
                                        onPressed: () => _resetAdminPassword(email),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                        tooltip: isCurrentUser ? 'No puedes revocar tu propio acceso' : 'Revocar Acceso',
                                        onPressed: isCurrentUser ? null : () => _showDeleteConfirmDialog(doc),
                                      ),
                                    ],
                                  ),
                                ];
                              }(),
                          ],
                        ),
                      const Divider(),
                      Paginador(
                        pagina: _currentPage,
                        porPagina: _rowsPerPage,
                        total: filteredDocs.length,
                        etiqueta: 'administradores',
                        onPagina: (n) => setState(() => _currentPage = n),
                        onPorPagina: (n) => setState(() {
                          _rowsPerPage = n;
                          _currentPage = 0;
                        }),
                      ),
                    ],
                  ),
                ),
              
            ],
          ),
        );
      },
    );
  }
}

class _TablePaginationControls extends StatelessWidget {
  const _TablePaginationControls({
    required this.currentPage,
    required this.rowsPerPage,
    required this.totalItems,
    required this.totalPages,
    required this.startIndex,
    required this.endIndex,
    required this.onPageChanged,
    required this.onRowsPerPageChanged,
    required this.itemLabel,
  });

  final int currentPage;
  final int rowsPerPage;
  final int totalItems;
  final int totalPages;
  final int startIndex;
  final int endIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onRowsPerPageChanged;
  final String itemLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mostrando ${totalItems == 0 ? 0 : startIndex + 1} - $endIndex de $totalItems $itemLabel',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              const Text(
                'Filas por página: ',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: rowsPerPage,
                items: [5, 10, 20, 50].map((int val) {
                  return DropdownMenuItem<int>(
                    value: val,
                    child: Text('$val', style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    onRowsPerPageChanged(newValue);
                  }
                },
                underline: const SizedBox(),
              ),
              const SizedBox(width: 24),
              IconButton(
                icon: const Icon(Icons.first_page_rounded),
                onPressed: currentPage > 0 ? () => onPageChanged(0) : null,
                tooltip: 'Primera página',
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: currentPage > 0
                    ? () => onPageChanged(currentPage - 1)
                    : null,
                tooltip: 'Página anterior',
              ),
              const SizedBox(width: 8),
              Text(
                'Pág. ${currentPage + 1} de ${totalPages == 0 ? 1 : totalPages}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: currentPage < totalPages - 1
                    ? () => onPageChanged(currentPage + 1)
                    : null,
                tooltip: 'Siguiente página',
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded),
                onPressed: currentPage < totalPages - 1
                    ? () => onPageChanged(totalPages - 1)
                    : null,
                tooltip: 'Última página',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FirestoreListTable extends StatefulWidget {
  const _FirestoreListTable({
    required this.stream,
    required this.emptyMessage,
    required this.columns,
    required this.rowBuilder,
    required this.itemLabel,
  });

  final Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> stream;
  final String emptyMessage;
  final List<String> columns;
  final List<DataCell> Function(QueryDocumentSnapshot<Map<String, dynamic>>)
  rowBuilder;
  final String itemLabel;

  @override
  State<_FirestoreListTable> createState() => _FirestoreListTableState();
}

class _FirestoreListTableState extends State<_FirestoreListTable> {
  int _currentPage = 0;
  int _rowsPerPage = 10;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: widget.stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error al leer Firestore: ${snapshot.error}');
            }

            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                snapshot.data!;
            if (docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(widget.emptyMessage),
                ),
              );
            }

            final int totalPages = (docs.length / _rowsPerPage).ceil();
            if (_currentPage >= totalPages && totalPages > 0) {
              _currentPage = totalPages - 1;
            }

            final int startIndex = _currentPage * _rowsPerPage;
            final int endIndex = (startIndex + _rowsPerPage) > docs.length
                ? docs.length
                : (startIndex + _rowsPerPage);
            final pageDocs = docs.sublist(startIndex, endIndex);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: widget.columns
                            .map(
                              (String column) =>
                                  DataColumn(label: Text(column)),
                            )
                            .toList(),
                        rows: pageDocs.map((doc) {
                          return DataRow(cells: widget.rowBuilder(doc));
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const Divider(),
                _TablePaginationControls(
                  currentPage: _currentPage,
                  rowsPerPage: _rowsPerPage,
                  totalItems: docs.length,
                  totalPages: totalPages,
                  startIndex: startIndex,
                  endIndex: endIndex,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  onRowsPerPageChanged: (rows) => setState(() {
                    _rowsPerPage = rows;
                    _currentPage = 0;
                  }),
                  itemLabel: widget.itemLabel,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

