import '../../core/utils/image_proxy.dart';
import 'tour_course.dart';

/// "식사 추가" 플로우의 식당 후보 — 백엔드가 실제로 검색한 결과만 온다
/// (Claude가 새로 만들어내지 않는다). 사용자가 하나를 고르면 이 객체를
/// 그대로 다시 백엔드에 실어 보내 코스에 삽입한다.
class RestaurantCandidate {
  const RestaurantCandidate({
    required this.restaurantId,
    required this.name,
    this.category = '',
    this.address = '',
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.photoAttributionName,
    this.photoAttributionUrl,
    this.detourM,
    this.reason,
  });

  final String restaurantId;
  final String name;
  final String category;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final String? photoAttributionName;
  final String? photoAttributionUrl;
  // 이 식당을 코스에 넣으면 기존 동선에서 얼마나 더 돌아가야 하는지(m).
  final int? detourM;
  // Claude가 순위를 매긴 이유(짧은 한 줄) — 랭킹 실패 시 null.
  final String? reason;

  /// 이미 코스에 들어가 있는 식사 정류지를 "선택된 후보"로 되돌린다 — 식사를
  /// 하나만 바꾸거나 지울 때, 건드리지 않는 다른 식사를 그대로 유지하려면
  /// 다시 삽입 요청에 실어 보내야 하는데 그때 이 변환이 필요하다.
  factory RestaurantCandidate.fromCourseStop(CourseStop stop) {
    return RestaurantCandidate(
      restaurantId: stop.name,
      name: stop.name,
      category: stop.category,
      address: stop.address,
      latitude: stop.latitude,
      longitude: stop.longitude,
      imageUrl: stop.imageUrl,
      photoAttributionName: stop.photoAttributionName,
      photoAttributionUrl: stop.photoAttributionUrl,
    );
  }

  factory RestaurantCandidate.fromJson(Map<String, dynamic> json) {
    final imagePath = json['image_url'] as String?;
    return RestaurantCandidate(
      restaurantId: json['restaurant_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      imageUrl: resolveStoredImageUrl(imagePath),
      photoAttributionName: json['photo_attribution_name'] as String?,
      photoAttributionUrl: json['photo_attribution_url'] as String?,
      detourM: json['detour_m'] as int?,
      reason: json['reason'] as String?,
    );
  }

  /// 후보 조회 응답을 그대로 다시 삽입 요청에 실어 보낸다 — 백엔드가 재검색하지
  /// 않고 이 값을 신뢰하므로, 여기서 받은 그대로(이미지 URL도 절대경로 그대로)
  /// 되돌려 보낸다.
  Map<String, dynamic> toJson() => {
        'restaurant_id': restaurantId,
        'name': name,
        'category': category,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'image_url': imageUrl,
        'photo_attribution_name': photoAttributionName,
        'photo_attribution_url': photoAttributionUrl,
        'detour_m': detourM,
        'reason': reason,
      };
}
