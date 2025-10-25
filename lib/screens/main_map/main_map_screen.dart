import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../routes/routes_screen.dart';
import '../complaints/complaints_screen.dart';
import '../payment_screen.dart';
import '../../models/bus.dart';
import '../../models/bus_stop.dart';
import '../../repositories/transport_repository.dart';
import 'widgets/bus_stop_popup.dart';

class MainMapScreen extends StatefulWidget {
  const MainMapScreen({super.key});

  @override
  State<MainMapScreen> createState() => _MainMapScreenState();
}

enum MapStatus { loading, success, failure }

enum MapFilter { all, nearMe, inService, delayed }

class _MainMapScreenState extends State<MainMapScreen> {
  // --- Controller جديد للنوافذ المنبثقة ---
  final PopupController _popupLayerController = PopupController();

  // --- كل المتغيرات الأخرى تبقى كما هي ---
  final MapController _mapController = MapController();
  late final TransportRepository _repository;
  List<BusStop> _busStops = [];
  List<Bus> _buses = [];
  // Cached marker lists to reduce per-build allocations
  List<Marker> _cachedStopMarkers = const [];
  List<Marker> _cachedBusMarkers = const [];
  MapStatus _status = MapStatus.loading;
  String _errorMessage = '';
  StreamSubscription? _stopsSubscription;
  StreamSubscription? _busesSubscription;
  Timer? _updateTimer;
  DateTime _lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastDataUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  MapFilter _filter = MapFilter.all;
  LatLng? _nearbyCenter;
  final double _nearbyRadiusMeters = 500.0;
  Bus? _nearestBus;
  String? _estimatedTime;
  String? _nearestBusLineName;

