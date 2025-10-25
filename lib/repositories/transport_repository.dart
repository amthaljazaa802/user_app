import '../models/bus.dart';
import '../models/bus_line.dart';
import '../models/bus_stop.dart';
import '../services/tracking_service.dart';

abstract class TransportRepository {
  List<Bus> get buses;
  List<BusStop> get busStops;
  List<BusLine> get busLines;

  Stream<List<Bus>> get busStream;
  Stream<List<BusStop>> get busStopsStream;
  Stream<List<BusLine>> get busLinesStream;

  Future<void> fetchInitialData();
  void dispose();
}

class TrackingTransportRepository implements TransportRepository {
  final TrackingService _service;

  TrackingTransportRepository(this._service);

  @override
  List<Bus> get buses => _service.buses;

  @override
  List<BusStop> get busStops => _service.busStops;

  @override
  List<BusLine> get busLines => _service.busLines;

  @override
  Stream<List<Bus>> get busStream => _service.busStream;

  @override
  Stream<List<BusStop>> get busStopsStream => _service.busStopsStream;

  @override
  Stream<List<BusLine>> get busLinesStream => _service.busLinesStream;

  @override
  Future<void> fetchInitialData() => _service.fetchInitialData();

  @override
  void dispose() => _service.dispose();
}
