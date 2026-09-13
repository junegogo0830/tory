import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/utils/image_proxy.dart';
import 'photo_fallback.dart';

/// Shared photo loader for every screen.
///
/// On web, decode bytes rather than using cached_network_image's HtmlImage
/// backend. Flutter 3.47 can clear that backend's HTML element when an image is
/// disposed, leaving retained pictures black on return navigation:
/// https://github.com/flutter/flutter/issues/191800
/// NetworkImage keeps Flutter's memory cache and normal browser HTTP caching.
/// Native platforms retain cached_network_image's disk cache.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  final String imageUrl;
  final BoxFit fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;

  @override
  Widget build(BuildContext context) {
    final url = resolveImageUrl(imageUrl);
    if (url.isEmpty) {
      return errorWidget?.call(context, url, StateError('Empty image URL')) ??
          const PhotoFallback();
    }
    if (!kIsWeb) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        placeholder: placeholder ?? (_, _) => const PhotoFallback(),
        errorWidget: errorWidget ?? (_, _, _) => const PhotoFallback(),
      );
    }
    return Image.network(
      url,
      fit: fit,
      // Do not use HTML image codecs, even when CORS fails. TourAPI URLs go
      // through our same-origin-compatible image proxy above.
      webHtmlElementStrategy: WebHtmlElementStrategy.never,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return placeholder?.call(context, url) ?? const PhotoFallback();
      },
      errorBuilder: (context, error, stackTrace) =>
          errorWidget?.call(context, url, error) ?? const PhotoFallback(),
    );
  }
}
