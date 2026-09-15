import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/notice.dart';

class NoticeDetailScreen extends StatelessWidget {
  const NoticeDetailScreen({super.key, required this.notice});

  final Notice notice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('공지사항')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: notice.badgeColor, borderRadius: BorderRadius.circular(14)),
                child: Icon(notice.icon, color: AppColors.accentDeep, size: 24),
              ),
              const SizedBox(height: 14),
              Text(notice.title, style: AppTypography.title.copyWith(fontSize: 21)),
              const SizedBox(height: 20),
              Text(notice.body.trim(), style: AppTypography.subhead.copyWith(height: 1.65)),
            ],
          ),
        ),
      ),
    );
  }
}
