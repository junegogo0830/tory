import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/custom_course.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/photo_fallback.dart';
import '../../auth/data/auth_providers.dart';
import '../data/custom_course_providers.dart';

const _allCategories = ['전체', ...customCourseCategories];

/// "코스 커스텀" — 사용자가 직접 장소를 골라 만든 코스를 둘러보는 목록.
/// 누구나 둘러볼 수 있지만, 새로 만들려면(FAB) 로그인이 필요하다.
class CustomCourseListScreen extends ConsumerStatefulWidget {
  const CustomCourseListScreen({super.key});

  @override
  ConsumerState<CustomCourseListScreen> createState() => _CustomCourseListScreenState();
}

class _CustomCourseListScreenState extends ConsumerState<CustomCourseListScreen> {
  int _categoryIndex = 0;
  String _sort = 'recent';

  Future<void> _createNew() async {
    final isLoggedIn = ref.read(authStateProvider).value ?? false;
    if (!isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('코스를 만들려면 먼저 로그인해주세요')),
      );
      context.go('/profile');
      return;
    }
    // 등록 성공 시 목록 갱신은 생성 화면이 customCourseListProvider를
    // 직접 invalidate한다(어느 카테고리/정렬로 돌아오든 반영되게).
    await context.push('/custom-courses/create');
  }

  @override
  Widget build(BuildContext context) {
    final category = _allCategories[_categoryIndex];
    final coursesAsync = ref.watch(
      customCourseListProvider((category: category == '전체' ? null : category, sort: _sort)),
    );

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('코스 커스텀')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: _createNew,
        icon: const Icon(Icons.add),
        label: const Text('코스 만들기'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _allCategories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final selected = _categoryIndex == index;
                            return ChoiceChip(
                              label: Text(_allCategories[index]),
                              selected: selected,
                              onSelected: (_) => setState(() => _categoryIndex = index),
                              showCheckmark: false,
                              selectedColor: AppColors.accent,
                              backgroundColor: AppColors.surface,
                              side: BorderSide(color: selected ? AppColors.accent : AppColors.hairline),
                              shape: const StadiumBorder(),
                              labelStyle: AppTypography.footnote.copyWith(
                                color: selected ? Colors.white : AppColors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              visualDensity: VisualDensity.compact,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _SortTab(label: '최신순', selected: _sort == 'recent', onTap: () => setState(() => _sort = 'recent')),
                          const SizedBox(width: 14),
                          _SortTab(label: '인기순', selected: _sort == 'popular', onTap: () => setState(() => _sort = 'popular')),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: coursesAsync.when(
                    data: (courses) {
                      if (courses.isEmpty) {
                        return const EmptyState(
                          icon: Icons.route_outlined,
                          title: '아직 만들어진 코스가 없어요',
                          message: '내가 좋아하는 장소들로 첫 코스를 만들어보세요.',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
                        itemCount: courses.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _CustomCourseRow(course: courses[index]),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                    error: (_, _) => Center(child: Text('불러오지 못했어요', style: AppTypography.subhead)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SortTab extends StatelessWidget {
  const _SortTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: AppTypography.footnote.copyWith(
          color: selected ? AppColors.accentDeep : AppColors.inkTertiary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _CustomCourseRow extends StatelessWidget {
  const _CustomCourseRow({required this.course});

  final CustomCourseSummary course;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/custom-courses/${course.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.tile),
            child: SizedBox(
              width: 64,
              height: 64,
              child: course.thumbnailUrl == null
                  ? const PhotoFallback(icon: Icons.route_outlined)
                  : AppNetworkImage(
                      imageUrl: course.thumbnailUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const PhotoFallback(icon: Icons.route_outlined),
                      errorWidget: (_, _, _) => const PhotoFallback(icon: Icons.route_outlined),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.pastelMint,
                        borderRadius: BorderRadius.circular(AppRadius.tag),
                      ),
                      child: Text(
                        course.category,
                        style: AppTypography.caption.copyWith(color: AppColors.accentDeep, fontWeight: FontWeight.w600, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '장소 ${course.placeCount}곳',
                        style: AppTypography.caption.copyWith(color: AppColors.inkTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  course.title,
                  style: AppTypography.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  course.authorNickname,
                  style: AppTypography.caption.copyWith(color: AppColors.inkTertiary),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Icon(Icons.thumb_up_alt_outlined, size: 15, color: AppColors.accentDeep),
              const SizedBox(height: 2),
              Text('${course.score}', style: AppTypography.caption.copyWith(color: AppColors.accentDeep, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Icon(Icons.mode_comment_outlined, size: 14, color: AppColors.inkTertiary),
              const SizedBox(height: 2),
              Text('${course.commentCount}', style: AppTypography.caption.copyWith(color: AppColors.inkTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}
