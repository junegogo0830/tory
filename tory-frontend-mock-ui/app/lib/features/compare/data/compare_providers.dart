import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/hometown_location.dart';
import '../../../data/repositories/repository_providers.dart';

final locationDetailProvider =
    FutureProvider.family<HometownLocation?, String>((ref, locationId) {
  final repo = ref.watch(locationRepositoryProvider);
  return repo.getLocationById(locationId);
});
