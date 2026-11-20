import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/saving.dart';
import '../../../data/models/new_id.dart';
import '../../../data/models/photo.dart';
import '../../../data/photos/photo_images.dart';
import '../../../data/photos/photo_preparer.dart';
import '../../../data/photos/photo_source.dart';
import '../../../data/photos/photo_upload.dart';
import '../../../l10n/l10n.dart';
import 'photo_position_screen.dart';
import 'stop_photo.dart';

/// 장소 입력 화면의 사진 칸. 장소마다 1장이다.
///
/// 고르면 바로 원본으로 줄이고 위치 정보를 지운 뒤([PhotoPreparer]), "사진 위치" 화면에서 정사각형 자리를 골라
/// 썸네일을 만든다. 올리기는 입력 화면을 저장할 때 한다.
/// 준비하는 동안은 [onPreparing]으로 알려 저장을 막는다(고른 사진이 빠진 채 저장되지 않게).
///
/// - 사진이 없으면 낮은 회색 칸 [사진 넣기]
/// - 있으면(있던 사진이나 새로 고른 사진) 정사각형 썸네일과 그 옆 글자 버튼 [바꾸기] [위치 바꾸기] [지우기].
///   사진을 누르면 전체 사진을 크게 본다. 버튼은 사진을 가리지 않게 옆에 두고, 테두리가 없어
///   아래 동작 버튼(후보로 빼기, 장소 지우기)과 모양이 다르다.
class PlacePhotoField extends ConsumerStatefulWidget {
  const PlacePhotoField({
    super.key,
    required this.current,
    required this.picked,
    required this.removed,
    required this.enabled,
    required this.onPicked,
    required this.onRemoved,
    required this.onPreparing,
  });

  /// 저장돼 있는 사진. 새 장소면 null이다.
  final Photo? current;

  /// 새로 고른 사진. 저장하면 [current]를 바꾼다.
  final PreparedPhoto? picked;

  /// [current]를 지우기로 했다.
  final bool removed;

  final bool enabled;
  final ValueChanged<PreparedPhoto> onPicked;
  final VoidCallback onRemoved;
  final ValueChanged<bool> onPreparing;

  @override
  ConsumerState<PlacePhotoField> createState() => _PlacePhotoFieldState();
}

class _PlacePhotoFieldState extends ConsumerState<PlacePhotoField> {
  /// 사진이 있을 때 한 변. 지도 마커, 장소 줄과 같은 정사각형 썸네일을 보여 준다.
  /// 전체 사진은 눌러서 크게 본다.
  static const _previewSize = 160.0;

  bool _preparing = false;

  /// 사진 칸 아래 안내(읽지 못함, 받지 못함). 없으면 null.
  String? _error;

  /// 새로 고른 사진에서 마지막으로 고른 정사각형. [위치 바꾸기]가 여기서 시작한다.
  Rect? _pickedArea;

  /// [work] 동안 진행 표시를 띄우고 저장을 막는다.
  Future<T> _whilePreparing<T>(Future<T> Function() work) async {
    setState(() => _preparing = true);
    widget.onPreparing(true);
    try {
      return await work();
    } finally {
      if (mounted) {
        setState(() => _preparing = false);
        widget.onPreparing(false);
      }
    }
  }

  /// 사진을 골라 원본으로 줄이고, 위치를 고르게 한다.
  Future<void> _pick() async {
    setState(() => _error = null);
    final preparer = ref.read(photoPreparerProvider);
    try {
      final bytes = await ref.read(photoSourceProvider).pick();
      if (bytes == null || !mounted) return;
      final original = await _whilePreparing(() => preparer.shrink(bytes));
      if (mounted) await _position(original);
    } catch (error) {
      // 고르기(권한, 파일)나 줄이기(형식, 깨진 파일)의 실패. 다른 사진을 고르면 된다.
      debugPrint('사진을 준비하지 못했습니다: $error');
      if (mounted) setState(() => _error = context.l10n.placePhotoReadFailed);
    }
  }

