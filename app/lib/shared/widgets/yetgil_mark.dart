import 'package:flutter/material.dart';

/// 옛길 로고 아이콘 — assets/logo/logo_icon.png(원본 로고에서 뱃지 부분만
/// 잘라낸 것)를 정사각형으로 보여준다.
class YetgilMark extends StatelessWidget {
  const YetgilMark({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset('assets/logo/logo_icon.png', fit: BoxFit.contain),
    );
  }
}

/// 로고에서 글자 부분만 뗀 워드마크(assets/logo/logo_wordmark.png) —
/// "옛길 게시판"처럼 아이콘 없이 로고 글자만 필요한 자리에 쓴다.
class YetgilWordmark extends StatelessWidget {
  const YetgilWordmark({super.key, this.fontSize = 18});

  /// 워드마크 이미지 원본 비율(가로 426 x 세로 216)에 맞춰 높이를 계산한다 —
  /// 기존에 폰트 크기로 지정해 쓰던 호출부를 그대로 쓸 수 있게 fontSize를
  /// "글자가 이 정도 높이로 보이면 좋겠다"는 기준값으로 재사용한다.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final height = fontSize * 1.3;
    return Image.asset(
      'assets/logo/logo_wordmark.png',
      height: height,
      fit: BoxFit.fitHeight,
      alignment: Alignment.centerLeft,
    );
  }
}
