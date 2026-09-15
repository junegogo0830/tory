import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/hometown_location.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/region_select_sheet.dart';
import '../../profile/data/profile_providers.dart';

const _ageGroups = ['10대', '20대', '30대', '40대', '50대', '60대 이상'];

/// 첫 로그인 온보딩 — 연령대/거주지/살았던 곳을 한 화면에서 받는다. 셋 다
/// 선택 입력이고, 언제든 "건너뛰기"로 바로 닫을 수 있다. AppShell이 로그인
/// 직후 profile.onboardingCompleted == false일 때 전체화면으로 띄운다.
///
/// 반환값: 이 화면을 지나며 거주지/살았던 곳 중 하나라도 채웠으면 true —
/// 호출부(AppShell)가 "첫 이야기를 남겨볼까요?" 넛지를 보여줄지 판단하는 데 쓴다.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  String? _ageGroup;
  String? _region;
  HometownLocation? _hometown;

  bool _isSearching = false;
  List<HometownLocation> _results = [];
  bool _submitting = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickRegion() async {
    final selected = await showRegionSelectSheet(context, prompt: '어디에 사시나요?');
    if (selected != null && mounted) setState(() => _region = selected);
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
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectHometown(HometownLocation location) {
    setState(() {
      _hometown = location;
      _results = [];
      _searchController.clear();
    });
  }

  Future<void> _finish() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      // 셋 다 독립적인 엔드포인트라 병렬로 보낸다 — 하나 실패해도 나머지는 반영되게
      // 개별 에러는 조용히 무시한다(온보딩은 선택 입력이라 실패해도 막을 이유가 없다).
      final region = _region;
      final hometown = _hometown;
      await Future.wait<void>([
        () async {
          try {
            await ref.read(profileRepositoryProvider).completeOnboarding(ageGroup: _ageGroup);
          } catch (_) {}
        }(),
        if (region != null)
          () async {
            try {
              await ref.read(communityRepositoryProvider).setHomeRegion(region);
            } catch (_) {}
          }(),
        if (hometown != null)
          () async {
            try {
              await ref.read(profileRepositoryProvider).saveLocation(hometown.id);
            } catch (_) {}
          }(),
      ]);
    } finally {
      if (mounted) {
        ref.invalidate(profileProvider);
        Navigator.of(context).pop(_region != null || _hometown != null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
                    children: [
                      Text('옛길에 오신 걸 환영해요', style: AppTypography.title.copyWith(fontSize: 24)),
                      const SizedBox(height: 8),
                      Text(
                        '몇 가지만 알려주시면 더 잘 맞는 추억을 보여드릴게요.\n지금 안 채우셔도 나중에 언제든 바꿀 수 있어요.',
                        style: AppTypography.subhead.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 32),
                      Text('연령대', style: AppTypography.headline),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final group in _ageGroups)
                            ChoiceChip(
                              label: Text(group),
                              selected: _ageGroup == group,
                              onSelected: (selected) => setState(() => _ageGroup = selected ? group : null),
                              showCheckmark: false,
                              selectedColor: AppColors.accent,
                              backgroundColor: AppColors.surface,
                              side: BorderSide(color: _ageGroup == group ? AppColors.accent : AppColors.hairline),
                              shape: const StadiumBorder(),
                              labelStyle: AppTypography.footnote.copyWith(
                                color: _ageGroup == group ? Colors.white : AppColors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text('지금 사는 곳', style: AppTypography.headline),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: _pickRegion,
                        borderRadius: BorderRadius.circular(AppRadius.field),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.field),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.location_city_outlined, size: 19, color: AppColors.accentDeep),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _region ?? '지역 선택하기',
                                  style: AppTypography.body.copyWith(
                                    color: _region == null ? AppColors.inkTertiary : AppColors.ink,
                                  ),
                                ),
                              ),
                              Icon(Icons.chevron_right, size: 20, color: AppColors.inkTertiary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text('예전에 살았던 곳', style: AppTypography.headline),
                      const SizedBox(height: 4),
                      Text('그 시절 추억이 있는 동네를 검색해보세요', style: AppTypography.footnote),
                      const SizedBox(height: 10),
                      if (_hometown != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.accentTint,
                            borderRadius: BorderRadius.circular(AppRadius.field),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, size: 18, color: AppColors.accentDeep),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_hometown!.name, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                                    Text(_hometown!.region, style: AppTypography.caption.copyWith(color: AppColors.inkSecondary)),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => setState(() => _hometown = null),
                                child: Icon(Icons.close, size: 18, color: AppColors.inkTertiary),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: const InputDecoration(
                            hintText: '예: 전주 한옥마을, 순천 정원',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                        if (_isSearching)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                              ),
                            ),
                          )
                        else if (_results.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.field),
                              border: Border.all(color: AppColors.hairline),
                            ),
                            child: Column(
                              children: [
                                for (var i = 0; i < _results.length; i++) ...[
                                  ListTile(
                                    dense: true,
                                    leading: Icon(Icons.location_on_outlined, size: 18, color: AppColors.inkTertiary),
                                    title: Text(_results[i].name, style: AppTypography.body),
                                    subtitle: Text(_results[i].region, style: AppTypography.caption),
                                    onTap: () => _selectHometown(_results[i]),
                                  ),
                                  if (i != _results.length - 1) Divider(height: 1, color: AppColors.hairline),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _finish,
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('확인'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _submitting ? null : _finish,
                        child: Text(
                          '지금 입력하고 싶지 않으신가요? 건너뛰기',
                          style: AppTypography.footnote.copyWith(color: AppColors.inkSecondary),
                        ),
                      ),
                    ],
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
