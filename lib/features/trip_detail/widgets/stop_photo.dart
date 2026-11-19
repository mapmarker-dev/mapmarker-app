import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/photo.dart';
import '../../../data/photos/photo_images.dart';
import '../../../l10n/l10n.dart';

/// 장소 사진 한 장. [original]이면 원본(크게 볼 때), 아니면 썸네일을 받는다.
///
/// 받는 동안과 받지 못했을 때는 빈 자리에 사진 아이콘을 둔다.
/// 주소가 바뀌면(여행을 다시 받음) 새로 만든다. 받아 둔 이미지는 사진 ID로 기억해서 다시 받지 않고,
/// 받지 못했던 이미지는 새 주소로 다시 받는다([PhotoImage]).
class StopPhotoImage extends ConsumerWidget {
  const StopPhotoImage(
    this.photo, {
    super.key,
    this.original = false,
    this.fit = BoxFit.cover,
  });

  final Photo photo;
  final bool original;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(photoImagesProvider);
    return Image(
      key: ValueKey(original ? photo.url : photo.thumbnailUrl),
      image: original ? images.originalOf(photo) : images.thumbnailOf(photo),
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, synchronous) =>
          frame == null && !synchronous ? const PhotoPlaceholder() : child,
      errorBuilder: (context, error, stack) =>
          const PhotoPlaceholder(failed: true),
    );
  }
}

/// 사진이 들어갈 자리. 받는 중이면 사진 아이콘, 받지 못했으면 깨진 사진 아이콘이다.
class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({super.key, this.failed = false});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors.photoPlaceholder;
    return ColoredBox(
      color: colors.background,
      child: Center(
        child: Icon(
          failed ? Icons.broken_image_outlined : Icons.image_outlined,
          color: colors.foreground,
        ),
      ),
    );
  }
}

/// 둥근 사각형 썸네일. [onTap]이 있으면 누를 수 있다(크게 보기).
class StopPhotoThumbnail extends StatelessWidget {
  const StopPhotoThumbnail(
    this.photo, {
    super.key,
    required this.size,
    required this.label,
    this.onTap,
  });

  final Photo photo;
  final double size;

  /// 화면 읽기 프로그램이 읽는 이름. 예: "성산일출봉 사진".
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    image: true,
    button: onTap != null,
    child: ClipRRect(
      borderRadius: AppRadius.sm,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            StopPhotoImage(photo),
            if (onTap case final onTap?)
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap),
              ),
          ],
        ),
      ),
    ),
  );
}

/// 사진을 화면 가득 크게 본다. 두 손가락으로 늘려 본다. [image]는 `BoxFit.contain`으로 그린 사진이다.
Future<void> showPhotoViewer(
  BuildContext context, {
  required Widget image,
  required String label,
}) => showDialog<void>(
  context: context,
  useSafeArea: false,
  builder: (context) {
    final colors = context.appColors.photoViewer;
    final insets = MediaQuery.paddingOf(context);
    return Dialog.fullscreen(
      backgroundColor: colors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            label: label,
            image: true,
            child: InteractiveViewer(maxScale: 4, child: image),
          ),
          Positioned(
            top: insets.top + AppSpace.sm,
            left: insets.left + AppSpace.sm,
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              color: colors.foreground,
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  },
);

/// 저장된 사진을 크게 본다.
Future<void> showStopPhoto(
  BuildContext context, {
  required Photo photo,
  required String label,
}) => showPhotoViewer(
  context,
  image: StopPhotoImage(photo, original: true, fit: BoxFit.contain),
  label: label,
);

/// 확인 창에서 함께 사라질 사진: 작은 썸네일과 "사진". [image]는 썸네일을 채워 그린 것이다.
///
/// 예정 시각과 구간처럼 사라질 것을 구체적으로 보여 준다(어떤 사진을 잃는지 바로 안다).
class LostPhotoLine extends StatelessWidget {
  const LostPhotoLine({super.key, required this.image});

  static const _size = 40.0;

  final Widget image;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.md),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: AppRadius.sm,
          child: SizedBox.square(dimension: _size, child: image),
        ),
        const SizedBox(width: AppSpace.sm),
        Text(
          context.l10n.lostStopPhoto,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    ),
  );
}
