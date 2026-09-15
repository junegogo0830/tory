import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/memory_attribute.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/region_select_sheet.dart';
import '../../friend_finder/presentation/add_memory_attribute_sheet.dart';
import '../data/profile_providers.dart';

const _ageGroups = ['10대', '20대', '30대', '40대', '50대', '60대 이상'];
const _genders = ['남성', '여성', '선택 안 함'];

/// 프로필 "정보 수정" — 나이/사는 곳/성별/이름/전화번호 + 모교/살았던 곳(추억 조건).
class ProfileInfoEditScreen extends ConsumerStatefulWidget {
  const ProfileInfoEditScreen({super.key});

  @override
  ConsumerState<ProfileInfoEditScreen> createState() => _ProfileInfoEditScreenState();
}

class _ProfileInfoEditScreenState extends ConsumerState<ProfileInfoEditScreen> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  List<MemoryAttribute>? _attributes;
  bool _initialized = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadAttributes();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadAttributes() async {
    try {
      final attributes = await ref.read(memoryRepositoryProvider).myAttributes();
      if (mounted) setState(() => _attributes = attributes);
    } catch (_) {
      if (mounted) setState(() => _attributes = []);
    }
  }

  Future<void> _pickAgeGroup(String group) async {
    try {
      await ref.read(profileRepositoryProvider).completeOnboarding(ageGroup: group);
      ref.invalidate(profileProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장하지 못했어요. 다시 시도해주세요.')));
      }
    }
  }

  Future<void> _pickRegion() async {
    final selected = await showRegionSelectSheet(context, prompt: '어디에 사시나요?');
    if (selected == null || !mounted) return;
    try {
      await ref.read(communityRepositoryProvider).setHomeRegion(selected);
      ref.invalidate(profileProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('지역을 바꾸지 못했어요. 다시 시도해주세요.')));
      }
    }
  }

  Future<void> _pickGender(String gender) async {
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).updateInfo(gender: gender);
      ref.invalidate(profileProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장하지 못했어요. 다시 시도해주세요.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveNameAndPhone() async {
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).updateInfo(
        fullName: _fullNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );
      ref.invalidate(profileProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장했어요')));
    } on Object catch (e) {
      final message = e.toString().contains('이미 다른 계정') ? '이미 다른 계정에서 쓰고 있는 번호예요' : '저장하지 못했어요. 다시 시도해주세요.';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addAttribute(String initialType) async {
    final draft = await showAddMemoryAttributeSheet(context, initialType: initialType);
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
      await _loadAttributes();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('추가하지 못했어요. 다시 시도해주세요.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAttribute(MemoryAttribute attribute) async {
    setState(() => _busy = true);
    try {
      await ref.read(memoryRepositoryProvider).deleteAttribute(attribute.id);
      await _loadAttributes();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    profileAsync.whenData((profile) {
      if (!_initialized) {
        _initialized = true;
        _fullNameController.text = profile.fullName ?? '';
        _phoneController.text = profile.phoneNumber ?? '';
      }
    });

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('정보 수정')),
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('나이', style: AppTypography.footnote),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final group in _ageGroups)
                    ChoiceChip(
                      label: Text(group),
                      selected: profile.ageGroup == group,
                      onSelected: (_) => _pickAgeGroup(group),
                      showCheckmark: false,
                      selectedColor: AppColors.accent,
                      backgroundColor: AppColors.surface,
                      side: BorderSide(color: profile.ageGroup == group ? AppColors.accent : AppColors.hairline),
                      shape: const StadiumBorder(),
                      labelStyle: AppTypography.footnote.copyWith(
                        color: profile.ageGroup == group ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Text('사는 곳', style: AppTypography.footnote),
              const SizedBox(height: 6),
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
                          profile.homeRegion ?? '지역 선택하기',
                          style: AppTypography.body.copyWith(
                            color: profile.homeRegion == null ? AppColors.inkTertiary : AppColors.ink,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 20, color: AppColors.inkTertiary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text('성별', style: AppTypography.footnote),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final gender in _genders)
                    ChoiceChip(
                      label: Text(gender),
                      selected: profile.gender == gender,
                      onSelected: _busy ? null : (_) => _pickGender(gender),
                      showCheckmark: false,
                      selectedColor: AppColors.accent,
                      backgroundColor: AppColors.surface,
                      side: BorderSide(color: profile.gender == gender ? AppColors.accent : AppColors.hairline),
                      shape: const StadiumBorder(),
                      labelStyle: AppTypography.footnote.copyWith(
                        color: profile.gender == gender ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Text('이름', style: AppTypography.footnote),
              const SizedBox(height: 6),
              TextField(
                controller: _fullNameController,
                maxLength: 40,
                decoration: const InputDecoration(hintText: '실명을 입력해주세요'),
              ),
              const SizedBox(height: 12),
              Text('전화번호', style: AppTypography.footnote),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: '010-0000-0000'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _saveNameAndPhone,
                  child: const Text('저장'),
                ),
              ),
              const SizedBox(height: 28),
              _AttributeSection(
                title: '모교',
                type: 'school',
                attributes: _attributes,
                busy: _busy,
                onAdd: () => _addAttribute('school'),
                onDelete: _deleteAttribute,
              ),
              const SizedBox(height: 22),
              _AttributeSection(
                title: '살았던 곳',
                type: 'region',
                attributes: _attributes,
                busy: _busy,
                onAdd: () => _addAttribute('region'),
                onDelete: _deleteAttribute,
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          error: (_, _) => Center(child: Text('불러오지 못했어요', style: AppTypography.subhead)),
        ),
      ),
    );
  }
}

class _AttributeSection extends StatelessWidget {
  const _AttributeSection({
    required this.title,
    required this.type,
    required this.attributes,
    required this.busy,
    required this.onAdd,
    required this.onDelete,
  });

  final String title;
  final String type;
  final List<MemoryAttribute>? attributes;
  final bool busy;
  final VoidCallback onAdd;
  final ValueChanged<MemoryAttribute> onDelete;

  @override
  Widget build(BuildContext context) {
    final items = attributes?.where((a) => a.type == type).toList() ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: AppTypography.footnote),
            TextButton.icon(
              onPressed: busy ? null : onAdd,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('추가'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (attributes == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (items.isEmpty)
          Text('아직 등록한 정보가 없어요', style: AppTypography.caption.copyWith(color: AppColors.inkTertiary))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final attribute in items)
                Chip(
                  label: Text(
                    [attribute.label, if (attribute.periodLabel.isNotEmpty) attribute.periodLabel].join(' · '),
                  ),
                  onDeleted: busy ? null : () => onDelete(attribute),
                  backgroundColor: AppColors.fieldBg,
                  side: BorderSide.none,
                ),
            ],
          ),
      ],
    );
  }
}
