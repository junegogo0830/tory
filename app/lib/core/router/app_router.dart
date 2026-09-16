import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/archive/presentation/archive_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/community/presentation/blocked_users_screen.dart';
import '../../features/community/presentation/classmates_screen.dart';
import '../../features/community/presentation/community_board_screen.dart';
import '../../features/community/presentation/community_map_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/community/presentation/memory_timeline_screen.dart';
import '../../features/community/presentation/neighbors_screen.dart';
import '../../features/community/presentation/school_community_screen.dart';
import '../../features/community/presentation/user_posts_screen.dart';
import '../../features/friend_finder/presentation/chat_thread_screen.dart';
import '../../features/friend_finder/presentation/connection_requests_screen.dart';
import '../../features/friend_finder/presentation/connections_screen.dart';
import '../../features/friend_finder/presentation/friend_finder_flow_screen.dart';
import '../../features/friend_finder/presentation/memory_profile_screen.dart';
import '../../features/friend_finder/presentation/my_memory_attributes_screen.dart';
import '../../features/compare/presentation/compare_screen.dart';
import '../../features/compare/presentation/roadview_screen.dart';
import '../../features/course/presentation/course_detail_screen.dart';
import '../../features/course/presentation/course_list_screen.dart';
import '../../features/course/presentation/nearby_map_screen.dart';
import '../../features/custom_course/presentation/custom_course_create_screen.dart';
import '../../features/custom_course/presentation/custom_course_detail_screen.dart';
import '../../features/custom_course/presentation/custom_course_list_screen.dart';
import '../../features/custom_course/presentation/custom_course_map_screen.dart';
import '../../features/home/presentation/category_restaurant_list_screen.dart';
import '../../features/home/presentation/explore_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/kakao_restaurant_list_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/about_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/my_courses_screen.dart';
import '../../features/profile/presentation/my_custom_courses_screen.dart';
import '../../features/profile/presentation/my_memories_screen.dart';
import '../../features/profile/presentation/profile_info_edit_screen.dart';
import '../../features/profile/presentation/saved_courses_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import 'app_shell.dart';
import '../../features/community/presentation/community_post_editor_screen.dart';
import '../../features/community/presentation/community_post_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/post/:postId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => CommunityPostScreen(
        postId: int.tryParse(state.pathParameters['postId']!) ?? -1,
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/community',
              builder: (context, state) => const CommunityScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/course',
              builder: (context, state) => const CourseListScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/login',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/explore',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExploreScreen(),
    ),
    GoRoute(
      path: '/community/write',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          CommunityPostEditorScreen(args: state.extra! as CommunityPostEditorArgs),
    ),
    GoRoute(
      path: '/friends/find',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const FriendFinderFlowScreen(),
    ),
    GoRoute(
      path: '/memory-profile/:userId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          MemoryProfileScreen(userId: int.parse(state.pathParameters['userId']!)),
    ),
    GoRoute(
      path: '/friends/requests',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ConnectionRequestsScreen(),
    ),
    GoRoute(
      path: '/friends/connections',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ConnectionsScreen(),
    ),
    GoRoute(
      path: '/friends/chat/:connectionId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          ChatThreadScreen(connectionId: int.parse(state.pathParameters['connectionId']!)),
    ),
    GoRoute(
      path: '/friends/my-attributes',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MyMemoryAttributesScreen(),
    ),
    GoRoute(
      path: '/compare/:locationId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          CompareScreen(locationId: state.pathParameters['locationId']!),
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
      builder: (context, state) =>
          ArchiveScreen(locationId: state.pathParameters['locationId']!),
    ),
    GoRoute(
      path: '/course/:courseId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          CourseDetailScreen(courseId: state.pathParameters['courseId']!),
    ),
    GoRoute(
      path: '/custom-courses',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CustomCourseListScreen(),
    ),
    GoRoute(
      path: '/custom-courses/create',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CustomCourseCreateScreen(),
    ),
    GoRoute(
      path: '/custom-courses/:courseId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => CustomCourseDetailScreen(
        courseId: int.tryParse(state.pathParameters['courseId']!) ?? -1,
      ),
    ),
    GoRoute(
      path: '/custom-courses/:courseId/edit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => CustomCourseCreateScreen(
        editCourseId: int.tryParse(state.pathParameters['courseId']!),
      ),
    ),
    GoRoute(
      path: '/custom-courses/:courseId/map',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => CustomCourseMapScreen(
        courseId: int.tryParse(state.pathParameters['courseId']!) ?? -1,
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
      path: '/community-map/:region/:boardId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => CommunityMapScreen(
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
      builder: (context, state) => KakaoRestaurantListScreen(
        initialRegion: state.uri.queryParameters['region'],
        initialCuisine: state.uri.queryParameters['cuisine'],
      ),
    ),
    GoRoute(
      path: '/nearby-map',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NearbyMapScreen(),
    ),
    GoRoute(
      path: '/notifications',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/blocked-users',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BlockedUsersScreen(),
    ),
    GoRoute(
      path: '/neighbors/:region',
      parentNavigatorKey: _rootNavigatorKey,
      // go_router가 이미 디코딩해서 준다 — 커뮤니티 라우트와 같은 이유로 다시 디코딩하지 않는다.
      builder: (context, state) => NeighborsScreen(region: state.pathParameters['region']!),
    ),
    GoRoute(
      path: '/neighbors/:region/:authorId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => UserPostsScreen(
        region: state.pathParameters['region']!,
        authorId: int.parse(state.pathParameters['authorId']!),
        authorNickname: state.uri.queryParameters['nickname'] ?? '이웃',
      ),
    ),
    GoRoute(
      path: '/my-posts/:authorId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => UserPostsScreen(
        authorId: int.parse(state.pathParameters['authorId']!),
        authorNickname: state.uri.queryParameters['nickname'] ?? '나',
      ),
    ),
    GoRoute(
      path: '/my-custom-courses',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MyCustomCoursesScreen(),
    ),
    GoRoute(
      path: '/saved-courses',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SavedCoursesScreen(),
    ),
    GoRoute(
      path: '/memory-timeline/:region',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => MemoryTimelineScreen(region: state.pathParameters['region']!),
    ),
    GoRoute(
      path: '/school-community/:schoolRegion',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          SchoolCommunityScreen(schoolRegion: state.pathParameters['schoolRegion']!),
    ),
    GoRoute(
      path: '/classmates/:schoolRegion',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => ClassmatesScreen(schoolRegion: state.pathParameters['schoolRegion']!),
    ),
    GoRoute(
      path: '/my-memories',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MyMemoriesScreen(),
    ),
    GoRoute(
      path: '/my-courses',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MyCoursesScreen(),
    ),
    GoRoute(
      path: '/about',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AboutScreen(),
    ),
    GoRoute(
      path: '/edit-profile',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/profile/info',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ProfileInfoEditScreen(),
    ),
  ],
);
