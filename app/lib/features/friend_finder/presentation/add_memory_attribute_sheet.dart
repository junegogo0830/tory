import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/hometown_location.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/region_select_sheet.dart';

/// 추억 조건 하나의 초안 — 학교/동네/장소 중 하나 + 시기(연도, 둘 다 비워도 됨).
/// 친구 찾기 검색 필터로도, 내 추억 프로필에 저장하는 입력으로도 그대로 쓴다.
class DraftMemoryAttribute {
  const DraftMemoryAttribute({
    required this.type,
    required this.label,
    this.placeId,
    this.startYear,
    this.endYear,
  });

  final String type; // 'region' | 'school' | 'place'
  final String label;
  final String? placeId;
  final int? startYear;
  final int? endYear;

  String get periodLabel {
    if (startYear != null && endYear != null) return '$startYear~$endYear';
    if (startYear != null) return '$startYear~';
    if (endYear != null) return '~$endYear';
    return '';
  }

  String get displayLabel {
    final period = periodLabel;
    return period.isEmpty ? label : '$label · $period';
  }

  Map<String, dynamic> toSearchFilterJson() => {
    'type': type,
    'label': label,
    'place_id': placeId,
    'start_year': startYear,
    'end_year': endYear,
  };
}

/// 추억 조건 추가 바텀시트 — 학교/동네/장소 중 하나를 고르고 시기를 입력한다.
/// [initialType]으로 처음 열릴 탭을 지정할 수 있다("모교 추가"/"살았던 곳 추가"
/// 버튼처럼 맥락이 정해진 곳에서 쓴다) — 그래도 전환 자체는 계속 허용한다.
Future<DraftMemoryAttribute?> showAddMemoryAttributeSheet(BuildContext context, {String initialType = 'school'}) {
  return showModalBottomSheet<DraftMemoryAttribute>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (context) => _AddMemoryAttributeContent(initialType: initialType),
  );
}

class _AddMemoryAttributeContent extends ConsumerStatefulWidget {
  const _AddMemoryAttributeContent({this.initialType = 'school'});

  final String initialType;

  @override
  ConsumerState<_AddMemoryAttributeContent> createState() => _AddMemoryAttributeContentState();
}

class _AddMemoryAttributeContentState extends ConsumerState<_AddMemoryAttributeContent> {
  late String _type = widget.initialType;
  final _labelController = TextEditingController();
  final _startYearController = TextEditingController();
  final _endYearController = TextEditingController();

  // school
  Timer? _schoolDebounce;
  bool _searchingSchool = false;
  List<({String name, String address})> _schoolResults = [];

  // place
  Timer? _placeDebounce;
  bool _searchingPlace = false;
  List<HometownLocation> _placeResults = [];
  HometownLocation? _selectedPlace;

  // region
  String? _selectedRegion;

  @override
  void dispose() {
    _labelController.dispose();
    _startYearController.dispose();
    _endYearController.dispose();
    _schoolDebounce?.cancel();
    _placeDebounce?.cancel();
    super.dispose();
  }

