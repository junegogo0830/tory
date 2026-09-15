import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/custom_course.dart';
import '../../../data/repositories/repository_providers.dart';
import '../data/custom_course_providers.dart';
import 'widgets/course_roadmap.dart';
import 'widgets/place_search_sheet.dart';

const _maxPlaces = 15;

/// 담긴 장소 하나 + 그 장소에 대한 코멘트 입력 컨트롤러를 함께 들고 있는
/// 작성 화면 전용 드래프트 단위.
class _DraftPlace {
  _DraftPlace(this.place) : noteController = TextEditingController(text: place.note ?? '');

  final CustomCoursePlace place;
  final TextEditingController noteController;

  void dispose() => noteController.dispose();
}

/// 사용자가 직접 장소를 검색해 담아 만드는 "코스 커스텀" 작성 화면 — 담은
/// 장소는 로드맵처럼 지그재그로 이어 보여준다(course_roadmap.dart). 로그인은
/// 진입 전(커뮤니티 탭의 "옛길 게시판" 팝업 또는 목록 화면 "코스 만들기"
/// 버튼)에서 이미 확인했다고 가정한다.
///
/// [editCourseId]를 주면(코스 상세의 "코스 수정") 그 코스를 불러와 필드를
/// 채워두고, 제출 시 새로 만드는 대신 통째로 업데이트한다.
class CustomCourseCreateScreen extends ConsumerStatefulWidget {
  const CustomCourseCreateScreen({super.key, this.editCourseId});

  final int? editCourseId;

  @override
  ConsumerState<CustomCourseCreateScreen> createState() => _CustomCourseCreateScreenState();
}

