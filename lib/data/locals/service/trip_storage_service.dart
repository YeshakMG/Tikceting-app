import 'package:hive/hive.dart';
import 'package:oro_ticket_app/data/locals/hive_boxes.dart';
import 'package:oro_ticket_app/data/locals/models/trip_model.dart';

class TripStorageService {
  final Box<TripModel> _tripBox = Hive.box<TripModel>(HiveBoxes.tripBox);

  /// Save a new trip
  Future<void> saveTrip(TripModel trip) async {
    await _tripBox.add(trip);
  }

  /// Get all trips (e.g. for sync)
  List<TripModel> getAllTrips() {
    return _tripBox.values.toList();
  }

  /// Clear all trips after successful sync
  Future<void> clearTrips() async {
    await _tripBox.clear();
  }

  /// Delete specific trip by key if you sync one by one
  Future<void> deleteTrip(int key) async {
    await _tripBox.delete(key);
  }
}
