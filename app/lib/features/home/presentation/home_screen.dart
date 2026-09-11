import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/hometown_location.dart';
import '../../../data/models/news_item.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/yetgil_mark.dart';
import '../../archive/data/archive_providers.dart';
import '../../compare/presentation/widgets/compare_slider.dart';
import '../../course/data/course_providers.dart';
import '../data/home_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _queryController = TextEditingController();
  Timer? _debounce;
  Timer? _carouselTimer;
  int _carouselIndex = 0;
  List<HometownLocation> _suggestions = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
    // 계속 첫 번째 장소(순천)만 보이지 않도록, 홈에 있는 동안 3초마다 자동으로
    // 다음 장소로 넘어간다. 검색 중일 땐 건드리지 않는다(자동완성 위로 화면이
    // 바뀌면 산만하다).
    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _queryController.text.trim().isNotEmpty) return;
      setState(() => _carouselIndex++);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _carouselTimer?.cancel();
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final query = _queryController.text.trim();
    _debounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    try {
      final results = await ref.read(locationRepositoryProvider).searchLocations(query);
      // 응답이 늦게 와서 이미 다른 검색어로 바뀌었으면 무시한다(오래된 결과로 덮어쓰기 방지).
      if (!mounted || _queryController.text.trim() != query) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || _queryController.text.trim() != query) return;
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
    }
  }

  void _selectSuggestion(HometownLocation location) {
    _debounce?.cancel();
    _queryController.clear();
    setState(() {
      _suggestions = [];
      _isSearching = false;
    });
    FocusScope.of(context).unfocus();
    context.push('/compare/${location.id}');
  }

  Future<void> _submitQuery() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    try {
      final location = await ref.read(locationRepositoryProvider).resolveFromQuery(query);
      if (mounted) context.push('/compare/${location.id}');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('장소를 찾지 못했어요. 다시 시도해주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentAsync = ref.watch(recentLocationsProvider);
    final isTyping = _queryController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: recentAsync.when(
              data: (locations) => _HomeContent(
                primary: locations.isNotEmpty ? locations[_carouselIndex % locations.length] : null,
                locationCount: locations.length,
                activeIndex: locations.isEmpty ? 0 : _carouselIndex % locations.length,
                controller: _queryController,
                onSubmit: _submitQuery,
                showSuggestions: isTyping,
                isSearching: _isSearching,
                suggestions: _suggestions,
                onSelectSuggestion: _selectSuggestion,
              ),
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
              error: (_, _) => Center(
                child: Text('홈 정보를 불러오지 못했어요', style: AppTypography.subhead),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.primary,
    required this.locationCount,
    required this.activeIndex,
    required this.controller,
    required this.onSubmit,
    required this.showSuggestions,
    required this.isSearching,
    required this.suggestions,
    required this.onSelectSuggestion,
  });

  final HometownLocation? primary;
  final int locationCount;
  final int activeIndex;
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool showSuggestions;
  final bool isSearching;
  final List<HometownLocation> suggestions;
  final ValueChanged<HometownLocation> onSelectSuggestion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
      children: [
        const _TopBar(),
        const SizedBox(height: 32),
        Text(
          '그리운 동네를 찾아보세요',
          style: AppTypography.largeTitle.copyWith(fontSize: 30, letterSpacing: -0.8),
        ),
        const SizedBox(height: 18),
        _SearchField(controller: controller, onSubmitted: onSubmit),
        if (showSuggestions) ...[
          const SizedBox(height: 8),
          _SearchSuggestions(
            isSearching: isSearching,
            suggestions: suggestions,
            onSelect: onSelectSuggestion,
          ),
        ],
        if (primary != null) ...[
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey(primary!.id),
              children: [
                _SelectedPlace(location: primary!),
                const SizedBox(height: 20),
                CompareSlider(
                  pastYear: primary!.pastYear,
                  currentYear: primary!.currentYear,
                  currentImageUrl: primary!.imageUrl,
                  height: 320,
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 700) {
                      return Column(
                        children: [
                          _NewsPanel(locationId: primary!.id),
                          const SizedBox(height: 16),
                          _CoursePanel(locationId: primary!.id),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _NewsPanel(locationId: primary!.id)),
                        const SizedBox(width: 16),
                        Expanded(child: _CoursePanel(locationId: primary!.id)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          if (locationCount > 1) ...[
            const SizedBox(height: 16),
            _CarouselDots(count: locationCount, activeIndex: activeIndex),
          ],
        ] else ...[
          const SizedBox(height: 40),
          const EmptyState(
            icon: Icons.location_on_outlined,
            title: '아직 둘러본 골목이 없어요',
            message: '고향 주소를 검색하면 그때 그 골목을 보여드릴게요.',
          ),
        ],
      ],
    );
  }
}

class _CarouselDots extends StatelessWidget {
  const _CarouselDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == activeIndex ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == activeIndex ? AppColors.accent : AppColors.hairline,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const YetgilMark(size: 30),
            const SizedBox(width: 10),
            Text('옛길', style: AppTypography.largeTitle.copyWith(fontSize: 27)),
          ],
        ),
        InkWell(
          onTap: () => context.go('/profile'),
          borderRadius: BorderRadius.circular(99),
          child: Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent, width: 1.4),
            ),
            child: const Icon(Icons.person, color: AppColors.accentDeep, size: 24),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(color: Color(0x16000000), blurRadius: 14, offset: Offset(0, 5)),
        ],
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onSubmitted(),
        decoration: InputDecoration(
          filled: false,
          hintText: '고향 주소, 학교, 살던 아파트',
          prefixIcon: const Icon(Icons.search, color: AppColors.inkSecondary, size: 27),
          suffixIcon: IconButton(
            onPressed: onSubmitted,
            icon: const Icon(Icons.arrow_forward, color: AppColors.accentDeep),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 17),
        ),
      ),
    );
  }
}

