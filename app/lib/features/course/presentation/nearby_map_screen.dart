import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../shared/widgets/web_iframe_view.dart';

/// "내 주변 관광지" 지도. GPS 대신 사용자가 직접 지역/장소를 검색해서 고르면
/// 그 좌표로 백엔드가 서빙하는 카카오맵 페이지(`/map/nearby`)를 띄운다 —
/// roadview_screen.dart와 같은 이유로 백엔드 도메인에서 서빙해야 한다
/// (카카오맵 JS SDK가 페이지 도메인을 검사함).
class NearbyMapScreen extends ConsumerStatefulWidget {
  const NearbyMapScreen({super.key});

  @override
  ConsumerState<NearbyMapScreen> createState() => _NearbyMapScreenState();
}

class _NearbyMapScreenState extends ConsumerState<NearbyMapScreen> {
  final _controller = TextEditingController();
  double? _lat;
  double? _lng;
  String? _placeName;
  bool _isSearching = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _isSearching = true;
      _error = null;
    });
    try {
      final location = await ref.read(locationRepositoryProvider).resolveFromQuery(query);
      if (!location.hasCoordinates) {
        if (mounted) setState(() => _error = '이 장소의 좌표를 찾지 못했어요. 다른 이름으로 검색해보세요');
        return;
      }
      if (mounted) {
        setState(() {
          _lat = location.latitude;
          _lng = location.longitude;
          _placeName = location.name;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '장소를 찾지 못했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = _lat;
    final lng = _lng;

    if (lat == null || lng == null) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(title: const Text('내 주변 관광지')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('어느 지역을 둘러볼까요?', style: AppTypography.sectionTitle),
                const SizedBox(height: 6),
                Text(
                  '동네, 관광지, 학교 이름 등으로 검색해보세요',
                  style: AppTypography.footnote.copyWith(color: AppColors.inkSecondary),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: '예: 수원 영통구, 강릉 남산공원',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.field),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSearching ? null : _search,
                    child: _isSearching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('검색'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: AppTypography.footnote.copyWith(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final url = '${AppConstants.apiBaseUrl}/map/nearby?lat=$lat&lng=$lng';
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(_placeName ?? '내 주변 관광지'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => setState(() {
              _lat = null;
              _lng = null;
            }),
          ),
        ],
      ),
      // webview_flutter는 웹 구현체가 없어서, 웹에서는 새 탭 대신 iframe으로
      // 바로 이 화면 안에 지도를 심는다(WebIframeView, dart:ui_web 기반).
      body: kIsWeb ? WebIframeView(url: url) : _NativeMap(key: ValueKey('$lat,$lng'), lat: lat, lng: lng),
    );
  }
}

class _NativeMap extends StatefulWidget {
  const _NativeMap({super.key, required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  State<_NativeMap> createState() => _NativeMapState();
}

class _NativeMapState extends State<_NativeMap> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.paper)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(
        Uri.parse(
          '${AppConstants.apiBaseUrl}/map/nearby?lat=${widget.lat}&lng=${widget.lng}',
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          ColoredBox(
            color: AppColors.paper,
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          ),
      ],
    );
  }
}
