import 'package:flutter/material.dart';

/// 로그인 전 커뮤니티/프로필 화면에 함께 쓰는 인사 일러스트(assets/logo/login.png) —
/// 이웃 세 명이 모여 "추억을 함께 나눠요!" 말풍선과 함께 있는 모습.
class NeighborsGreetingIllustration extends StatelessWidget {
  const NeighborsGreetingIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset(
        'assets/logo/login.png',
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}
