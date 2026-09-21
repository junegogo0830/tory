import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/community_post.dart';
import '../../../data/models/neighbor.dart';
import '../../../data/models/region_stats.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../auth/data/auth_providers.dart';

/// 내가 가입한 모든 동네(최근 가입 순) — 커뮤니티 탭 지역 토글에 쓴다.
final myRegionsProvider = FutureProvider<List<String>>((ref) {
  if (!(ref.watch(authStateProvider).value ?? false)) return Future.value([]);
  final repo = ref.watch(communityRepositoryProvider);
  return repo.myRegions();
});

/// 게시판별 카테고리 목록(글쓰기 태그 버튼/목록 필터 토글용) — 앱 내내 안 바뀌는
/// 값이라 한 번만 불러와 캐싱한다.
final communityPostCategoriesProvider = FutureProvider<Map<String, List<String>>>((ref) {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.postCategories();
});

/// 새 지역 가입 확인 화면용 통계.
final regionStatsProvider = FutureProvider.family<RegionStats, String>((ref, region) {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.regionStats(region);
});

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

/// 장소별 추억 타임라인 — 연도순 전체 목록.
final communityTimelineProvider = FutureProvider.family<List<CommunityPost>, String>((ref, region) {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.getTimeline(region);
});

/// "동창찾기" 등 home_region 없이 활동 기준으로 이웃을 찾는 스코프(학교 등)에서 쓴다.
final activeAuthorsProvider = FutureProvider.family<List<Neighbor>, String>((ref, region) {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.activeAuthors(region);
});

/// 홈 화면 "우리 동네 최신 이야기" — 타임캡슐을 뺀 4개 게시판(자유/추억/주민/
/// 관광정보)에서 최근 글을 걷어와 하나의 최신순 목록으로 섞는다. 게시판별
/// 목록 API만 여러 번 호출하는 방식이라 백엔드 변경이 필요 없다.
const _kLatestStoryBoards = ['free', 'memory', 'resident', 'info'];

final communityLatestStoriesProvider =
    FutureProvider.family<List<CommunityPost>, String>((ref, region) async {
      final repo = ref.watch(communityRepositoryProvider);
      final results = await Future.wait(
        _kLatestStoryBoards.map((board) => repo.getPosts(region, board: board, limit: 4)),
      );
      final posts = results.expand((list) => list).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts.take(6).toList();
    });

/// 홈 화면 "오늘의 추억" — 추억 게시판 글 중 하루 동안은 같은 글이 보이도록
/// 날짜로 시드를 고정해 하나를 뽑는다(진짜 랜덤이면 새로고침마다 바뀌어 어색함).
final todaysMemoryProvider = FutureProvider.family<CommunityPost?, String>((ref, region) async {
  final repo = ref.watch(communityRepositoryProvider);
  final posts = await repo.getPosts(region, board: 'memory', limit: 30);
  if (posts.isEmpty) return null;
  final daySeed = DateTime.now().difference(DateTime(2026)).inDays;
  return posts[daySeed % posts.length];
});
