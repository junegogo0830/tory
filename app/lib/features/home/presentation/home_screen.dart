import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../compare/presentation/widgets/compare_slider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _openMemory() => context.push('/compare/suncheon-jeonpo');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5EF),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
              children: [
                const _TopBar(),
                const SizedBox(height: 32),
                Text(
                  '그리운 동네를 찾아보세요',
                  style: AppTypography.largeTitle.copyWith(
                    fontSize: 30,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 18),
                _SearchField(
                  controller: _queryController,
                  onSubmitted: _openMemory,
                ),
                const SizedBox(height: 12),
                _SelectedPlace(onTap: _openMemory),
                const SizedBox(height: 20),
                const CompareSlider(
                  pastYear: 1998,
                  currentYear: 2026,
                  height: 350,
                ),
                const SizedBox(height: 12),
                const _PageIndicator(),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 700) {
                      return const Column(
                        children: [
                          _NewsPanel(),
                          SizedBox(height: 16),
                          _CoursePanel(),
                        ],
                      );
                    }
                    return const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _NewsPanel()),
                        SizedBox(width: 16),
                        Expanded(child: _CoursePanel()),
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

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '옛길',
          style: AppTypography.largeTitle.copyWith(
            fontSize: 31,
            color: const Color(0xFF403329),
          ),
        ),
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold, width: 1.4),
          ),
          child: const Icon(Icons.person, color: Color(0xFF7B6A58), size: 24),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE0D9CF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onSubmitted(),
        decoration: InputDecoration(
          filled: false,
          hintText: '고향 주소, 학교, 살던 아파트',
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF766B5D),
            size: 27,
          ),
          suffixIcon: IconButton(
            onPressed: onSubmitted,
            icon: const Icon(Icons.arrow_forward, color: AppColors.goldDeep),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 17),
        ),
      ),
    );
  }
}

class _SelectedPlace extends StatelessWidget {
  const _SelectedPlace({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.location_on, color: Color(0xFF8C7350)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '전라남도 순천시 전포동',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right, color: Color(0xFF8C8378)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Dot(active: true),
        SizedBox(width: 7),
        _Dot(),
        SizedBox(width: 7),
        _Dot(),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({this.active = false});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.gold : const Color(0xFFD9D1C5),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.icon, required this.title, this.trailing});
  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF766347), size: 22),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: AppTypography.headline)),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

class _NewsPanel extends StatelessWidget {
  const _NewsPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          _PanelHeader(
            icon: Icons.newspaper_outlined,
            title: '그 시절 뉴스',
            trailing: TextButton(
              onPressed: () => context.push('/archive/suncheon-jeonpo'),
              child: const Text('더보기'),
            ),
          ),
          const SizedBox(height: 12),
          const _NewsRow(
            year: '1998.05.14',
            title: '순천 전포동, 도시 재생 사업 본격 추진',
            source: '순천신문',
          ),
          const _NewsRow(
            year: '1993.09.22',
            title: '전포초등학교 개교 기념식 열려',
            source: '전남매일',
          ),
          const _NewsRow(
            year: '1988.03.03',
            title: '전포동 새마을 시장 개장',
            source: '전남일보',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _NewsRow extends StatelessWidget {
  const _NewsRow({
    required this.year,
    required this.title,
    required this.source,
    this.last = false,
  });
  final String year;
  final String title;
  final String source;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                const SizedBox(height: 5),
                const CircleAvatar(radius: 4, backgroundColor: AppColors.gold),
                if (!last)
                  Expanded(
                    child: Container(width: 1, color: const Color(0xFFD8C8A9)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    year,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.goldDeep,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: AppTypography.subhead.copyWith(color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(source, style: AppTypography.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoursePanel extends StatelessWidget {
  const _CoursePanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          const _PanelHeader(
            icon: Icons.map_outlined,
            title: '현재 추천 코스',
            trailing: Row(
              children: [
                Icon(Icons.schedule, size: 15, color: AppColors.inkSecondary),
                SizedBox(width: 4),
                Text('약 3시간', style: AppTypography.caption),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 105,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: const LinearGradient(
                colors: [Color(0xFF52614E), Color(0xFFB69B72)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.landscape_outlined,
                color: Colors.white70,
                size: 50,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _CourseStop(
            number: 1,
            title: '전포 옛길 골목',
            detail: '옛 담장과 골목길 산책',
          ),
          const _CourseStop(number: 2, title: '전포성당', detail: '역사와 문화가 깃든 장소'),
          const _CourseStop(
            number: 3,
            title: '순천부읍성 전망대',
            detail: '순천 시내와 노을 조망',
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/course'),
              icon: const Icon(Icons.map_outlined),
              label: const Text('코스 보기'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseStop extends StatelessWidget {
  const _CourseStop({
    required this.number,
    required this.title,
    required this.detail,
  });
  final int number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.gold,
            child: Text(
              '$number',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.subhead.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(detail, style: AppTypography.caption),
              ],
            ),
          ),
          Text('${30 + number * 10}분', style: AppTypography.caption),
        ],
      ),
    );
  }
}
