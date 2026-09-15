import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/memory_attribute.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/empty_state.dart';
import 'add_memory_attribute_sheet.dart';

const _typeLabel = {'school': '학교', 'region': '동네', 'place': '장소'};
const _typeIcon = {
  'school': Icons.school_outlined,
  'region': Icons.home_outlined,
  'place': Icons.place_outlined,
};

/// 프로필 탭 "나의 추억 조건 관리" — 내 학교/동네/장소 추억 속성을 추가/삭제한다.
/// 여기서 채운 속성이 다른 사람의 친구 찾기 검색·코스의 "추억이 겹치는 사람"
/// 매칭에 그대로 쓰인다.
class MyMemoryAttributesScreen extends ConsumerStatefulWidget {
  const MyMemoryAttributesScreen({super.key});

  @override
  ConsumerState<MyMemoryAttributesScreen> createState() => _MyMemoryAttributesScreenState();
}

class _MyMemoryAttributesScreenState extends ConsumerState<MyMemoryAttributesScreen> {
  List<MemoryAttribute>? _attributes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final attributes = await ref.read(memoryRepositoryProvider).myAttributes();
      if (mounted) setState(() => _attributes = attributes);
    } catch (_) {
      if (mounted) setState(() => _attributes = []);
    }
  }

  Future<void> _add() async {
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('추가하지 못했어요. 다시 시도해주세요.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(MemoryAttribute attribute) async {
    setState(() => _busy = true);
    try {
      await ref.read(memoryRepositoryProvider).deleteAttribute(attribute.id);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제하지 못했어요. 다시 시도해주세요.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attributes = _attributes;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('나의 추억 조건 관리')),
      body: SafeArea(
        child: attributes == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
            : attributes.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: EmptyState(
                        icon: Icons.auto_awesome_outlined,
                        title: '아직 등록한 추억 조건이 없어요',
                        message: '다녔던 학교, 살았던 동네, 자주 갔던 장소와 시기를 등록해두면\n같은 추억을 가진 사람을 더 잘 찾을 수 있어요.',
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: attributes.length,
                    itemBuilder: (context, index) {
                      final attribute = attributes[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.tile),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Row(
                          children: [
                            Icon(_typeIcon[attribute.type] ?? Icons.star_outline, color: AppColors.accentDeep, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(attribute.label, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    [_typeLabel[attribute.type] ?? attribute.type, if (attribute.periodLabel.isNotEmpty) attribute.periodLabel].join(' · '),
                                    style: AppTypography.caption.copyWith(color: AppColors.inkTertiary),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _busy ? null : () => _delete(attribute),
                              icon: Icon(Icons.close, size: 18, color: AppColors.inkTertiary),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _add,
        icon: const Icon(Icons.add),
        label: const Text('추억 조건 추가'),
      ),
    );
  }
}
