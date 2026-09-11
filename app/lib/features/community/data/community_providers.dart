import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/community_post.dart';
import '../../../data/repositories/repository_providers.dart';

/// 지역별 커뮤니티 피드. region이 바뀌면(내 동네 재설정 등) 자동으로 다시 불러온다.
final communityFeedProvider = FutureProvider.family<List<CommunityPost>, String>((ref, region) {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.getPosts(region);
});
