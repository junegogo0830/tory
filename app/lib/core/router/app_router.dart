import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/archive/presentation/archive_screen.dart';
import '../../features/community/presentation/community_board_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/compare/presentation/compare_screen.dart';
import '../../features/compare/presentation/roadview_screen.dart';
import '../../features/course/presentation/course_detail_screen.dart';
import '../../features/course/presentation/course_list_screen.dart';
import '../../features/course/presentation/nearby_map_screen.dart';
import '../../features/home/presentation/category_restaurant_list_screen.dart';
import '../../features/home/presentation/explore_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/kakao_restaurant_list_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import 'app_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/community', builder: (context, state) => const CommunityScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/course', builder: (context, state) => const CourseListScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        ]),
      ],
    ),
    GoRoute(
      path: '/explore',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExploreScreen(),
    ),
    GoRoute(
      path: '/compare/:locationId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => CompareScreen(
        locationId: state.pathParameters['locationId']!,
      ),
    ),
    GoRoute(
      path: '/roadview/:locationId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => RoadviewScreen(
        locationId: state.pathParameters['locationId']!,
        locationName: state.uri.queryParameters['name'] ?? '이 거리',
      ),
    ),
    GoRoute(
      path: '/archive/:locationId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => ArchiveScreen(
        locationId: state.pathParameters['locationId']!,
      ),
    ),
    GoRoute(
      path: '/course/:courseId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => CourseDetailScreen(
        courseId: state.pathParameters['courseId']!,
      ),
    ),
    GoRoute(
      path: '/community/:region/:boardId',
      parentNavigatorKey: _rootNavigatorKey,
      // go_router가 매칭된 경로 세그먼트를 이미 Uri.decodeComponent로 한 번 디코딩해서
      // pathParameters에 넣어준다 — 여기서 또 디코딩하면 순수 한글(퍼센트 인코딩 없는
      // 문자열)에 대해 "Illegal percent encoding in URI" 예외가 터진다(실제로 재현 확인).
      builder: (context, state) => CommunityBoardScreen(
        region: state.pathParameters['region']!,
        boardId: state.pathParameters['boardId']!,
      ),
    ),
    GoRoute(
      path: '/restaurants/:category',
      parentNavigatorKey: _rootNavigatorKey,
      // go_router가 이미 디코딩해서 준다 — 다시 디코딩하면 안 된다(커뮤니티
      // 라우트에서 겪은 "Illegal percent encoding" 문제와 같은 이유).
      builder: (context, state) => CategoryRestaurantListScreen(
        category: state.pathParameters['category']!,
      ),
    ),
    GoRoute(
      path: '/kakao-restaurants',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final lat = state.uri.queryParameters['lat'];
        final lng = state.uri.queryParameters['lng'];
        return KakaoRestaurantListScreen(
          lat: lat != null ? double.parse(lat) : null,
          lng: lng != null ? double.parse(lng) : null,
        );
      },
    ),
    GoRoute(
      path: '/nearby-map',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => NearbyMapScreen(
        lat: double.parse(state.uri.queryParameters['lat']!),
        lng: double.parse(state.uri.queryParameters['lng']!),
      ),
    ),
  ],
);
