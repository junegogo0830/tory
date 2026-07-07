import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/archive/presentation/archive_screen.dart';
import '../../features/compare/presentation/compare_screen.dart';
import '../../features/course/presentation/course_detail_screen.dart';
import '../../features/course/presentation/course_list_screen.dart';
import '../../features/home/presentation/explore_screen.dart';
import '../../features/home/presentation/home_screen.dart';
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
          GoRoute(path: '/explore', builder: (context, state) => const ExploreScreen()),
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
      path: '/compare/:locationId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => CompareScreen(
        locationId: state.pathParameters['locationId']!,
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
  ],
);
