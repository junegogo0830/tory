import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/hometown_location.dart';
import '../../../data/models/news_item.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/archive_providers.dart';

class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key, required this.locationId});

  final String locationId;

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  late String _locationId = widget.locationId;
  String? _displayRegionLabel;

  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  List<HometownLocation> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query.trim()));
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    try {
      final results = await ref.read(locationRepositoryProvider).searchLocations(query);
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectLocation(HometownLocation location) {
    setState(() {
      _locationId = location.id;
      _displayRegionLabel = '${location.name} · ${location.region}';
      _results = [];
      _searchController.clear();
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final newsAsync = ref.watch(newsByLocationProvider(_locationId));

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('그 시절 · 최근 소식')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _RegionSearchField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              currentLabel: _displayRegionLabel,
            ),
            if (_isSearching || _results.isNotEmpty) ...[
              const SizedBox(height: 8),
              _RegionSearchResults(
                results: _results,
                isSearching: _isSearching,
                onSelect: _selectLocation,
              ),
            ],
            const SizedBox(height: 20),
            const _SectionHeader(
              icon: Icons.auto_stories_outlined,
              title: '그 시절 이야기',
              subtitle: 'AI가 웹에서 찾아 정리한 이 동네의 옛 기록이에요',
            ),
            const SizedBox(height: 12),
            _RegionStoryCard(locationId: _locationId),
            const SizedBox(height: 28),
            const _SectionHeader(
              icon: Icons.newspaper_outlined,
              title: '최근 이 동네 소식',
              subtitle: '이 지역과 관련된 최근 뉴스예요',
            ),
            const SizedBox(height: 12),
            newsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.newspaper_outlined,
                    title: '아직 모아둔 소식이 없어요',
                    message: '이 지역은 데이터가 적어요. 곧 더 많은 이야기를 채워갈게요.',
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      _NewsTimelineCard(item: items[i]),
                    ],
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              ),
              error: (_, _) => Text('소식을 불러오는 중 문제가 발생했어요', style: AppTypography.subhead),
            ),
          ],
        ),
      ),
    );
  }
}

/// 다른 동네 소식이 궁금할 때 바로 검색해서 이 화면 안에서 전환할 수 있는 입력창.
class _RegionSearchField extends StatelessWidget {
  const _RegionSearchField({required this.controller, required this.onChanged, this.currentLabel});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? currentLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: '다른 동네를 검색해보세요 (예: 순천 저전동)',
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: AppColors.fieldBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.field),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (currentLabel != null) ...[
          const SizedBox(height: 6),
          Text('지금 보는 동네: $currentLabel', style: AppTypography.caption),
        ],
      ],
    );
  }
}

class _RegionSearchResults extends StatelessWidget {
  const _RegionSearchResults({required this.results, required this.isSearching, required this.onSelect});

  final List<HometownLocation> results;
  final bool isSearching;
  final ValueChanged<HometownLocation> onSelect;

  @override
  Widget build(BuildContext context) {
    if (isSearching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
          ),
        ),
      );
    }
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('검색 결과가 없어요', style: AppTypography.footnote),
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < results.length; i++) ...[
            ListTile(
              dense: true,
              title: Text(results[i].name, style: AppTypography.body),
              subtitle: Text(results[i].region, style: AppTypography.caption),
              onTap: () => onSelect(results[i]),
            ),
            if (i != results.length - 1) Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.hairline),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.accentDeep, size: 20),
            const SizedBox(width: 8),
            Text(title, style: AppTypography.title),
          ],
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: AppTypography.footnote.copyWith(color: AppColors.inkSecondary)),
      ],
    );
  }
}

/// Claude가 웹 검색으로 찾아 종합한 "그 시절" 이야기. 뉴스 검색 API가 못 채우는
/// 1990~2000년대 지역 기록을, 첫 방문에서만 (몇 초 걸려) 만들고 그 뒤로는 백엔드가
/// 사실상 영구 캐싱한다 — 못 찾으면 조용히 아무것도 안 보여준다.
class _RegionStoryCard extends ConsumerWidget {
  const _RegionStoryCard({required this.locationId});

  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storyAsync = ref.watch(regionStoryProvider(locationId));

    return storyAsync.when(
      data: (story) {
        if (story == null) {
          return Text(
            '아직 이 동네의 옛 기록을 찾지 못했어요',
            style: AppTypography.subhead.copyWith(color: AppColors.inkSecondary),
          );
        }
        return AppCard(
          child: Text(story, style: AppTypography.subhead.copyWith(height: 1.6)),
        );
      },
      loading: () => AppCard(
        child: Row(
          children: [
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
            ),
            const SizedBox(width: 10),
            Text('AI가 그 시절 기록을 찾아보고 있어요…', style: AppTypography.subhead),
          ],
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _NewsTimelineCard extends StatelessWidget {
  const _NewsTimelineCard({required this.item});

  final NewsItem item;

  String get _dateLabel {
    final date = item.publishedAt;
    if (date == null) return '${item.year}년';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _openArticle() async {
    final url = item.url;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final hasLink = item.url != null;

    return AppCard(
      onTap: hasLink ? _openArticle : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentTint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _dateLabel,
              style: AppTypography.caption.copyWith(
                color: AppColors.accentDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: AppTypography.headline),
                const SizedBox(height: 4),
                Text(item.summary, style: AppTypography.subhead),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(item.source, style: AppTypography.caption),
                    if (hasLink) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.open_in_new, size: 12, color: AppColors.inkTertiary),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
