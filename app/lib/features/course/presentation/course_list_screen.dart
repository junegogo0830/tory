import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({super.key});

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  int selectedCategory = 0;
  static const categories = ['전체', '산책', '역사', '미식'];

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
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('추천 코스', style: AppTypography.largeTitle.copyWith(fontSize: 34)),
                          const SizedBox(height: 5),
                          Text(
                            '추억에서 오늘의 여행으로',
                            style: AppTypography.body.copyWith(color: const Color(0xFF8F806E)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.map_outlined, size: 35, color: Color(0xFF766347)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) => ChoiceChip(
                      label: Text(categories[index]),
                      selected: selectedCategory == index,
                      onSelected: (_) => setState(() => selectedCategory = index),
                      showCheckmark: false,
                      selectedColor: AppColors.gold,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.hairline),
                      labelStyle: AppTypography.subhead.copyWith(
                        color: selectedCategory == index ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const _FeaturedCourse(),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cards = [
                      const _SmallCourse(
                        id: 'c2',
                        image: 'assets/images/market.png',
                        title: '옛 시장 미식 코스',
                        score: '감성 82%',
                        time: '약 2시간 30분',
                        description: '전통시장과 숨은 맛집을 즐기는 미식 여행',
                      ),
                      const _SmallCourse(
                        id: 'c3',
                        image: 'assets/images/alley-1998.png',
                        title: '근대문화유산 골목 코스',
                        score: '감성 79%',
                        time: '약 3시간',
                        description: '근대의 흔적을 따라 걷는 역사 탐방 코스',
                      ),
                    ];
                    if (constraints.maxWidth < 560) {
                      return Column(
                        children: [cards[0], const SizedBox(height: 14), cards[1]],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 14),
                        Expanded(child: cards[1]),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedCourse extends StatelessWidget {
  const _FeaturedCourse();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 7.5,
              child: Image.asset('assets/images/suncheon-bay.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('순천만 노을 산책 코스', style: AppTypography.title.copyWith(fontSize: 25)),
              const _InfoPill(icon: Icons.favorite, label: '감성 86%', gold: true),
              const _InfoPill(icon: Icons.schedule, label: '약 3시간'),
            ],
          ),
          const SizedBox(height: 18),
          const _RouteStop(number: 1, title: '전포동 골목', detail: '옛 담장과 골목길 산책', time: '40분'),
          const _RouteStop(number: 2, title: '순천만국가정원', detail: '자연과 조화를 이루는 정원', time: '80분'),
          const _RouteStop(number: 3, title: '순천만습지 노을전망대', detail: '노을과 함께하는 낭만의 시간', time: '60분', last: true),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/course/c1'),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('코스 시작하기'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.number,
    required this.title,
    required this.detail,
    required this.time,
    this.last = false,
  });
  final int number;
  final String title;
  final String detail;
  final String time;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.gold,
                  child: Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                if (!last) Expanded(child: Container(width: 1, color: const Color(0xFFD8C8A9))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.headline),
                  const SizedBox(height: 3),
                  Text(detail, style: AppTypography.subhead),
                ],
              ),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.schedule, size: 15, color: AppColors.inkSecondary),
              const SizedBox(width: 4),
              Text(time, style: AppTypography.footnote),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label, this.gold = false});
  final IconData icon;
  final String label;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: gold ? AppColors.goldTint : Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: gold ? AppColors.gold : AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: gold ? AppColors.gold : AppColors.inkSecondary),
          const SizedBox(width: 5),
          Text(label, style: AppTypography.footnote.copyWith(color: gold ? AppColors.goldDeep : AppColors.inkSecondary)),
        ],
      ),
    );
  }
}

class _SmallCourse extends StatelessWidget {
  const _SmallCourse({
    required this.id,
    required this.image,
    required this.title,
    required this.score,
    required this.time,
    required this.description,
  });
  final String id;
  final String image;
  final String title;
  final String score;
  final String time;
  final String description;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push('/course/$id'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration(radius: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: AspectRatio(aspectRatio: 16 / 9, child: Image.asset(image, fit: BoxFit.cover)),
            ),
            const SizedBox(height: 12),
            Text(title, style: AppTypography.headline),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                Text('♥ $score', style: AppTypography.footnote.copyWith(color: AppColors.goldDeep)),
                Text('◷ $time', style: AppTypography.footnote),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: AppTypography.subhead),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration({required double radius}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 7)),
      ],
    );