  /// 보이는 사진의 정사각형 위치를 다시 고른다. 저장된 사진이면 원본을 받아 새 사진으로 올린다.
  Future<void> _reposition() async {
    setState(() => _error = null);
    final picked = widget.picked;
    if (picked != null) {
      await _position(
        SizedJpeg(
          picked.original,
          width: picked.originalWidth,
          height: picked.originalHeight,
        ),
        initial: _pickedArea,
      );
      return;
    }
    final current = widget.current;
    if (current == null) return;
    final SizedJpeg original;
    try {
      original = await _whilePreparing(() async {
        final bytes = await ref.read(photoImagesProvider).fetch(current.url);
        return ref.read(photoPreparerProvider).measure(bytes);
      });
    } catch (error) {
      debugPrint('사진을 받지 못했습니다: $error');
      if (mounted) setState(() => _error = context.l10n.placePhotoFetchFailed);
      return;
    }
    if (mounted) await _position(original);
  }

  /// "사진 위치" 화면에서 고른 정사각형으로 썸네일을 만들어 넘긴다. 닫으면 아무것도 바꾸지 않는다.
  Future<void> _position(SizedJpeg original, {Rect? initial}) async {
    final area = await showPhotoPosition(
      context,
      image: MemoryImage(original.bytes),
      size: Size(original.width.toDouble(), original.height.toDouble()),
      initial: initial,
    );
    if (area == null || !mounted) return;
    try {
      final thumbnail = await _whilePreparing(
        () => ref.read(photoPreparerProvider).squareThumbnail(original, area),
      );
      if (!mounted) return;
      _pickedArea = area;
      widget.onPicked(
        PreparedPhoto(
          // 썸네일이 바뀌면 서버에는 새 사진이다(저장된 사진의 위치를 바꿀 때도).
          id: newId(),
          original: original.bytes,
          originalWidth: original.width,
          originalHeight: original.height,
          thumbnail: thumbnail,
        ),
      );
    } catch (error) {
      debugPrint('썸네일을 만들지 못했습니다: $error');
      if (mounted) setState(() => _error = context.l10n.placePhotoReadFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final picked = widget.picked;
    final current = widget.removed ? null : widget.current;
    final hasPhoto = picked != null || current != null;
    final enabled = widget.enabled && !_preparing;

    final placeholder = context.appColors.photoPlaceholder;
    final Widget body;
    if (_preparing) {
      body = _Tile(
        color: placeholder.background,
        child: SavingIndicator(label: l10n.placePhotoPreparing),
      );
    } else if (!hasPhoto) {
      // 사진이 없을 때는 낮은 칸 하나라 자리를 적게 차지하고, 아래 동작 버튼(테두리 버튼)과 모양이 다르다.
      body = _Tile(
        color: placeholder.background,
        onTap: enabled ? _pick : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: placeholder.foreground,
            ),
            const SizedBox(width: AppSpace.sm),
            Text(
              l10n.placePhotoAdd,
              style: textTheme.labelLarge?.copyWith(
                color: placeholder.foreground,
              ),
            ),
          ],
        ),
      );
    } else {
      final label = l10n.placePhotoLabel;
      final Widget image = switch (picked) {
        final picked? => Image.memory(
          picked.thumbnail,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
        null => StopPhotoImage(current!),
      };
      // 버튼은 사진 옆에 둔다(작은 사진 위에 올리면 사진을 가린다).
      // 테두리 없는 글자 버튼이라 아래 동작 버튼(후보로 빼기, 장소 지우기)과 모양이 다르다.
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppRadius.md,
            child: SizedBox.square(
              dimension: _previewSize,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image,
                  Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: () => showPhotoViewer(
                        context,
                        label: label,
                        image: switch (picked) {
                          final picked? => Image.memory(
                            picked.original,
                            fit: BoxFit.contain,
                          ),
                          null => StopPhotoImage(
                            current!,
                            original: true,
                            fit: BoxFit.contain,
                          ),
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: enabled ? _pick : null,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(l10n.placePhotoChange),
                ),
                TextButton.icon(
                  onPressed: enabled ? _reposition : null,
                  icon: const Icon(Icons.crop),
                  label: Text(l10n.placePhotoReposition),
                ),
                TextButton.icon(
                  onPressed: enabled ? widget.onRemoved : null,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.placePhotoRemove),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.placePhotoLabel,
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpace.sm),
        body,
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: Text(
              error,
              style: textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ),
      ],
    );
  }
}

/// 사진 칸의 둥근 바탕(사진이 없을 때, 준비 중일 때).
class _Tile extends StatelessWidget {
  const _Tile({required this.color, required this.child, this.onTap});

  static const _height = 56.0;

  final Color color;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: AppRadius.md,
    child: InkWell(
      onTap: onTap,
      borderRadius: AppRadius.md,
      child: SizedBox(
        height: _height,
        width: double.infinity,
        child: Center(child: child),
      ),
    ),
  );
}
