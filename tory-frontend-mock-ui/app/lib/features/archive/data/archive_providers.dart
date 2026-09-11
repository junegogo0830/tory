import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/news_item.dart';
import '../../../data/repositories/repository_providers.dart';

final newsByLocationProvider =
    FutureProvider.family<List<NewsItem>, String>((ref, locationId) {
  final repo = ref.watch(archiveRepositoryProvider);
  return repo.getNewsByLocation(locationId);
});
