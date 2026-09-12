/// 홈 화면 애니메이션/인사말에 쓰는 현재 날씨.
class WeatherInfo {
  const WeatherInfo({
    required this.condition,
    required this.temperature,
    required this.description,
    required this.isDaytime,
  });

  // clear_day | clear_night | cloudy | overcast | rain | snow
  final String condition;
  final double temperature;
  final String description;
  final bool isDaytime;

  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    return WeatherInfo(
      condition: json['condition'] as String,
      temperature: (json['temperature'] as num).toDouble(),
      description: json['description'] as String,
      isDaytime: json['is_daytime'] as bool,
    );
  }
}
