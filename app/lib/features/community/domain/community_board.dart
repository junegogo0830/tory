import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 지역구마다 별도로 운영되는 5개 게시판. id는 백엔드 `board` 값과 그대로 맞춘다.
class CommunityBoard {
  const CommunityBoard({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.requiresPhoto,
    this.requiresRevealDate = false,
    this.isTradeBoard = false,
    this.isMapBoard = false,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final bool requiresPhoto;
  // 타임캡슐 게시판 전용 — 글쓰기 화면에서 봉인 해제 날짜를 반드시 받아야 한다.
  final bool requiresRevealDate;
  // 주민 게시판 전용 — 중고거래 스타일(가격/거래상태)로 글을 올린다.
  final bool isTradeBoard;
  // 관광정보 게시판 전용 — 실제 장소를 첨부하고, 지도로도 볼 수 있다.
  final bool isMapBoard;
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
    description: '동네 중고거래 · 나눔 게시판이에요',
    icon: Icons.home_work_outlined,
    color: AppColors.pastelMint,
    requiresPhoto: false,
    isTradeBoard: true,
  ),
  CommunityBoard(
    id: 'info',
    label: '관광 정보',
    description: '가볼 만한 곳을 장소와 함께 공유해요',
    icon: Icons.map_outlined,
    color: AppColors.pastelButter,
    requiresPhoto: false,
    isMapBoard: true,
  ),
  CommunityBoard(
    id: 'timecapsule',
    label: '타임캡슐 편지',
    description: '미래의 우리에게 편지를 남겨요',
    icon: Icons.mail_lock_outlined,
    color: AppColors.pastelRose,
    requiresPhoto: false,
    requiresRevealDate: true,
  ),
];

CommunityBoard communityBoardById(String id) => communityBoards.firstWhere(
  (board) => board.id == id,
  orElse: () => communityBoards.first,
);
