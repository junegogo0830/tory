import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// 회원가입 화면에서 약관 항목을 눌렀을 때 전문을 보여주는 화면.
class TermsDetailScreen extends StatelessWidget {
  const TermsDetailScreen({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(body, style: AppTypography.subhead.copyWith(height: 1.6)),
        ),
      ),
    );
  }
}
