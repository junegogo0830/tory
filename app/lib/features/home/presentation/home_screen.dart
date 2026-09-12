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
import '../../archive/data/archive_providers.dart';
import '../data/home_providers.dart';
import 'widgets/community_preview_section.dart';
import 'widgets/highlight_carousel.dart';
import 'widgets/nearby_attractions_tile.dart';
import 'widgets/restaurant_categories_carousel.dart';
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

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
    // 지역 뉴스 섹션이 계속 첫 번째 장소만 보이지 않도록, 홈에 있는 동안 3초마다
    // 자동으로 다음 장소로 넘어간다. 검색 중일 땐 건드리지 않는다(자동완성 위로
    // 화면이 바뀌면 산만하다).
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
      children: [
        WeatherTopBanner(controller: controller, onSubmitted: onSubmit),
        if (showSuggestions) ...[
          const SizedBox(height: 8),
          _SearchSuggestions(
            isSearching: isSearching,
            suggestions: suggestions,
            onSelect: onSelectSuggestion,
          ),
        ],
        const SizedBox(height: 18),
        const HighlightCarousel(),
        const SizedBox(height: 22),
        const NearbyAttractionsTile(),
        const SizedBox(height: 12),
        const CommunityPreviewSection(),
        const SizedBox(height: 22),
        const RestaurantCategoriesCarousel(),
        const SizedBox(height: 22),
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
