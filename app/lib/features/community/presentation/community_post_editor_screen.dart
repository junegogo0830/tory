import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/hometown_location.dart';
import '../../../data/models/pending_photo.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../profile/data/profile_providers.dart';
import '../data/community_providers.dart';
import '../domain/community_board.dart';
import 'widgets/trade_status_chip.dart' show tradeStatuses;

const _maxPhotosPerPost = 5;

/// 글쓰기 풀페이지로 넘어갈 때 필요한 정보 — 어느 게시판에, 어느 지역에,
/// (compare_screen에서 왔다면) 어느 장소를 이미 붙인 채로 쓰는지.
class CommunityPostEditorArgs {
  const CommunityPostEditorArgs({
    required this.region,
    required this.board,
    this.locationId,
  });

  final String region;
  final CommunityBoard board;
  final String? locationId;
}

sealed class _EditorBlock {}

class _TextEditorBlock extends _EditorBlock {
  _TextEditorBlock({String text = ''}) : controller = TextEditingController(text: text);
  final TextEditingController controller;
}

class _ImageEditorBlock extends _EditorBlock {
  _ImageEditorBlock(this.bytes, this.filename);
  // 웹/모바일 어디서나 미리보기(Image.memory)와 업로드에 그대로 쓸 수 있게
  // XFile 경로 대신 픽 시점에 미리 읽어둔 바이트를 들고 있는다.
  final Uint8List bytes;
  final String filename;
}

/// 블로그처럼 글과 사진을 순서대로 섞어 쓰는 풀페이지 글쓰기 화면. 사진을
/// 추가하면 그 자리에 사진 블록이 들어가고, 바로 이어서 쓸 수 있게 빈 텍스트
/// 블록이 하나 더 따라붙는다. 등록 시 블록을 순서대로 훑어 텍스트/사진
/// 메타(JSON)와 실제 사진 파일 목록을 만들어 보낸다.
class CommunityPostEditorScreen extends ConsumerStatefulWidget {
  const CommunityPostEditorScreen({super.key, required this.args});

  final CommunityPostEditorArgs args;

  @override
  ConsumerState<CommunityPostEditorScreen> createState() => _CommunityPostEditorScreenState();
}

class _CommunityPostEditorScreenState extends ConsumerState<CommunityPostEditorScreen> {
  final _titleController = TextEditingController();
  final _yearController = TextEditingController();
  final _priceController = TextEditingController();
  final _placeSearchController = TextEditingController();
  final List<_EditorBlock> _blocks = [_TextEditorBlock()];

  DateTime? _revealAt;
  String _tradeStatus = tradeStatuses.first;
  bool _isTrade = true;
  bool _submitting = false;
  final Set<String> _selectedCategories = {};

  Timer? _placeDebounce;
  bool _searchingPlace = false;
  List<HometownLocation> _placeResults = [];
  HometownLocation? _attachedLocation;

  int get _photoCount => _blocks.whereType<_ImageEditorBlock>().length;

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    _priceController.dispose();
    _placeSearchController.dispose();
    _placeDebounce?.cancel();
    for (final block in _blocks) {
      if (block is _TextEditorBlock) block.controller.dispose();
    }
    super.dispose();
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

