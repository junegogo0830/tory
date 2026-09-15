import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/repositories/repository_providers.dart';
import '../data/community_providers.dart';
import 'community_screen.dart' show shortRegionLabel;

/// 처음 가입하는 동네일 때만 보여주는 확인 화면 — 그냥 지역 문자열을 바로
/// 저장해버리면 "가입"이라는 느낌 없이 필터 바꾸듯 가벼워 보인다는 피드백으로,
/// 그 동네의 실제 규모(이웃 수·게시글 수)를 보여주고 확인을 한 번 받는다.
/// 이미 가입한 지역으로 "전환"할 때는 이 화면을 거치지 않는다(커뮤니티 탭의
/// 지역 토글 참고).
Future<bool> showRegionJoinConfirmSheet(BuildContext context, {required String region}) async {
  final joined = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (context) => _RegionJoinContent(region: region),
  );
  return joined ?? false;
}

class _RegionJoinContent extends ConsumerStatefulWidget {
  const _RegionJoinContent({required this.region});

  final String region;

  @override
  ConsumerState<_RegionJoinContent> createState() => _RegionJoinContentState();
}

class _RegionJoinContentState extends ConsumerState<_RegionJoinContent> {
  bool _joining = false;

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      await ref.read(communityRepositoryProvider).setHomeRegion(widget.region);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _joining = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('가입하지 못했어요. 다시 시도해주세요.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(regionStatsProvider(widget.region));

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 28, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: AppColors.accentTint, shape: BoxShape.circle),
            child: const Icon(Icons.location_city, color: AppColors.accentDeep, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            '${shortRegionLabel(widget.region)} 커뮤니티에\n가입할까요?',
            style: AppTypography.title.copyWith(fontSize: 21, height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(
            '가입하면 이 동네 게시판에 글을 쓰고 이웃을 만날 수 있어요.\n나중에 살았던 다른 동네를 더 추가할 수도 있어요.',
            style: AppTypography.subhead.copyWith(height: 1.5, color: AppColors.inkSecondary),
          ),
          const SizedBox(height: 18),
          statsAsync.when(
            data: (stats) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(AppRadius.field),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatColumn(label: '함께하는 이웃', value: '${stats.memberCount}명'),
                  ),
                  Container(width: 1, height: 32, color: AppColors.hairline),
                  Expanded(
                    child: _StatColumn(label: '올라온 이야기', value: '${stats.postCount}개'),
                  ),
                ],
              ),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _joining ? null : _join,
              child: _joining
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('가입하기'),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _joining ? null : () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTypography.headline.copyWith(fontWeight: FontWeight.w800, color: AppColors.accentDeep)),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.caption.copyWith(color: AppColors.inkSecondary)),
      ],
    );
  }
}
