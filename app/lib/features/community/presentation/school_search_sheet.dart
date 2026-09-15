import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/school_search_result.dart';
import '../../../data/repositories/repository_providers.dart';

/// 커뮤니티 region 문자열 안에서 "이건 학교 스코프다"를 표시하는 접두어.
/// 별도 DB 컬럼 없이 기존 region 필드를 그대로 재사용하기 위한 관례다
/// (백엔드 community_posts.region은 자유 문자열이라 스키마 변경이 필요 없다).
const String schoolRegionPrefix = '학교·';

String schoolRegionFor(String schoolName) => '$schoolRegionPrefix$schoolName';

bool isSchoolRegion(String region) => region.startsWith(schoolRegionPrefix);

String schoolNameFrom(String region) => region.substring(schoolRegionPrefix.length);

/// 모교 이름을 검색해서 고르는 바텀시트. 고르면 [schoolRegionFor]로 감싼
/// "region" 문자열을 반환한다(취소하면 null).
Future<String?> showSchoolSearchSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (context) => const _SchoolSearchContent(),
  );
}

class _SchoolSearchContent extends ConsumerStatefulWidget {
  const _SchoolSearchContent();

  @override
  ConsumerState<_SchoolSearchContent> createState() => _SchoolSearchContentState();
}

class _SchoolSearchContentState extends ConsumerState<_SchoolSearchContent> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<SchoolSearchResult> _results = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
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
      final results = await ref.read(communityRepositoryProvider).searchSchools(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('모교를 검색해주세요', style: AppTypography.headline),
          const SizedBox(height: 6),
          Text('예: 옛길고등학교, 옛길초등학교', style: AppTypography.footnote),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            decoration: const InputDecoration(
              hintText: '학교 이름',
              prefixIcon: Icon(Icons.school_outlined),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 280,
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          _controller.text.trim().isEmpty ? '학교 이름을 입력해주세요' : '검색 결과가 없어요',
                          style: AppTypography.subhead.copyWith(color: AppColors.inkTertiary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.hairline),
                        itemBuilder: (context, index) {
                          final school = _results[index];
                          return ListTile(
                            leading: const Icon(Icons.school_outlined, color: AppColors.accentDeep),
                            title: Text(school.name, style: AppTypography.body),
                            subtitle: Text(school.address, style: AppTypography.caption),
                            onTap: () => Navigator.of(context).pop(schoolRegionFor(school.name)),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
