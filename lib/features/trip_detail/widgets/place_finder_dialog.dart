import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import 'address_search.dart';

export 'address_search.dart' show FoundPlace;

/// 주소로 장소를 찾는 화면. 고르면 좌표까지 받아 [FoundPlace]로 닫고, 그냥 닫으면 null이다.
/// 동선 사이 ⊕, "장소 넣기", "후보 찾아 넣기"가 연다.
Future<FoundPlace?> showPlaceFinder(
  BuildContext context, {
  required String title,
}) => showDialog<FoundPlace>(
  context: context,
  useSafeArea: false,
  builder: (context) => PlaceFinderDialog(title: title),
);

class PlaceFinderDialog extends StatefulWidget {
  const PlaceFinderDialog({super.key, required this.title});

  final String title;

  @override
  State<PlaceFinderDialog> createState() => _PlaceFinderDialogState();
}

class _PlaceFinderDialogState extends State<PlaceFinderDialog> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final insets = MediaQuery.paddingOf(context);
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(widget.title),
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            insets.left + AppSpace.lg,
            AppSpace.md,
            insets.right + AppSpace.lg,
            insets.bottom + AppSpace.lg,
          ),
          children: [
            AddressSearch(
              controller: _query,
              label: l10n.placeFinderHint,
              autofocus: true,
              guide: l10n.placeFinderGuide,
              onPicked: (found) => Navigator.of(context).pop(found),
            ),
          ],
        ),
      ),
    );
  }
}
