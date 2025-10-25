import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/bus.dart';
import '../../../models/bus_line.dart';
import '../../../models/bus_stop.dart';

class BusStopPopup extends StatefulWidget {
  final BusStop stop;
  final List<Bus> allBuses;
  final List<BusLine> allBusLines;

  const BusStopPopup({
    Key? key,
    required this.stop,
    required this.allBuses,
    required this.allBusLines,
  }) : super(key: key);

  @override
  State<BusStopPopup> createState() => _BusStopPopupState();
}

class _BusStopPopupState extends State<BusStopPopup> {
  String? _estimatedTime;
  String? _routeName;
  String? _expectedAt; // precomputed, instead of TimeOfDay.now() in build
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateArrivalTime();
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
      final expectedAt = _expectedTimeString(time);

      if (mounted) {
        setState(() {
          _estimatedTime = time;
          _routeName = routeName;
          _expectedAt = expectedAt;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _estimatedTime = 'لا حافلات قريبة';
          _routeName = 'غير متوفر';
          _expectedAt = null;
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

  String _expectedTimeString(String etaMinutesStr) {
    final minutes = int.tryParse(etaMinutesStr) ?? 0;
    final expected = DateTime.now().add(Duration(minutes: minutes));
    final tod = TimeOfDay.fromDateTime(expected);
    return tod.format(context);
  }

  String? _getLineNameById(String lineId) {
    try {
      return widget.allBusLines.firstWhere((line) => line.id == lineId).name;
    } catch (e) {
      return 'خط غير معروف';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.route, color: Colors.blue, size: 28),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'الخط القادم',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _isLoading ? '...' : (_routeName ?? '...'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              TextButton(onPressed: () {}, child: const Text('تحرير')),
            ],
          ),
          const Divider(height: 20, thickness: 1),
          Row(
            children: [
              Column(
                children: [
                  Text(
                    _isLoading ? '...' : (_estimatedTime ?? '-'),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('دقيقة', style: TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(width: 16),
              // Avoid intrinsic layout caused by VerticalDivider in Row
              Container(width: 1, height: 48, color: Colors.black12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الموقف: ${widget.stop.id}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.stop.name,
                            style: const TextStyle(color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_filled,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isLoading
                              ? '...'
                              : 'الوقت المتوقع: ${_expectedAt ?? "-"}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
