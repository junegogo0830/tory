import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/custom_course.dart';
import '../../../data/models/memory_attribute.dart';
import '../../../data/models/memory_profile.dart';
import '../../../data/repositories/repository_providers.dart';
import 'add_memory_attribute_sheet.dart';

const _typeIcon = {
  'school': Icons.school_outlined,
  'region': Icons.home_outlined,
  'place': Icons.place_outlined,
};

/// "추억 프로필" — 개인정보 대신 살았던 지역/학교/활동 시기, 작성한 추억,
/// 등록한 코스를 보여준다. 타인 프로필이면 연결 상태에 따라 요청/메시지 버튼이 갈린다.
class MemoryProfileScreen extends ConsumerStatefulWidget {
  const MemoryProfileScreen({super.key, required this.userId});

  final int userId;

  @override
  ConsumerState<MemoryProfileScreen> createState() => _MemoryProfileScreenState();
}

class _MemoryProfileScreenState extends ConsumerState<MemoryProfileScreen> {
  MemoryProfile? _profile;
  bool _loadFailed = false;
  bool _busy = false;
  List<CustomCourseSummary>? _friendCourses;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await ref.read(memoryRepositoryProvider).profile(widget.userId);
      if (mounted) setState(() => _profile = profile);
      if (profile.connectionStatus == 'accepted') {
        // 연결된 사이일 때만 상대방의 공개 코스를 보여준다 — 실패해도 프로필
        // 자체는 보여야 하니 조용히 빈 목록으로 둔다.
        try {
          final courses = await ref.read(customCourseRepositoryProvider).listByAuthor(widget.userId);
          if (mounted) setState(() => _friendCourses = courses);
        } catch (_) {
          if (mounted) setState(() => _friendCourses = []);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _addAttribute() async {
    final draft = await showAddMemoryAttributeSheet(context);
    if (draft == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(memoryRepositoryProvider).addAttribute(
        type: draft.type,
        label: draft.label,
        placeId: draft.placeId,
        startYear: draft.startYear,
        endYear: draft.endYear,
      );
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendConnectionRequest() async {
    final profile = _profile;
    if (profile == null) return;
    final suggested = profile.attributes.isNotEmpty
        ? '혹시 ${profile.attributes.first.label} ${profile.attributes.first.periodLabel}이신가요?'
        : '안녕하세요! 같은 추억이 있는 것 같아 연결 요청 드려요.';
    final controller = TextEditingController(text: suggested);
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('연결 요청 보내기'),
        content: TextField(controller: controller, maxLines: 3, maxLength: 300),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('보내기'),
          ),
        ],
      ),
    );
    if (message == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(connectionRepositoryProvider).sendRequest(
        recipientId: widget.userId,
        message: message.isEmpty ? null : message,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('연결 요청을 보냈어요')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('요청을 보내지 못했어요. 다시 시도해주세요.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('추억 프로필')),
      body: SafeArea(
        child: profile == null
            ? Center(
                child: _loadFailed
                    ? Text('프로필을 불러오지 못했어요', style: AppTypography.subhead)
                    : const CircularProgressIndicator(color: AppColors.accent),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.accentTint,
                        backgroundImage: profile.profileImageUrl != null
                            ? NetworkImage(profile.profileImageUrl!)
                            : null,
                        child: profile.profileImageUrl == null
                            ? const Icon(Icons.person, size: 28, color: AppColors.accentDeep)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(profile.nickname, style: AppTypography.title),
                            const SizedBox(height: 2),
                            Text(
                              '추억 ${profile.memoryPostCount}개 · 만든 코스 ${profile.courseCount}개',
                              style: AppTypography.footnote,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('추억 조건', style: AppTypography.headline),
                      if (profile.isMine)
                        TextButton.icon(
                          onPressed: _busy ? null : _addAttribute,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('추가'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (profile.attributes.isEmpty)
                    Text('아직 등록한 추억 조건이 없어요', style: AppTypography.footnote.copyWith(color: AppColors.inkTertiary))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [for (final attribute in profile.attributes) _AttributeChip(attribute: attribute)],
                    ),
                  const SizedBox(height: 24),
                  if (!profile.isMine) _ConnectionSection(profile: profile, busy: _busy, onConnect: _sendConnectionRequest),
                  if (profile.connectionStatus == 'accepted' && _friendCourses != null && _friendCourses!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('${profile.nickname}님이 만든 코스', style: AppTypography.headline),
                    const SizedBox(height: 8),
                    for (final course in _friendCourses!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.route_outlined, color: AppColors.accentDeep),
                          title: Text(course.title, style: AppTypography.body),
                          subtitle: Text('${course.category} · 장소 ${course.placeCount}곳', style: AppTypography.caption),
                          onTap: () => context.push('/custom-courses/${course.id}'),
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _AttributeChip extends StatelessWidget {
  const _AttributeChip({required this.attribute});

  final MemoryAttribute attribute;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.fieldBg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_typeIcon[attribute.type] ?? Icons.star_outline, size: 15, color: AppColors.accentDeep),
          const SizedBox(width: 6),
          Text(
            [attribute.label, if (attribute.periodLabel.isNotEmpty) attribute.periodLabel].join(' '),
            style: AppTypography.footnote.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ConnectionSection extends StatelessWidget {
  const _ConnectionSection({required this.profile, required this.busy, required this.onConnect});

  final MemoryProfile profile;
  final bool busy;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    switch (profile.connectionStatus) {
      case 'accepted':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.push('/friends/chat/${profile.connectionId}'),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('메시지 보내기'),
          ),
        );
      case 'pending_sent':
        return const _StatusBanner(icon: Icons.hourglass_empty, text: '연결 요청을 보냈어요 · 상대의 수락을 기다리는 중');
      case 'pending_received':
        return _StatusBanner(
          icon: Icons.mark_email_unread_outlined,
          text: '나에게 연결 요청을 보냈어요',
          action: TextButton(onPressed: () => context.push('/friends/requests'), child: const Text('확인하기')),
        );
      default:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: busy ? null : onConnect,
            icon: const Icon(Icons.person_add_alt, size: 18),
            label: const Text('연결 요청'),
          ),
        );
    }
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.fieldBg, borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.inkSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTypography.footnote)),
          ?action,
        ],
      ),
    );
  }
}
