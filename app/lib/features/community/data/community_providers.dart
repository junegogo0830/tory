import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/community_post.dart';
import '../../../data/models/neighbor.dart';
import '../../../data/repositories/repository_providers.dart';

typedef RegionBoard = ({String region, String board});

/// 지역+게시판별 피드. 둘 중 하나라도 바뀌면 자동으로 다시 불러온다.
final communityFeedProvider =
    FutureProvider.family<List<CommunityPost>, RegionBoard>((ref, key) {
      final repo = ref.watch(communityRepositoryProvider);
      return repo.getPosts(key.region, board: key.board);
    });

/// 홈 화면 "커뮤니티 새 소식" 미리보기용 — 추억 게시판 최근 3개만.
final communityPreviewProvider =
    FutureProvider.family<List<CommunityPost>, String>((ref, region) {
      final repo = ref.watch(communityRepositoryProvider);
      return repo.getPosts(region, board: 'memory', limit: 3);
    });

/// "친구찾기" — 같은 "내 동네"에 있는 다른 사용자들.
final neighborsProvider = FutureProvider.family<List<Neighbor>, String>((ref, region) {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.neighbors(region);
});

final blockedUsersProvider = FutureProvider((ref) {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.blockedUsers();
});