  @override
  void initState() {
    super.initState();
    _repository = Provider.of<TransportRepository>(context, listen: false);

    // Precache marker image for smoother first render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(
        const AssetImage('lib/assets/images/thumbnail.png'),
        context,
      );
    });

    _stopsSubscription = _repository.busStopsStream.listen(
      (stops) {
        if (mounted) setState(() => _busStops = stops);
        _rebuildStopMarkers();
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = 'فشل في جلب بيانات المواقف';
            _status = MapStatus.failure;
          });
        }
      },
    );

    _busesSubscription = _repository.busStream.listen(
      (buses) {
        if (mounted) {
          setState(() {
            _buses = buses;
            _status = MapStatus.success;
            _lastDataUpdate = DateTime.now();
          });
        }
        _rebuildBusMarkers();
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = 'فشل في جلب بيانات الحافلات';
            _status = MapStatus.failure;
          });
        }
      },
    );

    _repository.fetchInitialData();

    _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final now = DateTime.now();
      // Throttle UI updates to ~1 Hz
      if (now.difference(_lastUiUpdate).inMilliseconds < 900) return;
      _lastUiUpdate = now;
      _updateNearestBusInfo();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    _stopsSubscription?.cancel();
    _busesSubscription?.cancel();
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(33.5138, 36.2765),
              initialZoom: 14.0,
              onTap: (_, __) {
                _popupLayerController.hideAllPopups();
                // Clear any selection state (nearest bus, etc.)
                if (_nearestBus != null ||
                    _estimatedTime != null ||
                    _nearestBusLineName != null) {
                  setState(() {
                    _nearestBus = null;
                    _estimatedTime = null;
                    _nearestBusLineName = null;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.bus_tracking_app',
              ),
              // طبقة تجميع العلامات للحافلات
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  markers: _cachedBusMarkers,
                  maxClusterRadius: 45,
                  size: const Size(40, 40),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(32),
                  maxZoom: 18,
                  builder: (context, markers) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        markers.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
              // الكود الجديد الصحيح
              RepaintBoundary(
                child: PopupMarkerLayer(
                  options: PopupMarkerLayerOptions(
                    popupController: _popupLayerController,
                    // أظهر النوافذ المنبثقة لمواقف الحافلات فقط
                    markers: _cachedStopMarkers,
                    // --- بداية الإصلاح ---
                    popupDisplayOptions: PopupDisplayOptions(
                      builder: (BuildContext context, Marker marker) {
                        // كل منطق بناء النافذة المنبثقة يأتي هنا
                        if (marker.key is ValueKey<String>) {
                          final keyString =
                              (marker.key as ValueKey<String>).value;
                          if (keyString.startsWith('stop_')) {
                            final stopId = keyString.substring(5);
                            final stop = _busStops.firstWhere(
                              (s) => s.id == stopId,
                            );
                            return BusStopPopup(
                              stop: stop,
                              allBuses: _buses,
                              allBusLines: _repository.busLines,
                              popupController: _popupLayerController,
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    // --- نهاية الإصلاح ---
                  ),
                ),
              ),
            ],
          ),
          if (_status == MapStatus.loading)
            Container(
              color: const Color.fromARGB(204, 255, 255, 255),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('جارٍ التحديث…'),
                  ],
                ),
              ),
            ),
          if (_status == MapStatus.failure)
            Container(
              color: const Color.fromARGB(204, 255, 255, 255),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 50,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'حدث خطأ',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_errorMessage, textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          setState(() => _status = MapStatus.loading);
                          _repository.fetchInitialData();
                        },
                        label: const Text('حاول مرة أخرى'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_status == MapStatus.success) ...[
            _buildFloatingSearchBar(),
            _buildFilterChips(),
            _buildFloatingActionButtons(),
            _buildBottomInfoSheet(),
            _buildLastUpdatedChip(),
          ],
        ],
      ),
    );
  }

  Widget _buildLastUpdatedChip() {
    if (_lastDataUpdate.millisecondsSinceEpoch == 0) {
      return const SizedBox.shrink();
    }
    final now = DateTime.now();
    final seconds = now.difference(_lastDataUpdate).inSeconds;
    String friendly;
    if (seconds < 5) {
      friendly = 'الآن';
    } else if (seconds < 60) {
      friendly = 'قبل ${seconds}ث';
    } else {
      final minutes = (seconds / 60).floor();
      friendly = 'قبل ${minutes} دقيقة';
    }
    return Positioned(
      top: 15,
      right: 15,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Row(
          children: [
            const Icon(Icons.update, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text(
              'آخر تحديث: $friendly',
              style: const TextStyle(color: Colors.black87, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  List<Marker> _buildStopMarkers() {
    final stops = _applyStopFilter(_busStops);
    return stops.map((stop) {
      return Marker(
        key: ValueKey('stop_${stop.id}'),
        width: 40.0,
        height: 40.0,
        point: stop.position,
        child: Image.asset('lib/assets/images/thumbnail.png'),
      );
    }).toList();
  }

  List<Marker> _buildBusMarkers() {
    final buses = _applyBusFilter(_buses);
    return buses.map((bus) {
      return Marker(
        key: ValueKey('bus_${bus.id}'),
        width: 40.0,
        height: 40.0,
        point: bus.position,
        child: Icon(
          Icons.directions_bus_rounded,
          color: _getBusColor(bus.status),
          size: 35,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 2.0)],
        ),
      );
    }).toList();
  }

  void _rebuildStopMarkers() {
    _cachedStopMarkers = _buildStopMarkers();
  }

  void _rebuildBusMarkers() {
    _cachedBusMarkers = _buildBusMarkers();
  }

  Future<void> _updateNearestBusInfo() async {
    if (_status != MapStatus.success || _buses.isEmpty) return;
    try {
      final userLocationData = await _determinePosition();
      final userLocation = LatLng(
        userLocationData.latitude,
        userLocationData.longitude,
      );
      final nearest = _findNearestBus(userLocation, _buses);
      if (nearest != null) {
        final distance = Geolocator.distanceBetween(
          userLocation.latitude,
          userLocation.longitude,
          nearest.position.latitude,
          nearest.position.longitude,
        );
        final lineName = _getLineNameById(nearest.lineId) ?? 'خط غير معروف';
        final newEta = _estimateArrivalTime(distance);
        final shouldUpdate =
            _nearestBus?.id != nearest.id ||
            _estimatedTime != newEta ||
            _nearestBusLineName != lineName;
        if (mounted && shouldUpdate) {
          setState(() {
            _nearestBus = nearest;
            _estimatedTime = newEta;
            _nearestBusLineName = lineName;
          });
        }
      }
    } catch (e) {
      debugPrint('Error updating nearest bus info: $e');
      if (mounted) setState(() => _nearestBus = null);
    }
  }

  String? _getLineNameById(String lineId) {
    try {
      return _repository.busLines.firstWhere((line) => line.id == lineId).name;
    } catch (e) {
      return null;
    }
  }

  Bus? _findNearestBus(LatLng userLocation, List<Bus> buses) {
    if (buses.isEmpty) return null;
    Bus? nearestBus;
    double smallestD2 = double.infinity;
    for (final bus in buses) {
      final d2 = _distance2(userLocation, bus.position);
      if (d2 < smallestD2) {
        smallestD2 = d2;
        nearestBus = bus;
      }
    }
    return nearestBus;
  }

  // Fast approximate squared distance in degrees (good for nearest comparisons)
  double _distance2(LatLng a, LatLng b) {
    final dx = a.latitude - b.latitude;
    final dy = a.longitude - b.longitude;
    return dx * dx + dy * dy;
  }

  String _estimateArrivalTime(double distanceInMeters) {
    const averageBusSpeedKmh = 25.0;
    final speedMps = averageBusSpeedKmh * 1000 / 3600;
    if (distanceInMeters < 50) return 'قريب جدًا';
    final timeInSeconds = distanceInMeters / speedMps;
    final timeInMinutes = (timeInSeconds / 60).ceil();
    return ' ~ $timeInMinutes دقائق';
  }

  // --- Filters ---
  List<Bus> _applyBusFilter(List<Bus> list) {
    switch (_filter) {
      case MapFilter.inService:
        return list.where((b) => b.status == BusStatus.IN_SERVICE).toList();
      case MapFilter.delayed:
        return list.where((b) => b.status == BusStatus.DELAYED).toList();
      case MapFilter.nearMe:
        if (_nearbyCenter == null) return const <Bus>[];
        return list
            .where(
              (b) =>
                  Geolocator.distanceBetween(
                    _nearbyCenter!.latitude,
                    _nearbyCenter!.longitude,
                    b.position.latitude,
                    b.position.longitude,
                  ) <=
                  _nearbyRadiusMeters,
            )
            .toList();
      case MapFilter.all:
        return list;
    }
  }

  List<BusStop> _applyStopFilter(List<BusStop> list) {
    switch (_filter) {
      case MapFilter.nearMe:
        if (_nearbyCenter == null) return const <BusStop>[];
        return list
            .where(
              (s) =>
                  Geolocator.distanceBetween(
                    _nearbyCenter!.latitude,
                    _nearbyCenter!.longitude,
                    s.position.latitude,
                    s.position.longitude,
                  ) <=
                  _nearbyRadiusMeters,
            )
            .toList();
      default:
        return list;
    }
  }

  Widget _buildFilterChips() {
    return Positioned(
      top: 92.0,
      left: 15.0,
      right: 15.0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip('الكل', MapFilter.all),
            const SizedBox(width: 8),
            _chip('بالقرب منك', MapFilter.nearMe),
            const SizedBox(width: 8),
            _chip('في الخدمة', MapFilter.inService),
            const SizedBox(width: 8),
            _chip('متأخر', MapFilter.delayed),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, MapFilter value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (sel) async {
        if (!sel) return;
        if (value == MapFilter.nearMe) {
          try {
            final p = await _determinePosition();
            _nearbyCenter = LatLng(p.latitude, p.longitude);
          } catch (_) {
            // Keep center null if permission denied
            _nearbyCenter = null;
          }
        } else {
          _nearbyCenter = null;
        }
        setState(() {
          _filter = value;
        });
        _rebuildStopMarkers();
        _rebuildBusMarkers();
      },
      selectedColor: Colors.blue.shade100,
      backgroundColor: Colors.grey.shade200,
      labelStyle: TextStyle(
        color: selected ? Colors.blue.shade900 : Colors.black87,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? Colors.blue.shade300 : Colors.transparent,
        ),
      ),
    );
  }

  Future<void> _centerOnUserLocation() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري تحديد موقعك...'),
        duration: Duration(seconds: 2),
      ),
    );
    try {
      final position = await _determinePosition();
      _mapController.move(LatLng(position.latitude, position.longitude), 15.0);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لا يمكن تحديد الموقع: ${e.toString()}')),
      );
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('خدمات تحديد الموقع معطلة.');
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied)
        return Future.error('تم رفض صلاحيات الوصول للموقع.');
    }
    if (permission == LocationPermission.deniedForever)
      return Future.error('تم رفض صلاحيات الموقع بشكل دائم.');
    return await Geolocator.getCurrentPosition();
  }

  Color _getBusColor(BusStatus status) {
    switch (status) {
      case BusStatus.IN_SERVICE:
        return Colors.lightBlue;
      case BusStatus.DELAYED:
        return Colors.orange;
      case BusStatus.NOT_IN_SERVICE:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color backgroundColor = const Color(0xFF2C3E50),
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
        padding: const EdgeInsets.all(12),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _buildFloatingSearchBar() {
    return Positioned(
      top: 50.0,
      left: 15.0,
      right: 15.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30.0),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(38, 0, 0, 0),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const TextField(
          decoration: InputDecoration(
            hintText: 'ابحث عن محطة أو حافلة...',
            border: InputBorder.none,
            icon: Icon(Icons.search),
            suffixIcon: Icon(Icons.close),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Positioned(
      top: 120.0,
      right: 15.0,
      child: Column(
        children: [
          _buildCircularButton(
            icon: Icons.menu,
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const RoutesScreen()));
            },
            backgroundColor: Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildCircularButton(
            icon: Icons.my_location,
            onPressed: _centerOnUserLocation,
          ),
          const SizedBox(height: 12),
          _buildCircularButton(
            icon: Icons.refresh,
            onPressed: _resetMapView,
            backgroundColor: Colors.blueGrey,
          ),
          const SizedBox(height: 12),
          _buildCircularButton(
            icon: Icons.feedback_outlined,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ComplaintsScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildCircularButton(
            icon: Icons.qr_code_scanner,
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PaymentScreen()));
            },
          ),
        ],
      ),
    );
  }

  void _resetMapView() {
    // Try to fit all stops, fallback to initial center/zoom
    if (_busStops.isNotEmpty) {
      final latitudes = _busStops.map((s) => s.position.latitude);
      final longitudes = _busStops.map((s) => s.position.longitude);
      final minLat = latitudes.reduce((a, b) => a < b ? a : b);
      final maxLat = latitudes.reduce((a, b) => a > b ? a : b);
      final minLng = longitudes.reduce((a, b) => a < b ? a : b);
      final maxLng = longitudes.reduce((a, b) => a > b ? a : b);
      final bounds = LatLngBounds(
        LatLng(minLat, minLng),
        LatLng(maxLat, maxLng),
      );
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    } else {
      _mapController.move(const LatLng(33.5138, 36.2765), 14.0);
    }
    // Also clear popups and selection
    _popupLayerController.hideAllPopups();
    if (_nearestBus != null ||
        _estimatedTime != null ||
        _nearestBusLineName != null) {
      setState(() {
        _nearestBus = null;
        _estimatedTime = null;
        _nearestBusLineName = null;
      });
    }
  }

  Widget _buildBottomInfoSheet() {
    if (_nearestBus == null || _estimatedTime == null) {
      return const SizedBox.shrink();
    }
    return Positioned(
      bottom: 20.0,
      left: 20.0,
      right: 20.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15.0),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(26, 0, 0, 0),
              spreadRadius: 2,
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _nearestBusLineName ?? '...',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Row(
              children: [
                const Icon(Icons.directions_bus, color: Colors.grey),
                const SizedBox(width: 10),
                Text(
                  _estimatedTime!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.access_time, color: Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
