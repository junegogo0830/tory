import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 지역구마다 별도로 운영되는 4개 게시판. id는 백엔드 `board` 값과 그대로 맞춘다.
class CommunityBoard {
  const CommunityBoard({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.requiresPhoto,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final bool requiresPhoto;
}

const List<CommunityBoard> communityBoards = [
  CommunityBoard(
    id: 'free',
    label: '자유 게시판',
    description: '동네 이야기를 자유롭게 나눠요',
    icon: Icons.chat_bubble_outline,
    color: AppColors.pastelSky,
    requiresPhoto: false,
  ),
  CommunityBoard(
    id: 'memory',
    label: '추억 게시판',
    description: '그 시절 사진과 추억을 남겨요',
    icon: Icons.photo_camera_back_outlined,
    color: AppColors.pastelPeach,
    requiresPhoto: true,
  ),
  CommunityBoard(
    id: 'resident',
    label: '주민 게시판',
    description: '동네 소식과 생활 정보를 나눠요',
    icon: Icons.home_work_outlined,
    color: AppColors.pastelMint,
    requiresPhoto: false,
  ),
  CommunityBoard(
    id: 'info',
    label: '관광 정보',
    description: '이 동네 가볼 만한 곳을 공유해요',
    icon: Icons.map_outlined,
    color: AppColors.pastelButter,
    requiresPhoto: false,
  ),
];

CommunityBoard communityBoardById(String id) =>
    communityBoards.firstWhere((board) => board.id == id, orElse: () => communityBoards.first);
