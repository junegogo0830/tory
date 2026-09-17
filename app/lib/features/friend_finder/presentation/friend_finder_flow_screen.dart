import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/memory_match.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import 'add_memory_attribute_sheet.dart';
import '../../profile/data/profile_providers.dart';

/// "친구 찾기" — 지역 대신 추억 조건(학교/동네/자주 간 장소 + 시기)을 골라
/// 같은 추억을 가진 사람을 점수순으로 추천한다. 조건을 계속 추가/삭제하면서
/// 같은 화면에서 다시 찾을 수 있다.
class FriendFinderFlowScreen extends ConsumerStatefulWidget {
  const FriendFinderFlowScreen({super.key});

  @override
  ConsumerState<FriendFinderFlowScreen> createState() => _FriendFinderFlowScreenState();
}

class _FriendFinderFlowScreenState extends ConsumerState<FriendFinderFlowScreen> {
  final List<DraftMemoryAttribute> _conditions = [];
  List<MemoryMatch>? _results;
  bool _searching = false;
  bool _visibilityBusy = false;

  Future<void> _setVisible(bool value) async {
    setState(() => _visibilityBusy = true);
    try {
      await ref.read(profileRepositoryProvider).updateInfo(friendFinderEnabled: value);
      ref.invalidate(profileProvider);
    } finally {
      if (mounted) setState(() => _visibilityBusy = false);
    }
  }

  Future<void> _addCondition() async {
    final draft = await showAddMemoryAttributeSheet(context);
    if (draft == null || !mounted) return;
    setState(() {
      _conditions.add(draft);
      _results = null; // 조건이 바뀌면 이전 검색 결과는 지운다.
    });
  }

  void _removeCondition(int index) {
    setState(() {
      _conditions.removeAt(index);
      _results = null;
    });
  }

  Future<void> _search() async {
    if (_conditions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('추억 조건을 하나 이상 추가해주세요')));
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await ref
          .read(memoryRepositoryProvider)
          .search([for (final c in _conditions) c.toSearchFilterJson()]);
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('검색에 실패했어요. 다시 시도해주세요.')));
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final isVisible = profile.value?.friendFinderEnabled ?? true;
    final results = _results;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('친구 찾기')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Material(
              color: AppColors.fieldBg,
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: SwitchListTile(
                title: const Text('다른 유저에게 정보를 보여줄까요?'),
                subtitle: const Text('끄면 다른 사람의 검색 결과에 내가 나오지 않아요. 나는 계속 찾아볼 수 있어요.'),
                value: isVisible,
                onChanged: _visibilityBusy ? null : _setVisible,
              ),
            ),
            const SizedBox(height: 18),
            Text('같은 추억을 가진 사람 찾기', style: AppTypography.title),
            const SizedBox(height: 6),
            Text(
              '다녔던 학교, 살았던 동네, 자주 갔던 장소와 시기를 조건으로 추가하면\n겹치는 게 많은 사람일수록 위로 추천해드려요.',
              style: AppTypography.subhead,
            ),
            const SizedBox(height: 18),
            if (_conditions.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.fieldBg,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Text(
                  '예: 옛길고등학교(2008~2010), 고잔동(2005~2012), 중앙분식',
                  style: AppTypography.footnote.copyWith(color: AppColors.inkTertiary),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _conditions.length; i++)
                    Chip(
                      label: Text(_conditions[i].displayLabel),
                      onDeleted: () => _removeCondition(i),
                      backgroundColor: AppColors.accentTint,
                      side: BorderSide.none,
                    ),
                ],
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addCondition,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('추억 조건 추가'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _searching ? null : _search,
                child: _searching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('이런 추억을 가진 사람 찾기'),
              ),
            ),
            if (results != null) ...[
              const SizedBox(height: 28),
              Divider(color: AppColors.hairline),
              const SizedBox(height: 16),
              Text('추억이 겹치는 사람 ${results.length}명', style: AppTypography.sectionTitle),
              const SizedBox(height: 10),
              if (results.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: EmptyState(
                    icon: Icons.person_search_outlined,
                    title: '아직 겹치는 추억을 가진 사람이 없어요',
                    message: '다른 조건으로 다시 찾아보거나, 나중에 다시 확인해보세요.',
                  ),
                )
              else
                for (final match in results) ...[
                  _MatchCard(match: match),
                  const SizedBox(height: 10),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});

  final MemoryMatch match;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/memory-profile/${match.userId}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.accentTint,
            backgroundImage: match.profileImageUrl != null ? NetworkImage(match.profileImageUrl!) : null,
            child: match.profileImageUrl == null
                ? const Icon(Icons.person, size: 22, color: AppColors.accentDeep)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        match.nickname,
                        style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.pastelMint,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '공통점 ${match.reasons.length}개',
                        style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final reason in match.reasons)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.fieldBg,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(reason, style: AppTypography.caption),
                      ),
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
