import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/services/simulated_toll_service.dart';
import '../data/services/geocoding_service.dart';
import '../data/services/history_service.dart';

class RouteSetupScreen extends StatefulWidget {
  final LatLng? initialOrigin;
  const RouteSetupScreen({super.key, this.initialOrigin});

  @override
  State<RouteSetupScreen> createState() => _RouteSetupScreenState();
}

class _RouteSetupScreenState extends State<RouteSetupScreen> {
  // Colores del tema dark
  final Color bgColor = const Color(0xFF0F172A);
  final Color primaryColor = const Color(0xFF4F46E5);
  final Color textMain = const Color(0xFFF8FAFC);
  final Color textMuted = const Color(0xFF94A3B8);
  final Color inputBg = const Color(0x990F172A);
  final Color surfaceBorder = const Color(0x1AFFFFFF);
  final Color navBgColor = const Color(0xFF1E293B);

  Map<String, dynamic>? _selectedVehicleMap;
  bool _isLoading = false;
  
  // Inicializamos el nuevo servicio de simulación gratuito
  final SimulatedTollService _tollService = SimulatedTollService();
  final GeocodingService _geocodingService = GeocodingService();
  final HistoryService _historyService = HistoryService();

  // Coordenadas seleccionadas
  LatLng? _originLocation;
  LatLng? _destinationLocation;

  final TextEditingController _originController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialOrigin != null) {
      _originLocation = widget.initialOrigin;
      _originController.text = 'Mi ubicación actual';
    }
    _cargarVehiculoPrincipal();
  }

  @override
  void dispose() {
    _originController.dispose();
    super.dispose();
  }

  Future<void> _cargarVehiculoPrincipal() async {
    final vehiculo = await _historyService.getPrincipalVehicleInfo();
    if (mounted) {
      setState(() {
        _selectedVehicleMap = vehiculo;
      });
    }
  }

  Future<void> _seleccionarVehiculo() async {
    final vehicles = await _historyService.getUserVehicles();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: navBgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Seleccionar Vehículo', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                if (vehicles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No tienes vehículos registrados.', style: TextStyle(color: Colors.white70)),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: vehicles.length,
                      itemBuilder: (context, index) {
                        final v = vehicles[index];
                        return ListTile(
                          leading: const Icon(Icons.directions_car, color: Colors.white70),
                          title: Text(v['patente'] ?? '', style: const TextStyle(color: Colors.white)),
                          subtitle: Text(v['marca'] ?? '', style: TextStyle(color: textMuted)),
                          onTap: () {
                            setState(() {
                              _selectedVehicleMap = v;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textMuted),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Text(
                'Configurar Viaje',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textMain,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Busca tu origen, destino y vehículo.',
                style: TextStyle(color: textMuted, fontSize: 16),
              ),
              const SizedBox(height: 40),

              // 1. Buscador Origen
              _buildAutocompleteField(
                controller: _originController,
                hintText: 'Ruta Origen (Buscar dirección...)',
                icon: Icons.my_location,
                iconColor: primaryColor,
                onSelected: (selection) {
                  setState(() {
                    _originLocation = selection.location;
                  });
                },
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20),
                child: Icon(Icons.more_vert, color: textMuted.withValues(alpha: 0.5)),
              ),

              // 2. Buscador Destino
              _buildAutocompleteField(
                hintText: 'Ruta Destino (Buscar dirección...)',
                icon: Icons.location_on,
                iconColor: const Color(0xFF10B981),
                onSelected: (selection) {
                  setState(() {
                    _destinationLocation = selection.location;
                  });
                },
              ),
              
              const SizedBox(height: 32),

              // 3. Vehículo Principal
              Text(
                '  Vehículo a utilizar (Principal)',
                style: TextStyle(color: textMuted, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _seleccionarVehiculo,
                child: Container(
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: surfaceBorder),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Icon(Icons.directions_car_outlined, color: primaryColor),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _selectedVehicleMap != null 
                            ? '${_selectedVehicleMap!['marca']} (${_selectedVehicleMap!['patente']})' 
                            : 'Selecciona un vehículo',
                          style: TextStyle(
                            color: _selectedVehicleMap != null ? textMain : Colors.orange, 
                            fontSize: 16,
                            fontWeight: _selectedVehicleMap != null ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: textMuted),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Botón Iniciar Viaje
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _iniciarViaje,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: Colors.transparent,
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Ver ruta',
                            style: TextStyle(
                              color: textMain,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.directions, color: textMain),
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

  void _iniciarViaje() async {
    if (_originLocation == null || _destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona un Origen y Destino válidos.'),
          backgroundColor: Colors.orange,
        )
      );
      return;
    }

    if (_selectedVehicleMap == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona un vehículo.'),
          backgroundColor: Colors.orange,
        )
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final routeData = await _tollService.calculateRouteAndTolls(
        origin: _originLocation!,
        destination: _destinationLocation!,
      );
      
      if (!mounted) return;

      // Retornar datos junto con el vehículo
      Navigator.pop(context, {
        'route': routeData,
        'vehicle': _selectedVehicleMap,
      });
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
        )
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildAutocompleteField({
    TextEditingController? controller,
    required String hintText,
    required IconData icon,
    required Color iconColor,
    required Function(PlaceSuggestion) onSelected,
  }) {
    return Autocomplete<PlaceSuggestion>(
      initialValue: controller != null ? TextEditingValue(text: controller.text) : null,
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<PlaceSuggestion>.empty();
        }
        // Llamar a Mapbox API
        return await _geocodingService.searchPlaces(textEditingValue.text);
      },
      onSelected: onSelected,
      displayStringForOption: (PlaceSuggestion option) => option.address,
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        return Container(
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: surfaceBorder),
          ),
          child: TextField(
            controller: textEditingController,
            focusNode: focusNode,
            style: TextStyle(color: textMain),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.7)),
              prefixIcon: Icon(icon, color: iconColor),
              suffixIcon: textEditingController.text.isNotEmpty 
                ? IconButton(
                    icon: Icon(Icons.clear, color: textMuted, size: 18),
                    onPressed: () {
                      textEditingController.clear();
                      if (controller == _originController) {
                        _originLocation = null;
                      }
                    },
                  )
                : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            color: navBgColor, // Color oscuro para el desplegable
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 48, // Ajustar al padding
              height: 200,
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final PlaceSuggestion option = options.elementAt(index);
                  return ListTile(
                    leading: const Icon(Icons.location_city, color: Colors.white54),
                    title: Text(
                      option.address,
                      style: TextStyle(color: textMain, fontSize: 14),
                    ),
                    onTap: () {
                      onSelected(option);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
