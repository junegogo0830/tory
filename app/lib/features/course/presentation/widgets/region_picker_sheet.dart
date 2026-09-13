import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/tour_course.dart';
import '../../../../data/repositories/repository_providers.dart';
import '../../../../shared/widgets/region_select_sheet.dart';

Future<void> showRegionPickerSheet(BuildContext context, WidgetRef ref) async {
  final region = await showRegionSelectSheet(
    context,
    prompt: '어느 지역 코스를 만들까요?',
  );
  if (region == null || !context.mounted) return;
  final course = await showModalBottomSheet<TourCourse>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.paper,
    builder: (_) => _CoursePreferences(region: region),
  );
  if (course != null && context.mounted) context.push('/course/${course.id}');
}

class _CoursePreferences extends ConsumerStatefulWidget {
  const _CoursePreferences({required this.region});
  final String region;
  @override
  ConsumerState<_CoursePreferences> createState() => _CoursePreferencesState();
}

class _CoursePreferencesState extends ConsumerState<_CoursePreferences> {
  String _age = '선택 안 함',
      _gender = '선택 안 함',
      _pace = '보통',
      _weather = 'current';
  final Set<String> _categories = {'산책'};
  int _hours = 3;
  bool _busy = false;
  String? _error;
  final CancelToken _cancel = CancelToken();

  @override
  void dispose() {
    _cancel.cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_busy || _categories.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final course = await ref.read(courseRepositoryProvider).generate({
        'region': widget.region,
        'age_group': _age,
        'gender': _gender,
        'categories': _categories.toList(),
        'weather_mode': _weather,
        'pace': _pace,
        'duration_hours': _hours,
      }, cancelToken: _cancel);
      if (mounted) Navigator.pop(context, course);
    } on DioException catch (e) {
      if (!mounted || CancelToken.isCancel(e)) return;
      final detail = e.response?.data;
      setState(
        () => _error = detail is Map && detail['detail'] is String
            ? detail['detail'] as String
            : '지역 정보를 불러오지 못했어요. 다시 시도해주세요.',
      );
    } catch (_) {
      if (mounted) setState(() => _error = '코스를 만들지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _choices(
    String title,
    List<String> values,
    String selected,
    ValueChanged<String> change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: AppTypography.headline),
      const SizedBox(height: 8),
      Wrap(
        spacing: 7,
        runSpacing: 5,
        children: values
            .map(
              (v) => ChoiceChip(
                label: Text(v),
                selected: selected == v,
                onSelected: _busy ? null : (_) => setState(() => change(v)),
                selectedColor: AppColors.accentTint,
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 20),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: .93,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('나에게 맞는 옛길', style: AppTypography.title),
                      const SizedBox(height: 4),
                      Text(widget.region, style: AppTypography.subhead),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('어떤 여행을 하고 싶나요?', style: AppTypography.headline),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    children: ['산책', '역사', '미식', '문화', '자연', '가족']
                        .map(
                          (c) => FilterChip(
                            label: Text(c),
                            selected: _categories.contains(c),
                            selectedColor: AppColors.accentTint,
                            onSelected: _busy
                                ? null
                                : (selected) => setState(() {
                                    if (selected) {
                                      _categories.add(c);
                                    } else if (_categories.length > 1) {
                                      _categories.remove(c);
                                    }
                                  }),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  Text('날씨', style: AppTypography.headline),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _weather,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'current',
                        child: Text('선택 지역의 현재 날씨 자동 반영'),
                      ),
                      DropdownMenuItem(value: 'clear', child: Text('맑음')),
                      DropdownMenuItem(value: 'rain', child: Text('비')),
                      DropdownMenuItem(value: 'snow', child: Text('눈')),
                      DropdownMenuItem(value: 'hot', child: Text('더위')),
                      DropdownMenuItem(value: 'cold', child: Text('추위')),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _weather = v!),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '현재 날씨는 코스를 만들 때 확인해요. 비·눈·더위·추위에는 실내 장소와 짧은 이동을 우선해요.',
                    style: AppTypography.footnote,
                  ),
                  const SizedBox(height: 20),
                  _choices(
                    '연령대 (선택)',
                    ['선택 안 함', '10대', '20대', '30대', '40대', '50대', '60대 이상'],
                    _age,
                    (v) => _age = v,
                  ),
                  _choices(
                    '성별 (선택)',
                    ['선택 안 함', '여성', '남성', '기타'],
                    _gender,
                    (v) => _gender = v,
                  ),
                  _choices(
                    '여행 속도',
                    ['여유롭게', '보통', '활기차게'],
                    _pace,
                    (v) => _pace = v,
                  ),
                  Text('여행 시간 · $_hours시간', style: AppTypography.headline),
                  Slider(
                    value: _hours.toDouble(),
                    min: 1,
                    max: 8,
                    divisions: 7,
                    label: '$_hours시간',
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _hours = v.round()),
                  ),
                  Text(
                    '실제 등록된 장소를 이동 거리와 관심사에 맞춰 연결해요. 성별만으로 장소를 제한하지 않아요.',
                    style: AppTypography.footnote,
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.accentDeep),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _generate,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.route_outlined),
                  label: Text(_busy ? '날씨와 주변 장소를 확인하고 있어요…' : '내 코스 만들기'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
