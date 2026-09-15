import '../../core/constants/app_constants.dart';

/// 블로그 스타일 글쓰기의 본문 블록 하나 — 텍스트 또는 사진, 작성한 순서 그대로.
/// 옛 글(글쓰기 당시 블록 개념이 없던 글)은 항상 null이고, caption/photoUrls로 렌더링한다.
class ContentBlock {
  const ContentBlock({required this.type, this.text, this.imageUrl});

  final String type; // 'text' | 'image'
  final String? text;
  final String? imageUrl;

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    final imagePath = json['image_url'] as String?;
    return ContentBlock(
      type: json['type'] as String,
      text: json['text'] as String?,
      imageUrl: imagePath == null ? null : '${AppConstants.apiBaseUrl}$imagePath',
    );
  }
}

/// 커뮤니티 탭/장소 상세 화면에서 사용자가 직접 올린 게시물. 지역(region) +
/// 게시판(board) 조합이 하나의 "게시판" 단위 — 자유/추억/주민/관광정보 4개가
/// 지역구마다 별도로 운영된다.
class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorNickname,
    required this.region,
    required this.board,
    this.title,
    this.photoUrl,
    this.photoUrls = const [],
    this.locationId,
    this.caption,
    this.contentBlocks,
    this.memoryYear,
    this.revealAt,
    this.revealed = true,
    this.price,
    this.tradeStatus,
    required this.createdAt,
  });

  final int id;
  final int authorId;
  final String authorNickname;
  final String region;
  final String board;
  final String? title;
  final String? locationId;
  // 백엔드가 상대경로("/uploads/community/xxx.jpg")로 내려주므로 여기서 절대 URL로 만든다.
  // 자유/주민/관광정보 게시판은 사진 없이 글만 올릴 수 있어 null일 수 있다.
  final String? photoUrl;
  // 전체 사진(여러 장 지원) — 목록 카드는 photoUrl(대표 사진) 하나만 쓰고,
  // 상세 화면 갤러리에서 이 전체 목록을 보여준다.
  final List<String> photoUrls;
  final String? caption;
  // 블로그 스타일로 작성된 글만 채워진다. null/빈 배열이면 위 caption/photoUrls로 렌더링하는 옛 글.
  final List<ContentBlock>? contentBlocks;
  final int? memoryYear;
  // 타임캡슐 게시판 전용 — 이 시각이 지나야 열린다. 다른 게시판은 항상 null/true.
  final DateTime? revealAt;
  final bool revealed;
  // 주민 게시판(중고거래 스타일) 전용 — 다른 게시판은 항상 null.
  // price가 null이면 "나눔"으로 보여준다.
  final int? price;
  final String? tradeStatus;
  final DateTime createdAt;

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    final photoPath = json['photo_url'] as String?;
    final photoPaths = (json['photo_urls'] as List? ?? []).cast<String>();
    final revealAtRaw = json['reveal_at'] as String?;
    return CommunityPost(
      id: json['id'] as int,
      authorId: json['author_id'] as int,
      authorNickname: json['author_nickname'] as String,
      region: json['region'] as String,
      board: json['board'] as String,
      title: json['title'] as String?,
      locationId: json['location_id'] as String?,
      photoUrl: photoPath == null ? null : '${AppConstants.apiBaseUrl}$photoPath',
      photoUrls: photoPaths.map((path) => '${AppConstants.apiBaseUrl}$path').toList(),
      caption: json['caption'] as String?,
      contentBlocks: (json['content_blocks'] as List?)
          ?.map((b) => ContentBlock.fromJson(b as Map<String, dynamic>))
          .toList(),
      memoryYear: json['memory_year'] as int?,
      revealAt: revealAtRaw == null ? null : DateTime.parse(revealAtRaw),
      revealed: json['revealed'] as bool? ?? true,
      price: json['price'] as int?,
      tradeStatus: json['trade_status'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