  Future<void> _pickRevealDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year + 1, now.month, now.day),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 10, now.month, now.day),
      helpText: '봉인을 풀 날짜',
    );
    if (picked != null && mounted) setState(() => _revealAt = picked);
  }

  Future<void> _addPhotos() async {
    final remaining = _maxPhotosPerPost - _photoCount;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진은 최대 $_maxPhotosPerPost장까지 첨부할 수 있어요')),
      );
      return;
    }
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 1920);
    if (picked.isEmpty || !mounted) return;

    final newBlocks = <_ImageEditorBlock>[];
    for (final photo in picked.take(remaining)) {
      final bytes = await photo.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${photo.name}은(는) 8MB를 넘어서 제외했어요')),
          );
        }
        continue;
      }
      newBlocks.add(_ImageEditorBlock(bytes, photo.name));
    }
    if (!mounted || newBlocks.isEmpty) return;
    setState(() {
      _blocks.addAll(newBlocks);
      // 사진 밑에서 바로 이어 쓸 수 있게 빈 텍스트 블록을 하나 더 붙인다.
      _blocks.add(_TextEditorBlock());
    });
  }

  void _removeBlock(_EditorBlock block) {
    setState(() {
      if (block is _TextEditorBlock) block.controller.dispose();
      _blocks.remove(block);
      if (_blocks.isEmpty) _blocks.add(_TextEditorBlock());
    });
  }

  ({List<Map<String, dynamic>> blocks, List<PendingPhoto> photos}) _resolveBlocks() {
    final metaBlocks = <Map<String, dynamic>>[];
    final photos = <PendingPhoto>[];
    for (final block in _blocks) {
      if (block is _TextEditorBlock) {
        metaBlocks.add({'type': 'text', 'text': block.controller.text.trim()});
        continue;
      }
      final imageBlock = block as _ImageEditorBlock;
      final bytes = imageBlock.bytes;
      final mimeType = bytes.length >= 12 && bytes[0] == 0x89 && bytes[1] == 0x50
          ? 'image/png'
          : bytes.length >= 12 && bytes[0] == 0x52 && bytes[8] == 0x57
          ? 'image/webp'
          : 'image/jpeg';
      photos.add(PendingPhoto(bytes: bytes, filename: imageBlock.filename, mimeType: mimeType));
      metaBlocks.add({'type': 'image', 'index': photos.length - 1});
    }
    return (blocks: metaBlocks, photos: photos);
  }

  Future<void> _submit() async {
    final board = widget.args.board;
    final title = _titleController.text.trim();

    final yearText = _yearController.text.trim();
    final year = int.tryParse(yearText);
    if (yearText.isNotEmpty && (year == null || year < 1900 || year > DateTime.now().year)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('1900년부터 올해 사이의 연도를 입력해주세요')),
      );
      return;
    }
    if (board.requiresRevealDate && _revealAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('봉인을 풀 날짜를 선택해주세요')));
      return;
    }
    if (board.requiresPhoto && _photoCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${board.label}에는 사진을 첨부해주세요')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final resolved = _resolveBlocks();
      final hasText = resolved.blocks.any((b) => b['type'] == 'text' && (b['text'] as String).isNotEmpty);
      if (title.isEmpty && !hasText && resolved.photos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('제목이나 내용을 입력해주세요')));
        return;
      }

      final isTrade = board.isTradeBoard ? _isTrade : false;
      final price = isTrade ? int.tryParse(_priceController.text.trim().replaceAll(',', '')) : null;

      await ref
          .read(communityRepositoryProvider)
          .createPost(
            region: widget.args.region,
            board: board.id,
            title: title.isEmpty ? null : title,
            photos: resolved.photos,
            locationId: widget.args.locationId ?? _attachedLocation?.id,
            memoryYear: year,
            revealAt: _revealAt,
            price: price,
            tradeStatus: isTrade ? _tradeStatus : null,
            isTrade: isTrade,
            contentBlocks: jsonEncode(resolved.blocks),
            categories: _selectedCategories.toList(),
          );
      ref.invalidate(profileProvider);
      ref.invalidate(communityFeedProvider((region: widget.args.region, board: board.id)));
      if (board.id == 'memory') ref.invalidate(communityPreviewProvider(widget.args.region));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('글이 등록됐어요')));
      context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('등록에 실패했어요. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = widget.args.board;
    final categoryOptions = ref.watch(communityPostCategoriesProvider).value?[board.id] ?? const [];
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(board.label),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentDeep),
                  )
                : Text(
                    '등록',
                    style: AppTypography.body.copyWith(color: AppColors.accentDeep, fontWeight: FontWeight.w700),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                TextField(
                  controller: _titleController,
                  maxLength: 60,
                  style: AppTypography.headline,
                  decoration: const InputDecoration(hintText: '제목', border: InputBorder.none, counterText: ''),
                ),
                const Divider(height: 24),
                if (categoryOptions.isNotEmpty) ...[
                  Text('카테고리 (중복 선택 가능)', style: AppTypography.footnote.copyWith(color: AppColors.inkSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in categoryOptions)
                        _CategoryChip(
                          label: category,
                          selected: _selectedCategories.contains(category),
                          onTap: () => setState(() {
                            if (!_selectedCategories.remove(category)) _selectedCategories.add(category);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (board.isTradeBoard) ...[
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('중고거래'), icon: Icon(Icons.sell_outlined, size: 16)),
                      ButtonSegment(value: false, label: Text('자유글'), icon: Icon(Icons.chat_bubble_outline, size: 16)),
                    ],
                    selected: {_isTrade},
                    onSelectionChanged: (value) => setState(() => _isTrade = value.first),
                  ),
                  if (_isTrade) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: '가격 (비우면 나눔)', suffixText: '원'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _tradeStatus,
                            items: [
                              for (final status in tradeStatuses)
                                DropdownMenuItem(value: status, child: Text(status, style: AppTypography.subhead)),
                            ],
                            onChanged: (value) => setState(() => _tradeStatus = value ?? tradeStatuses.first),
                            decoration: const InputDecoration(isDense: true),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
                if (board.isMapBoard && widget.args.locationId == null) ...[
                  if (_attachedLocation != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.accentTint,
                        borderRadius: BorderRadius.circular(AppRadius.field),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 17, color: AppColors.accentDeep),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_attachedLocation!.name} · ${_attachedLocation!.region}',
                              style: AppTypography.footnote.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _attachedLocation = null),
                            child: Icon(Icons.close, size: 16, color: AppColors.inkTertiary),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    TextField(
                      controller: _placeSearchController,
                      onChanged: _onPlaceQueryChanged,
                      decoration: const InputDecoration(
                        hintText: '이 이야기의 장소를 검색해보세요 (선택)',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    if (_searchingPlace)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                      )
                    else if (_placeResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.hairline),
                          borderRadius: BorderRadius.circular(AppRadius.field),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _placeResults.length,
                          separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.hairline),
                          itemBuilder: (context, index) {
                            final place = _placeResults[index];
                            return ListTile(
                              dense: true,
                              title: Text(place.name, style: AppTypography.body),
                              subtitle: Text(place.region, style: AppTypography.caption),
                              onTap: () => setState(() {
                                _attachedLocation = place;
                                _placeResults = [];
                                _placeSearchController.clear();
                              }),
                            );
                          },
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                ],
                if (board.id == 'memory') ...[
                  TextField(
                    controller: _yearController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '몇 년도 사진인가요? 예: 1999'),
                  ),
                  const SizedBox(height: 16),
                ],
                if (board.requiresRevealDate) ...[
                  OutlinedButton.icon(
                    onPressed: _pickRevealDate,
                    icon: const Icon(Icons.lock_clock_outlined, size: 18),
                    label: Text(
                      _revealAt == null
                          ? '봉인을 풀 날짜 선택'
                          : '${_revealAt!.year}.${_revealAt!.month.toString().padLeft(2, '0')}.${_revealAt!.day.toString().padLeft(2, '0')}에 열려요',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // 본문 블록 — 텍스트/사진이 작성한 순서 그대로 이어진다.
                for (final block in _blocks) ...[
                  if (block is _TextEditorBlock)
                    TextField(
                      controller: block.controller,
                      maxLength: 2000,
                      maxLines: null,
                      minLines: 3,
                      style: AppTypography.body,
                      decoration: InputDecoration(
                        hintText: board.id == 'memory' ? '예: 우리 아파트 놀이터에서 친구들이랑' : '내용을 입력해주세요',
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    )
                  else if (block is _ImageEditorBlock)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(
                              block.bytes,
                              width: double.infinity,
                              height: 220,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: InkWell(
                              onTap: () => _removeBlock(block),
                              customBorder: const CircleBorder(),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addPhotos,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: Text('사진 추가 ($_photoCount/$_maxPhotosPerPost)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.fieldBg,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? AppColors.accent : AppColors.border),
        ),
        child: Text(
          label,
          style: AppTypography.footnote.copyWith(
            color: selected ? Colors.white : AppColors.inkSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