class _SearchSuggestions extends StatelessWidget {
  const _SearchSuggestions({
    required this.isSearching,
    required this.suggestions,
    required this.onSelect,
  });

  final bool isSearching;
  final List<HometownLocation> suggestions;
  final ValueChanged<HometownLocation> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 5)),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 340),
      child: isSearching
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                ),
              ),
            )
          : suggestions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
                  child: Text('검색 결과가 없어요', style: AppTypography.subhead),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: suggestions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.hairline),
                  itemBuilder: (context, index) {
                    final location = suggestions[index];
                    return InkWell(
                      onTap: () => onSelect(location),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 18, color: AppColors.inkTertiary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    location.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.headline,
                                  ),
                                  Text(
                                    location.region,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.footnote,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _SelectedPlace extends StatelessWidget {
  const _SelectedPlace({required this.location});

  final HometownLocation location;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => context.push('/compare/${location.id}'),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.accentDeep),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${location.region} ${location.name}',
                  style: AppTypography.headline,
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.inkTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 7)),
        ],
      ),
      child: child,
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.icon, required this.title, this.trailing});
  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accentDeep, size: 22),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: AppTypography.headline)),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

class _NewsPanel extends ConsumerWidget {
  const _NewsPanel({required this.locationId});

  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(newsByLocationProvider(locationId));

    return _Panel(
      child: Column(
        children: [
          _PanelHeader(
            icon: Icons.newspaper_outlined,
            title: '그 시절 뉴스',
            trailing: TextButton(
              onPressed: () => context.push('/archive/$locationId'),
              child: const Text('더보기'),
            ),
          ),
          const SizedBox(height: 8),
          newsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('아직 모아둔 뉴스가 없어요', style: AppTypography.subhead),
                );
              }
              final top = items.take(3).toList();
              return Column(
                children: [
                  for (var i = 0; i < top.length; i++)
                    _NewsRow(item: top[i], last: i == top.length - 1),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
            ),
            error: (_, _) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('뉴스를 불러오지 못했어요', style: AppTypography.subhead),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsRow extends StatelessWidget {
  const _NewsRow({required this.item, this.last = false});

  final NewsItem item;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                const SizedBox(height: 5),
                const CircleAvatar(radius: 4, backgroundColor: AppColors.accent),
                if (!last) Expanded(child: Container(width: 1, color: AppColors.hairline)),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${item.year}', style: AppTypography.caption.copyWith(color: AppColors.accentDeep)),
                  const SizedBox(height: 3),
                  Text(item.title, style: AppTypography.subhead.copyWith(color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(item.source, style: AppTypography.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoursePanel extends ConsumerWidget {
  const _CoursePanel({required this.locationId});

  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(coursesByLocationProvider(locationId));

    return _Panel(
      child: coursesAsync.when(
        data: (courses) {
          if (courses.isEmpty) {
            return Column(
              children: const [
                _PanelHeader(icon: Icons.map_outlined, title: '현재 추천 코스'),
                SizedBox(height: 16),
                Text('이 지역엔 아직 추천 코스가 없어요', style: AppTypography.subhead),
              ],
            );
          }
          final course = courses.first;
          return Column(
            children: [
              _PanelHeader(
                icon: Icons.map_outlined,
                title: '현재 추천 코스',
                trailing: Row(
                  children: [
                    const Icon(Icons.schedule, size: 15, color: AppColors.inkSecondary),
                    const SizedBox(width: 4),
                    Text(course.durationLabel, style: AppTypography.caption),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(course.title, style: AppTypography.headline),
              const SizedBox(height: 4),
              Text(course.description, style: AppTypography.subhead),
              const SizedBox(height: 12),
              for (var i = 0; i < course.stops.length; i++)
                _CourseStop(number: i + 1, title: course.stops[i].name),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/course/${course.id}'),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('코스 보기'),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (_, _) => const Text('코스를 불러오지 못했어요', style: AppTypography.subhead),
      ),
    );
  }
}

class _CourseStop extends StatelessWidget {
  const _CourseStop({required this.number, required this.title});
  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.accent,
            child: Text('$number', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: AppTypography.subhead.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
