import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
              children: const [
                _ProfileHeader(),
                SizedBox(height: 22),
                _MemberCard(),
                SizedBox(height: 28),
                _SavedPlaces(),
                SizedBox(height: 22),
                _MenuCard(),
                SizedBox(height: 18),
                _FamilyBanner(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('프로필', style: AppTypography.largeTitle.copyWith(fontSize: 34))),
        IconButton(onPressed: () {}, icon: const Icon(Icons.settings_outlined, size: 31)),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EBD9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8D7B8)),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 78,
                height: 78,
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: ClipOval(child: Image.asset('assets/images/alley-current.png', fit: BoxFit.cover)),
              ),
              const SizedBox(width: 17),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('김옛길', style: AppTypography.title.copyWith(fontSize: 24)),
                    const SizedBox(height: 5),
                    Text('나의 추억 여행을 기록하고 있어요', style: AppTypography.subhead),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                style: IconButton.styleFrom(backgroundColor: Colors.white),
                icon: const Icon(Icons.edit_outlined, color: AppColors.goldDeep),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),
          const Row(
            children: [
              Expanded(child: _Stat(label: '저장한 골목', value: '12')),
              _VerticalLine(),
              Expanded(child: _Stat(label: '완주한 코스', value: '4')),
              _VerticalLine(),
              Expanded(child: _Stat(label: '추억 사진', value: '8')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppTypography.subhead.copyWith(color: AppColors.ink)),
        const SizedBox(height: 6),
        Text(value, style: AppTypography.largeTitle.copyWith(fontSize: 30)),
      ],
    );
  }
}

class _VerticalLine extends StatelessWidget {
  const _VerticalLine();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 55, color: const Color(0xFFD4C09D));
}

class _SavedPlaces extends StatelessWidget {
  const _SavedPlaces();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('나의 옛길', style: AppTypography.title.copyWith(fontSize: 25))),
            TextButton(onPressed: () {}, child: const Text('전체 보기 〉')),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Expanded(
              child: _SavedPlaceCard(
                image: 'assets/images/alley-current.png',
                title: '전포동 옛길 골목',
                region: '전라남도 순천시 전포동',
              ),
            ),
            SizedBox(width: 13),
            Expanded(
              child: _SavedPlaceCard(
                image: 'assets/images/suncheon-bay.png',
                title: '수성동 언덕길',
                region: '전라남도 순천시 수성동',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SavedPlaceCard extends StatelessWidget {
  const _SavedPlaceCard({required this.image, required this.title, required this.region});
  final String image;
  final String title;
  final String region;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _whiteCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(aspectRatio: 4 / 3, child: Image.asset(image, fit: BoxFit.cover)),
              const Positioned(
                right: 10,
                top: 10,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.gold,
                  child: Icon(Icons.bookmark, color: Colors.white, size: 19),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.headline),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 15, color: AppColors.inkSecondary),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(region, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: _whiteCard,
      child: const Column(
        children: [
          _MenuRow(icon: Icons.bookmark_border, label: '저장한 골목'),
          Divider(),
          _MenuRow(icon: Icons.map_outlined, label: '내가 만든 코스'),
          Divider(),
          _MenuRow(icon: Icons.camera_alt_outlined, label: '사진으로 남긴 추억'),
          Divider(),
          _MenuRow(icon: Icons.notifications_none, label: '알림 설정'),
          Divider(),
          _MenuRow(icon: Icons.info_outline, label: '옛길 소개'),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF8C7350), size: 25),
            const SizedBox(width: 15),
            Expanded(child: Text(label, style: AppTypography.body)),
            const Icon(Icons.chevron_right, color: AppColors.inkSecondary),
          ],
        ),
      ),
    );
  }
}

class _FamilyBanner extends StatelessWidget {
  const _FamilyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFF8E8C4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9B86B)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundColor: Color(0xFFFFF4DA),
            child: Icon(Icons.group_outlined, color: AppColors.goldDeep, size: 29),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('가족과 추억을 공유해보세요', style: AppTypography.headline),
                const SizedBox(height: 3),
                Text('함께한 추억 여행을 더 특별하게 간직할 수 있어요.', style: AppTypography.footnote),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.goldDeep),
        ],
      ),
    );
  }
}

const _whiteCard = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(19)),
  boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 7))],
);