  void _onSchoolQueryChanged(String query) {
    _schoolDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _schoolResults = []);
      return;
    }
    _schoolDebounce = Timer(const Duration(milliseconds: 350), () => _searchSchool(query.trim()));
  }

  Future<void> _searchSchool(String query) async {
    setState(() => _searchingSchool = true);
    try {
      final results = await ref.read(communityRepositoryProvider).searchSchools(query);
      if (mounted) {
        setState(() => _schoolResults = [for (final r in results) (name: r.name, address: r.address)]);
      }
    } catch (_) {
      if (mounted) setState(() => _schoolResults = []);
    } finally {
      if (mounted) setState(() => _searchingSchool = false);
    }
  }

  void _onPlaceQueryChanged(String query) {
    _placeDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _placeResults = []);
      return;
    }
    _placeDebounce = Timer(const Duration(milliseconds: 350), () => _searchPlace(query.trim()));
  }

  Future<void> _searchPlace(String query) async {
    setState(() => _searchingPlace = true);
    try {
      final results = await ref.read(locationRepositoryProvider).searchLocations(query);
      if (mounted) setState(() => _placeResults = results);
    } catch (_) {
      if (mounted) setState(() => _placeResults = []);
    } finally {
      if (mounted) setState(() => _searchingPlace = false);
    }
  }

  Future<void> _pickRegion() async {
    final selected = await showRegionSelectSheet(context, prompt: '살았던 지역을 선택해주세요');
    if (selected != null && mounted) setState(() => _selectedRegion = selected);
  }

  void _submit() {
    final startYear = int.tryParse(_startYearController.text.trim());
    final endYear = int.tryParse(_endYearController.text.trim());
    if (endYear != null && startYear != null && endYear < startYear) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('종료 연도가 시작 연도보다 빠를 수 없어요')),
      );
      return;
    }

    switch (_type) {
      case 'school':
        final label = _labelController.text.trim();
        if (label.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('학교를 검색해서 선택해주세요')));
          return;
        }
        Navigator.of(context).pop(
          DraftMemoryAttribute(type: 'school', label: label, startYear: startYear, endYear: endYear),
        );
      case 'region':
        final neighborhood = _labelController.text.trim();
        if (_selectedRegion == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('지역을 선택해주세요')));
          return;
        }
        final label = neighborhood.isEmpty ? _selectedRegion! : '$_selectedRegion $neighborhood';
        Navigator.of(context).pop(
          DraftMemoryAttribute(type: 'region', label: label, startYear: startYear, endYear: endYear),
        );
      case 'place':
        final place = _selectedPlace;
        if (place == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('장소를 검색해서 선택해주세요')));
          return;
        }
        Navigator.of(context).pop(
          DraftMemoryAttribute(type: 'place', label: place.name, placeId: place.id),
        );
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
          Text('추억 조건 추가', style: AppTypography.headline),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'school', label: Text('학교'), icon: Icon(Icons.school_outlined, size: 16)),
              ButtonSegment(value: 'region', label: Text('동네'), icon: Icon(Icons.home_outlined, size: 16)),
              ButtonSegment(value: 'place', label: Text('장소'), icon: Icon(Icons.place_outlined, size: 16)),
            ],
            selected: {_type},
            onSelectionChanged: (value) => setState(() => _type = value.first),
          ),
          const SizedBox(height: 14),
          if (_type == 'school') ...[
            TextField(
              controller: _labelController,
              onChanged: _onSchoolQueryChanged,
              decoration: const InputDecoration(hintText: '학교 이름 검색', prefixIcon: Icon(Icons.search)),
            ),
            if (_searchingSchool)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else if (_schoolResults.isNotEmpty)
              _ResultList(
                items: [for (final s in _schoolResults) (title: s.name, subtitle: s.address)],
                onTap: (index) => setState(() {
                  _labelController.text = _schoolResults[index].name;
                  _schoolResults = [];
                }),
              ),
          ] else if (_type == 'region') ...[
            OutlinedButton.icon(
              onPressed: _pickRegion,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text(_selectedRegion ?? '지역 선택 (도/시군구)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _labelController,
              maxLength: 30,
              decoration: const InputDecoration(hintText: '동네 이름 (선택, 예: 고잔동)', counterText: ''),
            ),
          ] else ...[
            TextField(
              onChanged: _onPlaceQueryChanged,
              enabled: _selectedPlace == null,
              decoration: InputDecoration(
                hintText: _selectedPlace?.name ?? '자주 갔던 장소 검색',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _selectedPlace != null
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _selectedPlace = null),
                      )
                    : null,
              ),
            ),
            if (_searchingPlace)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else if (_placeResults.isNotEmpty)
              _ResultList(
                items: [for (final p in _placeResults) (title: p.name, subtitle: p.region)],
                onTap: (index) => setState(() {
                  _selectedPlace = _placeResults[index];
                  _placeResults = [];
                }),
              ),
          ],
          const SizedBox(height: 14),
          Text('시기 (선택)', style: AppTypography.footnote.copyWith(color: AppColors.inkSecondary)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startYearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: '시작 연도'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _endYearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: '종료 연도'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _submit, child: const Text('추가')),
          ),
        ],
      ),
    );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({required this.items, required this.onTap});

  final List<({String title, String subtitle})> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: items.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.hairline),
        itemBuilder: (context, index) => ListTile(
          dense: true,
          title: Text(items[index].title, style: AppTypography.body),
          subtitle: Text(items[index].subtitle, style: AppTypography.caption),
          onTap: () => onTap(index),
        ),
      ),
    );
  }
}
