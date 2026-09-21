import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/tour_course.dart';
import '../../data/repositories/repository_providers.dart';
import '../../features/auth/data/auth_providers.dart';

/// 코스 저장(북마크) 토글 버튼 — AI 생성 코스/커스텀 코스 상세 화면이 공유한다.
/// AppBar actions에 놓기 좋게 아이콘 버튼 하나로만 구성했다.
class SaveCourseButton extends ConsumerStatefulWidget {
  const SaveCourseButton({super.key, required this.courseType, required this.courseId, this.course});

  final String courseType; // 'generated' | 'custom'
  final String courseId;

  /// generated 코스에서, 화면이 지금 들고 있는 코스(식사 추가처럼 서버 캐시엔
  /// 없는 변경 포함)를 그대로 저장하고 싶을 때 넘긴다 — 안 넘기면 백엔드가
  /// courseId로 다시 조회한 원본을 저장한다.
  final TourCourse? course;

  @override
  ConsumerState<SaveCourseButton> createState() => _SaveCourseButtonState();
}

class _SaveCourseButtonState extends ConsumerState<SaveCourseButton> {
  bool? _saved;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (ref.read(authStateProvider).value != true) return;
    try {
      final saved = await ref
          .read(savedCourseRepositoryProvider)
          .status(courseType: widget.courseType, courseId: widget.courseId);
      if (mounted) setState(() => _saved = saved);
    } catch (_) {
      // 조용히 포기 — 버튼은 "저장 안 함" 상태로 남는다.
    }
  }

  Future<void> _toggle() async {
    if (ref.read(authStateProvider).value != true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그인하면 코스를 저장할 수 있어요')));
      return;
    }
    final wasSaved = _saved ?? false;
    setState(() => _busy = true);
    try {
      final repo = ref.read(savedCourseRepositoryProvider);
      if (wasSaved) {
        await repo.unsave(courseType: widget.courseType, courseId: widget.courseId);
      } else {
        await repo.save(courseType: widget.courseType, courseId: widget.courseId, course: widget.course);
      }
      if (mounted) {
        setState(() => _saved = !wasSaved);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(wasSaved ? '저장을 취소했어요' : '코스를 저장했어요')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('처리하지 못했어요. 다시 시도해주세요.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = _saved ?? false;
    return IconButton(
      onPressed: _busy ? null : _toggle,
      icon: Icon(
        saved ? Icons.bookmark : Icons.bookmark_border,
        color: saved ? AppColors.accent : AppColors.ink,
      ),
      tooltip: saved ? '저장 취소' : '코스 저장',
    );
  }
}
