import 'package:latlong2/latlong.dart';

class BusStop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  BusStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  // دالة لتحويل JSON إلى كائن BusStop
  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      id: json['id'],
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
    );
  }

  // للوصول السهل إلى الموقع كـ LatLng
  LatLng get position => LatLng(latitude, longitude);
}
