import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A centralized cached image widget that handles network image loading
/// with consistent caching, error handling, and loading states
class CachedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool showLoadingIndicator;
  final Color? placeholderColor;
  final IconData? errorIcon;
  final Duration? fadeInDuration;
  final Duration? fadeOutDuration;
  final Map<String, String>? httpHeaders;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.showLoadingIndicator = true,
    this.placeholderColor,
    this.errorIcon,
    this.fadeInDuration,
    this.fadeOutDuration,
    this.httpHeaders,
  });

  /// Factory constructor for anime cover images with consistent styling
  factory CachedImage.animeCover({
    required String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    return CachedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      placeholderColor: Colors.grey[300],
      errorIcon: Icons.movie,
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }

  /// Factory constructor for character images with consistent styling
  factory CachedImage.character({
    required String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    return CachedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      placeholderColor: Colors.grey[300],
      errorIcon: Icons.person,
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }

  /// Factory constructor for producer/studio images with consistent styling
  factory CachedImage.producer({
    required String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    return CachedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      placeholderColor: Colors.grey[300],
      errorIcon: Icons.business,
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }

  /// Factory constructor for user profile images with circular styling
  factory CachedImage.profile({
    required String? imageUrl,
    double? size,
    BoxFit fit = BoxFit.cover,
  }) {
    return CachedImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      fit: fit,
      borderRadius: BorderRadius.circular((size ?? 40) / 2),
      placeholderColor: Colors.grey[300],
      errorIcon: Icons.account_circle,
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Handle null or empty image URLs
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return _buildErrorWidget(context);
    }

    Widget imageWidget = CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      httpHeaders: httpHeaders,
      fadeInDuration: fadeInDuration ?? const Duration(milliseconds: 500),
      fadeOutDuration: fadeOutDuration ?? const Duration(milliseconds: 200),
      placeholder: placeholder != null 
          ? (context, url) => placeholder!
          : showLoadingIndicator 
              ? (context, url) => _buildLoadingWidget(context)
              : null,
      errorWidget: (context, url, error) => _buildErrorWidget(context),
      // Enable memory and disk caching
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      maxWidthDiskCache: 1000,
      maxHeightDiskCache: 1000,
    );

    // Apply border radius if specified
    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// Build the loading widget shown while image is downloading
  Widget _buildLoadingWidget(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: placeholderColor ?? Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
        ),
      ),
    );
  }

  /// Build the error widget shown when image fails to load
  Widget _buildErrorWidget(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: placeholderColor ?? Colors.grey[200],
      child: Icon(
        errorIcon ?? Icons.broken_image,
        color: Colors.grey[400],
        size: (width != null && height != null) 
            ? (width! < height! ? width! * 0.4 : height! * 0.4)
            : 24,
      ),
    );
  }
}

/// Extension to provide easy access to cached image widgets
extension CachedImageExtension on String? {
  /// Convert a string URL to a cached anime cover image
  Widget toAnimeCover({
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    return CachedImage.animeCover(
      imageUrl: this,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
    );
  }

  /// Convert a string URL to a cached character image
  Widget toCharacterImage({
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    return CachedImage.character(
      imageUrl: this,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
    );
  }

  /// Convert a string URL to a cached producer image
  Widget toProducerImage({
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    return CachedImage.producer(
      imageUrl: this,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
    );
  }

  /// Convert a string URL to a cached profile image
  Widget toProfileImage({
    double? size,
    BoxFit fit = BoxFit.cover,
  }) {
    return CachedImage.profile(
      imageUrl: this,
      size: size,
      fit: fit,
    );
  }
} 