import 'package:latlong2/latlong.dart';
import 'bus_stop.dart';

class BusLine {
  final String id;
  final String name;
  final String description;
  final List<BusStop> stops;
  final List<LatLng> path;

  BusLine({
    required this.id,
    required this.name,
    required this.description,
    required this.stops,
    required this.path,
  });

  // --- دالة جديدة لتحويل بيانات JSON القادمة من الخادم ---
  factory BusLine.fromJson(Map<String, dynamic> json) {
    // هذا الكود يفترض أن الخادم يرسل قائمة كاملة من كائنات المحطات
    final stopsList =
        (json['stops'] as List<dynamic>?)
            ?.map((stopJson) => BusStop.fromJson(stopJson))
            .toList() ??
        [];

    // هذا الكود يفترض أن الخادم يرسل قائمة من الإحداثيات
    final pathList =
        (json['path'] as List<dynamic>?)
            ?.map((point) => LatLng(point['lat'], point['lng']))
            .toList() ??
        [];

    return BusLine(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      stops: stopsList,
      path: pathList,
    );
  }
}
