import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/saving.dart';
import '../../../data/models/new_id.dart';
import '../../../data/models/photo.dart';
import '../../../data/photos/photo_preparer.dart';
import '../../../data/photos/photo_source.dart';
import '../../../data/photos/photo_upload.dart';
import '../../../l10n/l10n.dart';
import 'stop_photo.dart';

/// 장소 입력 화면의 사진 칸. 장소마다 1장이다.
///
/// 고르면 바로 줄이고 위치 정보를 지워 둔다([PhotoPreparer]). 올리기는 입력 화면을 저장할 때 한다.
/// 줄이는 동안은 [onPreparing]으로 알려 저장을 막는다(고른 사진이 빠진 채 저장되지 않게).
///
/// - 사진이 없으면 낮은 회색 칸 [사진 넣기]
/// - 있으면(있던 사진이나 새로 고른 사진) 정사각형 사진과, 그 위 오른쪽의 작은 원 버튼 [바꾸기] [지우기].
///   사진을 누르면 크게 본다. 버튼을 사진 위에 둬서 아래 동작 버튼(후보로 빼기, 장소 지우기)과 섞이지 않는다.
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
  /// 사진이 있을 때 한 변. 지도 마커와 장소 줄처럼 가운데를 정사각형으로 잘라 보여 준다
  /// (같은 사진이 화면마다 다르게 잘려 보이지 않게). 전체 사진은 눌러서 크게 본다.
  static const _previewSize = 160.0;

  /// 고른 원본을 미리 볼 때 풀어 둘 폭(px). 1920px 그대로 풀면 메모리를 많이 쓴다.
  static const _decodeWidth = 600;

  bool _preparing = false;
  bool _failed = false;

  Future<void> _pick() async {
    setState(() => _failed = false);
    final source = ref.read(photoSourceProvider);
    final preparer = ref.read(photoPreparerProvider);
    try {
      final bytes = await source.pick();
      if (bytes == null || !mounted) return;
      setState(() => _preparing = true);
      widget.onPreparing(true);
      final photo = await preparer.prepare(bytes, id: newId());
      if (mounted) widget.onPicked(photo);
    } catch (error) {
      // 고르기(권한, 파일)나 줄이기(형식, 깨진 파일)의 실패. 다른 사진을 고르면 된다.
      debugPrint('사진을 준비하지 못했습니다: $error');
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted && _preparing) {
        setState(() => _preparing = false);
        widget.onPreparing(false);
      }
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
      // 썸네일(400px)은 160dp를 고해상도 화면에 그리기에 흐려서 원본을 쓴다.
      final Widget image = switch (picked) {
        final picked? => Image.memory(
          picked.original,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: _decodeWidth,
        ),
        null => StopPhotoImage(current!, original: true),
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
        if (_failed)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: Text(
              l10n.placePhotoReadFailed,
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
