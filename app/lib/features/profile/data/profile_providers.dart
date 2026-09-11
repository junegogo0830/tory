import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/repository_providers.dart';

final profileProvider = FutureProvider<Profile>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getProfile();
});