class _CustomCourseCreateScreenState extends ConsumerState<CustomCourseCreateScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _category;
  bool _isPublic = true;
  final List<_DraftPlace> _places = [];
  bool _submitting = false;

  bool get _isEditing => widget.editCourseId != null;

  // 수정 모드에서 기존 코스를 불러오는 동안의 상태.
  bool _loadingExisting = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadExistingCourse();
  }

  Future<void> _loadExistingCourse() async {
    setState(() => _loadingExisting = true);
    try {
      final course = await ref.read(customCourseRepositoryProvider).getById(widget.editCourseId!);
      if (!mounted) return;
      setState(() {
        _titleController.text = course.title;
        _descriptionController.text = course.description ?? '';
        _category = course.category;
        _isPublic = course.isPublic;
        _places.addAll(course.places.map(_DraftPlace.new));
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final draft in _places) {
      draft.dispose();
    }
    super.dispose();
  }

  bool _addPlaceToDraft(CustomCoursePlace place) {
    if (_places.length >= _maxPlaces) return false;
    if (_places.any((d) => d.place.source == place.source && d.place.placeId == place.placeId)) return false;
    _places.add(_DraftPlace(place));
    return true;
  }

  Future<void> _addPlace() async {
    if (_places.length >= _maxPlaces) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('장소는 최대 $_maxPlaces곳까지 담을 수 있어요')),
      );
      return;
    }
    final place = await showPlaceSearchSheet(context);
    if (place == null || !mounted) return;
    if (!_addPlaceToDraft(place)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미 담은 장소예요')));
      return;
    }
    setState(() {});
  }

  /// "커스텀 코스에서 가져오기" — 다른 코스의 장소 목록을 통째로 불러와
  /// 지금 만드는 코스 뒤에 이어 붙인다(이미 담은 장소는 건너뛴다).
  Future<void> _importFromMyCourse() async {
    final picked = await showModalBottomSheet<CustomCourseSummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (context) => const _MyCoursePickerSheet(),
    );
    if (picked == null || !mounted) return;

    try {
      final course = await ref.read(customCourseRepositoryProvider).getById(picked.id);
      if (!mounted) return;
      var added = 0;
      setState(() {
        for (final place in course.places) {
          if (_addPlaceToDraft(place)) added++;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(added > 0 ? '장소 $added곳을 가져왔어요' : '가져올 새 장소가 없어요')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('불러오지 못했어요. 다시 시도해주세요.')));
      }
    }
  }

  void _removePlace(int index) {
    setState(() {
      _places.removeAt(index).dispose();
    });
  }

  /// 검색 결과 썸네일 대신(또는 썸네일이 없을 때) 직접 찍거나 고른 사진으로 바꾼다.
  Future<void> _pickPlacePhoto(int index) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
    if (picked == null || !mounted) return;
    try {
      final bytes = await picked.readAsBytes();
      final mimeType = bytes.length >= 12 && bytes[0] == 0x89 && bytes[1] == 0x50
          ? 'image/png'
          : bytes.length >= 12 && bytes[0] == 0x52 && bytes[8] == 0x57
          ? 'image/webp'
          : 'image/jpeg';
      final url = await ref
          .read(customCourseRepositoryProvider)
          .uploadPhoto(bytes: bytes, filename: picked.name, mimeType: mimeType);
      if (!mounted) return;
      setState(() {
        final draft = _places[index];
        // 아직 제출 전인 코멘트 입력 중일 수 있으니 place.note(마지막 저장값)가
        // 아니라 노트 컨트롤러의 지금 실제 입력값을 그대로 옮긴다.
        final updatedPlace = draft.place.copyWith(note: draft.noteController.text, imageUrl: url);
        _places[index] = _DraftPlace(updatedPlace);
        draft.dispose();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('사진을 올리지 못했어요. 다시 시도해주세요.')));
      }
    }
  }

  void _saveDraft() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('임시 저장했어요')));
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('코스 제목을 입력해주세요')));
      return;
    }
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('카테고리를 선택해주세요')));
      return;
    }
    if (_places.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('장소를 하나 이상 담아주세요')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final description = _descriptionController.text.trim();
      final places = [
        for (final draft in _places)
          draft.place.copyWith(note: draft.noteController.text.trim().isEmpty ? null : draft.noteController.text.trim()),
      ];
      final repo = ref.read(customCourseRepositoryProvider);
      // customCourseListProvider는 family라 특정 인자로 호출하지 않고 바로
      // invalidate하면 캐싱된 모든 카테고리/정렬 조합이 한꺼번에 갱신된다.
      if (_isEditing) {
        final course = await repo.update(
          id: widget.editCourseId!,
          title: title,
          category: _category!,
          description: description.isEmpty ? null : description,
          places: places,
          isPublic: _isPublic,
        );
        ref.invalidate(customCourseListProvider);
        ref.invalidate(customCourseDetailProvider(course.id));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('코스를 수정했어요')));
        context.pop();
      } else {
        final course = await repo.create(
          title: title,
          category: _category!,
          description: description.isEmpty ? null : description,
          places: places,
          isPublic: _isPublic,
        );
        ref.invalidate(customCourseListProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('코스가 등록됐어요')));
        context.pushReplacement('/custom-courses/${course.id}');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? '수정에 실패했어요. 다시 시도해주세요.' : '등록에 실패했어요. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingExisting) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(title: const Text('코스 수정')),
        body: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    if (_loadFailed) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(title: const Text('코스 수정')),
        body: Center(child: Text('코스를 불러오지 못했어요', style: AppTypography.subhead)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(_isEditing ? '코스 수정' : '코스 공유 만들기'),
        actions: [
          if (!_isEditing)
            TextButton(
              onPressed: _submitting ? null : _saveDraft,
              child: Text('임시 저장', style: AppTypography.footnote.copyWith(color: AppColors.accentDeep, fontWeight: FontWeight.w600)),
            ),
          InkWell(
            onTap: () => context.go('/profile'),
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.only(right: 16, left: 4),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.accentTint,
                child: Icon(Icons.person_outline, size: 17, color: AppColors.accentDeep),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text('코스 제목', style: AppTypography.headline),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  maxLength: 60,
                  decoration: const InputDecoration(hintText: '예: 주말 오후 벚꽃길 산책 코스'),
                ),
                const SizedBox(height: 22),
                Text('장소 추가', style: AppTypography.headline),
                const SizedBox(height: 8),
                _ImportFromMyCourseCard(onTap: _importFromMyCourse),
                const SizedBox(height: 20),
                Text('장소 검색 추가', style: AppTypography.headline),
                const SizedBox(height: 8),
                _SearchBar(onTap: _addPlace),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('나의 로드맵', style: AppTypography.headline),
                    Text('${_places.length}/$_maxPlaces', style: AppTypography.caption.copyWith(color: AppColors.inkTertiary)),
                  ],
                ),
                const SizedBox(height: 10),
                CourseRoadmap(
                  items: [
                    for (var i = 0; i < _places.length; i++)
                      CourseRoadmapItem(
                        title: _places[i].place.name,
                        subtitle: _places[i].place.address,
                        imageUrl: _places[i].place.imageUrl,
                        onRemove: () => _removePlace(i),
                        onEditPhoto: () => _pickPlacePhoto(i),
                        side: _PlaceNoteField(
                          controller: _places[i].noteController,
                          placeName: _places[i].place.name,
                        ),
                      ),
                  ],
                  trailingAdd: _places.length >= _maxPlaces ? null : _addPlace,
                ),
                const SizedBox(height: 12),
                Text('카테고리', style: AppTypography.headline),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in customCourseCategories)
                      ChoiceChip(
                        label: Text(category),
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
                        showCheckmark: false,
                        selectedColor: AppColors.accent,
                        backgroundColor: AppColors.surface,
                        side: BorderSide(color: _category == category ? AppColors.accent : AppColors.hairline),
                        shape: const StadiumBorder(),
                        labelStyle: AppTypography.footnote.copyWith(
                          color: _category == category ? Colors.white : AppColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                Text('소개 (선택)', style: AppTypography.headline),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  maxLength: 300,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: '이 코스를 어떻게 즐기면 좋을지 알려주세요'),
                ),
                const SizedBox(height: 22),
                Text('공개 설정', style: AppTypography.headline),
                const SizedBox(height: 8),
                _VisibilityToggle(isPublic: _isPublic, onChanged: (value) => setState(() => _isPublic = value)),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.hairline)),
          ),
          // Center(기본값)는 세로 방향으로도 "가능한 한 크게" 확장한다 — Scaffold가
          // bottomNavigationBar에 (남은 화면 높이만큼) 넉넉한 세로 제약을 주면
          // 이 Center가 그걸 그대로 다 차지해버려서, body 쪽엔 높이가 0만 남고
          // 화면 전체가 텅 비어 보이는 버그였다. heightFactor: 1로 자식(Row) 높이
          // 만큼만 차지하게 하고, 가로만 계속 꽉 채워서(widthFactor 없음) 가로
          // 가운데 정렬은 그대로 유지한다.
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: Row(
                children: [
                  Text(
                    '${_places.length}/$_maxPlaces',
                    style: AppTypography.footnote.copyWith(color: AppColors.inkTertiary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isEditing ? '수정 완료' : '코스 등록하기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImportFromMyCourseCard extends StatelessWidget {
  const _ImportFromMyCourseCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadows.tile,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.pastelSky, borderRadius: BorderRadius.circular(AppRadius.tile)),
              child: Icon(Icons.route_outlined, color: AppColors.accentDeep, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('커스텀 코스에서 가져오기', style: AppTypography.body.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('기존에 만든 코스에서 바로 가져오기', style: AppTypography.caption.copyWith(color: AppColors.inkTertiary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.inkTertiary),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.fieldBg, borderRadius: BorderRadius.circular(AppRadius.field)),
        child: Row(
          children: [
            Icon(Icons.search, size: 20, color: AppColors.inkTertiary),
            const SizedBox(width: 10),
            Text('장소 이름으로 검색해보세요', style: AppTypography.body.copyWith(color: AppColors.inkTertiary)),
          ],
        ),
      ),
    );
  }
}

class _PlaceNoteField extends StatelessWidget {
  const _PlaceNoteField({required this.controller, required this.placeName});

  final TextEditingController controller;
  final String placeName;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: 300,
      maxLines: 3,
      style: AppTypography.caption.copyWith(color: AppColors.ink, fontSize: 12),
      decoration: InputDecoration(
        hintText: '$placeName에 대한 당신의 생각',
        hintStyle: AppTypography.caption.copyWith(color: AppColors.inkTertiary, fontSize: 12),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({required this.isPublic, required this.onChanged});

  final bool isPublic;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _VisibilityOption(label: '공개', selected: isPublic, onTap: () => onChanged(true))),
        const SizedBox(width: 10),
        Expanded(child: _VisibilityOption(label: '비공개', selected: !isPublic, onTap: () => onChanged(false))),
      ],
    );
  }
}

