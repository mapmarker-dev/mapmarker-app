import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/map/geo.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/saving.dart';
import '../../../data/addresses/address_api.dart';
import '../../../data/api/api_exception.dart';
import '../../../l10n/l10n.dart';
import '../pasted_place.dart';

/// 찾기 화면에서 고른 곳.
@immutable
class FoundPlace {
  const FoundPlace({
    required this.address,
    required this.position,
    this.nameHint,
  });

  /// 주소 칸에 넣을 글(도로명 + 상세 + 참고 항목).
  final String address;

  /// 건물 출입구 좌표.
  final LatLng position;

  /// 붙여 넣은 글에 있던 이름 줄. 없으면 null이다(건물명은 가게 이름과 달라 넣지 않는다).
  final String? nameHint;
}

/// 주소로 장소를 찾는 화면. 고르면 좌표까지 받아 [FoundPlace]로 닫고, 그냥 닫으면 null이다.
///
/// 검색은 엔터·찾기 버튼·[붙여넣기] 때만 한다(글자마다 부르면 행안부 호출이 많아진다).
Future<FoundPlace?> showPlaceFinder(
  BuildContext context, {
  required String title,
}) => showDialog<FoundPlace>(
  context: context,
  useSafeArea: false,
  builder: (context) => PlaceFinderDialog(title: title),
);

class PlaceFinderDialog extends ConsumerStatefulWidget {
  const PlaceFinderDialog({super.key, required this.title});

  final String title;

  @override
  ConsumerState<PlaceFinderDialog> createState() => _PlaceFinderDialogState();
}

class _PlaceFinderDialogState extends ConsumerState<PlaceFinderDialog> {
  final _query = TextEditingController();

  /// 붙여 넣은 글의 이름 줄. 직접 고쳐 찾으면 버린다.
  String? _nameHint;

  /// 지금 화면의 결과. 찾기 전이면 null이다.
  AddressSearchResult? _result;
  bool _searching = false;
  ApiFailure? _searchFailure;

  /// 좌표를 받는 줄. 받는 동안 다른 줄은 누를 수 없다.
  int? _loading;

  /// 좌표를 받지 못한 줄과 그 이유(null이면 위치 없음).
  final _rowFailures = <int, ApiFailure?>{};

  /// 늦게 온 응답을 버리려고 검색마다 올린다.
  int _searchCount = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || !mounted) return;
    final parsed = parsePastedPlace(text);
    _query.text = parsed.query;
    _nameHint = parsed.nameHint;
    await _search();
  }

  Future<void> _search() async {
    final text = _query.text.trim();
    if (text.isEmpty || _loading != null) return;
    final count = ++_searchCount;
    setState(() {
      _searching = true;
      _searchFailure = null;
      _rowFailures.clear();
    });
    try {
      final result = await ref.read(addressApiProvider).search(text);
      if (!mounted || count != _searchCount) return;
      setState(() => _result = result);
    } on ApiException catch (error) {
      if (!mounted || count != _searchCount) return;
      setState(() {
        _result = null;
        _searchFailure = error.failure;
      });
    } finally {
      if (mounted && count == _searchCount) setState(() => _searching = false);
    }
  }

  Future<void> _choose(int index) async {
    final result = _result;
    if (result == null || _loading != null || _searching) return;
    final address = result.addresses[index];
    setState(() {
      _loading = index;
      _rowFailures.remove(index);
    });
    try {
      final position = await ref
          .read(addressApiProvider)
          .coordinates(address.ref);
      // 받는 사이 닫았으면 버린다.
      if (!mounted) return;
      if (position == null) {
        setState(() => _rowFailures[index] = null);
        return;
      }
      Navigator.of(context).pop(
        FoundPlace(
          address: address.fullAddress(result.detail),
          position: position,
          nameHint: _nameHint,
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _rowFailures[index] = error.failure);
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final insets = MediaQuery.paddingOf(context);
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: material.closeButtonTooltip,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(widget.title),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                insets.left + AppSpace.lg,
                AppSpace.md,
                insets.right + AppSpace.lg,
                AppSpace.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _query,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: (_) => _nameHint = null,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        labelText: l10n.placeFinderHint,
                        suffixIcon: IconButton(
                          tooltip: l10n.placeFinderSearch,
                          icon: const Icon(Icons.search),
                          onPressed: _search,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  OutlinedButton.icon(
                    onPressed: _paste,
                    icon: const Icon(Icons.content_paste),
                    label: Text(l10n.placeFinderPaste),
                  ),
                ],
              ),
            ),
            if (_searching) const LinearProgressIndicator(),
            Expanded(child: _body(l10n, muted, insets)),
          ],
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l10n, TextStyle? muted, EdgeInsets insets) {
    final padding = EdgeInsets.fromLTRB(
      insets.left + AppSpace.lg,
      AppSpace.md,
      insets.right + AppSpace.lg,
      insets.bottom + AppSpace.lg,
    );
    final failure = _searchFailure;
    if (failure != null) {
      return Padding(
        padding: padding,
        child: Text(l10n.searchFailureText(failure)),
      );
    }
    final result = _result;
    if (result == null) {
      return Padding(
        padding: padding,
        child: Text(l10n.placeFinderGuide, style: muted),
      );
    }
    if (result.addresses.isEmpty) {
      return Padding(padding: padding, child: Text(l10n.placeFinderEmpty));
    }
    return ListView.builder(
      padding: EdgeInsets.only(bottom: insets.bottom + AppSpace.lg),
      itemCount: result.addresses.length,
      itemBuilder: (context, index) {
        final address = result.addresses[index];
        final building = address.buildingName;
        final rowFailure = _rowFailures.containsKey(index)
            ? (_rowFailures[index] == null
                  ? l10n.placeFinderNoPosition
                  : l10n.searchFailureText(_rowFailures[index]!))
            : null;
        return ListTile(
          contentPadding: EdgeInsets.only(
            left: insets.left + AppSpace.lg,
            right: insets.right + AppSpace.lg,
          ),
          enabled: _loading == null || _loading == index,
          title: Text(building ?? address.roadAddress),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (building != null) Text(address.roadAddress),
              Text(l10n.placeFinderJibun(address.jibunAddress), style: muted),
              if (rowFailure != null)
                Text(
                  rowFailure,
                  style: muted?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
            ],
          ),
          trailing: _loading == index
              ? SavingIndicator(label: l10n.placeFinderLoading, padded: false)
              : null,
          onTap: () => _choose(index),
        );
      },
    );
  }
}
