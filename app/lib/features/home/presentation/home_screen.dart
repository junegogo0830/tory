import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/hometown_location.dart';
import '../../../data/models/news_item.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../archive/data/archive_providers.dart';
import '../../chatbot/presentation/chatbot_fab.dart';
import '../data/home_providers.dart';
import 'widgets/community_preview_section.dart';
import 'widgets/hero_highlight_banner.dart';
import 'widgets/kakao_restaurant_card.dart';
import 'widgets/notice_banner.dart';
import 'widgets/quick_action_grid.dart';
import 'widgets/restaurant_categories_carousel.dart';
import 'widgets/todays_memory_card.dart';
import 'widgets/weather_top_banner.dart';

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
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
    // 지역 뉴스 섹션이 계속 첫 번째 장소만 보이지 않도록, 홈에 있는 동안 3초마다
    // 자동으로 다음 장소로 넘어간다. 검색 중일 땐 건드리지 않는다(자동완성 위로
    // 화면이 바뀌면 산만하다).
    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !TickerMode.valuesOf(context).enabled || !(ModalRoute.of(context)?.isCurrent ?? true) || _queryController.text.trim().isNotEmpty) return;
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
      final repository = ref.read(locationRepositoryProvider);
      // 카테고리 필터가 있으면 등록 관광지 중 그 카테고리만(음식점/문화시설 등),
      // 없으면 기존처럼 주소·학교·아파트까지 포함하는 통합 검색을 쓴다.
      final results = _categoryFilter != null
          ? await repository.searchTourLocations(query, contentTypeId: _categoryFilter)
          : await repository.searchLocations(query);
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

  void _onCategoryFilterChanged(String? category) {
    setState(() => _categoryFilter = category);
    final query = _queryController.text.trim();
    if (query.isNotEmpty) {
      setState(() => _isSearching = true);
      _search(query);
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
      if (mounted) _selectSuggestion(location);
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
        child: Stack(
          children: [
            Center(
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
                    categoryFilter: _categoryFilter,
                    onCategoryFilterChanged: _onCategoryFilterChanged,
                  ),
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  error: (_, _) => Center(
                    child: Text('홈 정보를 불러오지 못했어요', style: AppTypography.subhead),
                  ),
                ),
              ),
            ),
            const ChatbotFab(),
          ],
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
    required this.categoryFilter,
    required this.onCategoryFilterChanged,
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
  final String? categoryFilter;
  final ValueChanged<String?> onCategoryFilterChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
      children: [
        WeatherTopBanner(
          controller: controller,
          onSubmitted: onSubmit,
          categoryFilter: categoryFilter,
          onCategoryFilterChanged: onCategoryFilterChanged,
        ),
        if (showSuggestions) ...[
          const SizedBox(height: 8),
          _SearchSuggestions(
            isSearching: isSearching,
            suggestions: suggestions,
            onSelect: onSelectSuggestion,
          ),
        ],
        // 섹션 간격은 정보 관계에 따라 다르게 — 배너→하이라이트→바로가기는 한
        // 덩어리처럼 붙이고, 그 뒤 큰 섹션 사이는 28로 넉넉히 띄운다.
        const SizedBox(height: 16),
        const HeroHighlightBanner(key: ValueKey('home-highlights')),
        const SizedBox(height: 20),
        const QuickActionGrid(),
        const SizedBox(height: 24),
        const NoticeBanner(),
        const SizedBox(height: 24),
        const TodaysMemoryCard(),
        const SizedBox(height: 30),
        const RestaurantCategoriesCarousel(key: ValueKey('home-restaurants')),
        const SizedBox(height: 30),
        const CommunityPreviewSection(),
        const SizedBox(height: 30),
        const KakaoRestaurantCard(),
        const SizedBox(height: 30),
        if (primary != null) ...[
          _NewsPanel(locationId: primary!.id),
          if (locationCount > 1) ...[
            const SizedBox(height: 12),
            _CarouselDots(count: locationCount, activeIndex: activeIndex),
          ],
        ] else
          const EmptyState(
            icon: Icons.location_on_outlined,
            title: '아직 둘러본 골목이 없어요',
            message: '고향 주소를 검색하면 그때 그 골목을 보여드릴게요.',
          ),
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
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.card,
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
                  separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.hairline),
                  itemBuilder: (context, index) {
                    final location = suggestions[index];
                    return InkWell(
                      onTap: () => onSelect(location),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 18, color: AppColors.inkTertiary),
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

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
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
        Icon(icon, color: AppColors.accentDeep, size: 20),
        const SizedBox(width: 7),
        Expanded(child: Text(title, style: AppTypography.headline.copyWith(fontWeight: FontWeight.w700))),
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
            title: '지역 뉴스',
            trailing: TextButton(
              onPressed: () => context.push('/archive/$locationId'),
              child: const Text('더보기'),
            ),
          ),
          const SizedBox(height: 8),
          newsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
            error: (_, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
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
                  Text(
                    '${item.year}',
                    style: AppTypography.caption.copyWith(color: AppColors.accentDeep, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.title,
                    style: AppTypography.subhead.copyWith(color: AppColors.ink, fontWeight: FontWeight.w500, height: 1.4),
                  ),
                  const SizedBox(height: 3),
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
