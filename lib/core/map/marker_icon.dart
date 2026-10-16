import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'map_provider.dart';

/// 마커 그림. 지도 구현이 이 위젯을 이미지로 바꿔 지도에 올린다.
///
/// 원의 가운데가 그림의 가운데라서, 마커의 기준점은 그림 가운데다.
class MarkerIcon extends StatelessWidget {
  const MarkerIcon(this.look, {super.key});

  /// 원(지름 [_circle])과, 원 오른쪽 위에 걸친 배지(지름 [_badge])가 들어가는 크기.
  static const size = Size.square(36);

  static const _circle = 28.0;
  static const _border = 2.0;
  static const _badge = 16.0;

  final MarkerLook look;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontSize: 13,
      fontWeight: AppFont.extraBold,
      color: look.foreground,
      height: 1,
    );
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: _circle,
            height: _circle,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: look.fill,
              shape: BoxShape.circle,
              border: Border.all(color: look.halo, width: _border),
            ),
            child: switch (look) {
              MarkerLook(:final label?) => Text(label, style: labelStyle),
              MarkerLook(:final icon?) => Icon(
                icon,
                size: 16,
                color: look.foreground,
              ),
              _ => null,
            },
          ),
          if (look.badge case final badge?)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: _badge,
                height: _badge,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: look.halo,
                  shape: BoxShape.circle,
                  border: Border.all(color: look.fill),
                ),
                child: Icon(badge, size: 11, color: look.foreground),
              ),
            ),
        ],
      ),
    );
  }
}
