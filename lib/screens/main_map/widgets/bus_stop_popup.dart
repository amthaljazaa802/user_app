import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import '../../../models/bus.dart';
import '../../../models/bus_line.dart';
import '../../../models/bus_stop.dart';

class BusStopPopup extends StatefulWidget {
  final BusStop stop;
  final List<Bus> allBuses;
  final List<BusLine> allBusLines;
  final PopupController? popupController;

  const BusStopPopup({
    Key? key,
    required this.stop,
    required this.allBuses,
    required this.allBusLines,
    this.popupController,
  }) : super(key: key);

  @override
  State<BusStopPopup> createState() => _BusStopPopupState();
}

class _BusStopPopupState extends State<BusStopPopup> {
  String? _estimatedTime;
  String? _routeName;
  int? _expectedMinutes; // Store minutes instead of formatted string
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateArrivalTime();
    });
  }

  @override
  void didUpdateWidget(covariant BusStopPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    final busesChanged = !listEquals(widget.allBuses, oldWidget.allBuses);
    final linesChanged = !listEquals(widget.allBusLines, oldWidget.allBusLines);
    final stopChanged = widget.stop != oldWidget.stop;
    if (busesChanged || linesChanged || stopChanged) {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      _calculateArrivalTime();
    }
  }

  void _calculateArrivalTime() {
    final Bus? nearestBus = _findNearestBusToStop(widget.stop, widget.allBuses);

    if (nearestBus != null) {
      final distance = Geolocator.distanceBetween(
        nearestBus.position.latitude,
        nearestBus.position.longitude,
        widget.stop.position.latitude,
        widget.stop.position.longitude,
      );

      final time = _estimateArrivalTime(distance);
      final routeName = _getLineNameById(nearestBus.lineId);
      final expectedMinutes = int.tryParse(time) ?? 0;

      if (mounted) {
        setState(() {
          _estimatedTime = time;
          _routeName = routeName;
          _expectedMinutes = expectedMinutes;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _estimatedTime = 'لا حافلات قريبة';
          _routeName = 'غير متوفر';
          _expectedMinutes = null;
          _isLoading = false;
        });
      }
    }
  }

  Bus? _findNearestBusToStop(BusStop stop, List<Bus> buses) {
    if (buses.isEmpty) return null;
    return buses.reduce((a, b) {
      final da = _distance2(a.position, stop.position);
      final db = _distance2(b.position, stop.position);
      return da <= db ? a : b;
    });
  }

  double _distance2(LatLng a, LatLng b) {
    final dx = a.latitude - b.latitude;
    final dy = a.longitude - b.longitude;
    return dx * dx + dy * dy;
  }

  String _estimateArrivalTime(double distanceInMeters) {
    const averageBusSpeedKmh = 25.0;
    final speedMps = averageBusSpeedKmh * 1000 / 3600;
    if (distanceInMeters < 50) return '0';
    final timeInSeconds = distanceInMeters / speedMps;
    return (timeInSeconds / 60).ceil().toString();
  }

  String? _getLineNameById(String lineId) {
    try {
      return widget.allBusLines.firstWhere((line) => line.id == lineId).name;
    } catch (e) {
      return 'خط غير معروف';
    }
  }

  String _formatExpectedTime(int minutes) {
    final expected = DateTime.now().add(Duration(minutes: minutes));
    final hour = expected.hour;
    final minute = expected.minute;
    final period = hour >= 12 ? 'م' : 'ص';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.directions_bus,
                        color: Colors.blue,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'موقف الحافلة',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              widget.stop.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    if (widget.popupController != null) {
                      widget.popupController!.hideAllPopups();
                    }
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 1),
            // Next bus info
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              Row(
                children: [
                  const Icon(Icons.route, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'الخط القادم: ${_routeName ?? "غير متوفر"}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'الوصول بعد',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_estimatedTime ?? "-"} دقيقة',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  if (_expectedMinutes != null && _expectedMinutes! > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'الوقت المتوقع',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatExpectedTime(_expectedMinutes!),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
