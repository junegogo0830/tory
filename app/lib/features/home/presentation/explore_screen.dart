import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  int selectedRegion = 0;

  static const regions = ['전체', '전라', '경상', '강원', '서울'];
  static const places = [
    _PlaceData(
      id: 'suncheon-jeonpo',
      title: '전포동 골목',
      region: '전라남도 순천시',
      description: '시간이 천천히 걷던 골목, 담벼락 너머로 들리던 아이들 웃음소리가 아직도 남아 있어요.',
      image: 'assets/images/alley-current.png',
    ),
    _PlaceData(
      id: 'gunsan-jungang',
      title: '중앙로 상가',
      region: '전라북도 군산시',
      description: '변화했던 그때 그 거리, 간판 아래 오가던 사람들의 발걸음이 추억을 되살려 줍니다.',
      image: 'assets/images/market.png',
    ),
    _PlaceData(
      id: 'yeongwol-jang',
      title: '영월장 인근',
      region: '강원도 영월군',
      description: '장날이면 더 활기찼던 골목, 정겨운 인심과 풍경이 그대로 남아 있어요.',
      image: 'assets/images/alley-1998.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5EF),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 36),
              children: [
                _Header(onSearch: () {}, onFilter: () {}),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: regions.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) => ChoiceChip(
                      label: Text(regions[index]),
                      selected: selectedRegion == index,
                      onSelected: (_) => setState(() => selectedRegion = index),
                      selectedColor: AppColors.gold,
                      backgroundColor: Colors.white,
                      side: BorderSide.none,
                      showCheckmark: false,
                      labelStyle: AppTypography.body.copyWith(
                        color: selectedRegion == index ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w500,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Icon(Icons.star_outline, color: AppColors.goldDeep, size: 27),
                    const SizedBox(width: 8),
                    Text('이번 주 추천 골목', style: AppTypography.title),
                  ],
                ),
                const SizedBox(height: 14),
                for (final place in places) ...[
                  _PlaceCard(place: place),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSearch, required this.onFilter});
  final VoidCallback onSearch;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '둘러보기',
                style: AppTypography.largeTitle.copyWith(fontSize: 34),
              ),
            ),
            IconButton(onPressed: onSearch, icon: const Icon(Icons.search, size: 30)),
            IconButton(onPressed: onFilter, icon: const Icon(Icons.tune, size: 28)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '추억이 머무는 동네를 둘러보세요',
          style: AppTypography.body.copyWith(color: const Color(0xFF8F806E)),
        ),
      ],
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place});
  final _PlaceData place;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 7)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth > 560;
          final image = Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(place.image, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0x45000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          );
          final detail = _PlaceDetail(place: place);
          if (horizontal) {
            return SizedBox(
              height: 250,
              child: Row(
                children: [Expanded(flex: 4, child: image), Expanded(flex: 6, child: detail)],
              ),
            );
          }
          return Column(
            children: [SizedBox(height: 210, width: double.infinity, child: image), detail],
          );
        },
      ),
    );
  }
}

class _PlaceDetail extends StatelessWidget {
  const _PlaceDetail({required this.place});
  final _PlaceData place;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(child: Text(place.title, style: AppTypography.title.copyWith(fontSize: 23))),
              const Icon(Icons.bookmark_border, color: AppColors.goldDeep, size: 28),
            ],
          ),
          const SizedBox(height: 4),
          Text(place.region, style: AppTypography.subhead.copyWith(color: AppColors.goldDeep)),
          const SizedBox(height: 12),
          Text(place.description, style: AppTypography.subhead.copyWith(height: 1.55)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/compare/${place.id}'),
                  icon: const Icon(Icons.compare, size: 17),
                  label: const Text('과거와 비교'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/archive/${place.id}'),
                  icon: const Icon(Icons.newspaper_outlined, size: 17),
                  label: const Text('그 시절 뉴스'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaceData {
  const _PlaceData({
    required this.id,
    required this.title,
    required this.region,
    required this.description,
    required this.image,
  });
  final String id;
  final String title;
  final String region;
  final String description;
  final String image;
}
