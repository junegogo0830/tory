import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/hometown_location.dart';
import '../../../data/repositories/repository_providers.dart';

final recentLocationsProvider = FutureProvider<List<HometownLocation>>((ref) {
  final repo = ref.watch(locationRepositoryProvider);
  return repo.getRecentLocations();
});
