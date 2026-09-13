import 'package:yetgil_app/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/my_memory.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/photo_fallback.dart';
import '../data/profile_providers.dart';

/// 프로필 "사진으로 남긴 추억" — 내가 쓴 글 중 사진이 있는 것만 모아 보여준다.
class MyMemoriesScreen extends ConsumerWidget {
  const MyMemoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoriesAsync = ref.watch(myMemoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('사진으로 남긴 추억')),
      body: SafeArea(
        child: memoriesAsync.when(
          data: (memories) {
            if (memories.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: EmptyState(
                    icon: Icons.camera_alt_outlined,
                    title: '아직 남긴 추억이 없어요',
                    message: '장소 정보 화면의 "추억 등록"에서 사진을 남겨보세요.',
                  ),
                ),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemCount: memories.length,
              itemBuilder: (context, index) => _MemoryTile(memory: memories[index]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          error: (_, _) => Center(child: Text('불러오지 못했어요', style: AppTypography.subhead)),
        ),
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({required this.memory});

  final MyMemory memory;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: () => context.push('/post/${memory.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: AppNetworkImage(
                  imageUrl: memory.photoUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const PhotoFallback(),
                  errorWidget: (_, _, _) => const PhotoFallback(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memory.memoryYear != null ? '${memory.memoryYear}년' : memory.region,
                      style: AppTypography.caption.copyWith(color: AppColors.accentDeep),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      memory.title ?? memory.caption ?? '그 시절의 추억',
                      style: AppTypography.footnote,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