class _VisibilityOption extends StatelessWidget {
  const _VisibilityOption({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.accentTint : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.field),
          border: Border.all(color: selected ? AppColors.accent : AppColors.hairline),
        ),
        child: Text(
          label,
          style: AppTypography.footnote.copyWith(
            color: selected ? AppColors.accentDeep : AppColors.inkSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MyCoursePickerSheet extends ConsumerWidget {
  const _MyCoursePickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myCoursesAsync = ref.watch(myCustomCoursesProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('내가 만든 코스에서 가져오기', style: AppTypography.headline),
          const SizedBox(height: 6),
          Text('선택한 코스의 장소를 통째로 불러와요', style: AppTypography.footnote),
          const SizedBox(height: 14),
          SizedBox(
            height: 320,
            child: myCoursesAsync.when(
              data: (courses) => courses.isEmpty
                  ? Center(
                      child: Text(
                        '아직 만든 코스가 없어요',
                        style: AppTypography.subhead.copyWith(color: AppColors.inkTertiary),
                      ),
                    )
                  : ListView.separated(
                      itemCount: courses.length,
                      separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.hairline),
                      itemBuilder: (context, index) {
                        final course = courses[index];
                        return ListTile(
                          leading: const Icon(Icons.route_outlined, color: AppColors.accentDeep),
                          title: Text(course.title, style: AppTypography.body),
                          subtitle: Text('${course.category} · 장소 ${course.placeCount}곳', style: AppTypography.caption),
                          onTap: () => Navigator.of(context).pop(course),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
              error: (_, _) => Center(
                child: Text('불러오지 못했어요', style: AppTypography.subhead.copyWith(color: AppColors.inkTertiary)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
