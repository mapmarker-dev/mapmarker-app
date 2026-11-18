import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/map/geo.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/saving.dart';
import '../../../data/addresses/address_api.dart';
import '../../../data/api/api_exception.dart';
import '../../../l10n/l10n.dart';

/// 주소 검색에서 고른 곳.
@immutable
class FoundPlace {
  const FoundPlace({required this.address, required this.position});

  /// 주소 칸에 넣을 글(도로명 + 상세 + 참고 항목).
  final String address;

  /// 건물 출입구 좌표.
  final LatLng position;
}

/// 주소 칸과 그 아래 주소 목록. 찾기 화면과 장소·후보 입력 화면의 주소 칸이 함께 쓴다.
///
/// 검색은 🔍·엔터를 누를 때만 한다(글자마다 부르면 행안부 호출이 많아진다).
/// 목록에서 고르면 좌표까지 받아 칸을 그 주소로 바꾸고 [onPicked]를 부른다. 고르지 않으면 칸의 글자만 바뀐다.
class AddressSearch extends ConsumerStatefulWidget {
  const AddressSearch({
    super.key,
    required this.controller,
    required this.label,
    required this.onPicked,
    this.enabled = true,
    this.autofocus = false,
    this.maxLength,
    this.guide,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<FoundPlace> onPicked;

  final bool enabled;
  final bool autofocus;
  final int? maxLength;

  /// 찾기 전에 목록 자리에 보일 안내. null이면 없다.
  final String? guide;

  @override
  ConsumerState<AddressSearch> createState() => _AddressSearchState();
}

class _AddressSearchState extends ConsumerState<AddressSearch> {
  /// 지금 보이는 결과. 찾기 전이거나 고른 뒤면 null이다.
  AddressSearchResult? _result;
  bool _searching = false;
  ApiFailure? _searchFailure;

  /// 좌표를 받는 줄. 받는 동안 다른 줄은 누를 수 없다.
  int? _loading;

  /// 좌표를 받지 못한 줄과 그 이유(null이면 위치 없음).
  final _rowFailures = <int, ApiFailure?>{};

  /// 늦게 온 검색 응답을 버리려고 검색마다 올린다.
  int _searchCount = 0;

  /// [x]로 지운 뒤 바로 다시 쓰게 칸에 커서를 둔다.
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// 칸과 결과를 비운다. 위치는 그대로다(글자만 고친 것과 같다).
  void _clear() {
    widget.controller.clear();
    _searchCount++; // 찾는 중이던 응답은 버린다.
    setState(() {
      _result = null;
      _searching = false;
      _searchFailure = null;
      _rowFailures.clear();
    });
    _focus.requestFocus();
  }

  Future<void> _search() async {
    final text = widget.controller.text.trim();
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
      // 받는 사이 화면을 닫았으면 버린다.
      if (!mounted) return;
      if (position == null) {
        setState(() => _rowFailures[index] = null);
        return;
      }
      final found = FoundPlace(
        address: address.fullAddress(result.detail),
        position: position,
      );
      widget.controller.text = found.address;
      setState(() => _result = null);
      widget.onPicked(found);
    } on ApiException catch (error) {
      if (mounted) setState(() => _rowFailures[index] = error.failure);
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = widget.enabled && _loading == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 글이 있을 때만 [x]를 돋보기 왼쪽에 둔다.
        ValueListenableBuilder(
          valueListenable: widget.controller,
          builder: (context, value, _) {
            final icons = [
              if (value.text.isNotEmpty)
                IconButton(
                  tooltip: l10n.addressClear,
                  icon: const Icon(Icons.close),
                  onPressed: enabled ? _clear : null,
                ),
              IconButton(
                tooltip: l10n.placeFinderSearch,
                icon: const Icon(Icons.search),
                onPressed: enabled ? _search : null,
              ),
            ];
            return TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: enabled,
              autofocus: widget.autofocus,
              maxLength: widget.maxLength,
              // 긴 주소도 잘리지 않게 3줄까지 감싸 보인다. 엔터는 줄바꿈이 아니라 찾기다.
              keyboardType: TextInputType.text,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: widget.label,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: icons,
                ),
              ),
            );
          },
        ),
        if (_searching) const LinearProgressIndicator(),
        ..._results(l10n),
      ],
    );
  }

  List<Widget> _results(AppLocalizations l10n) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final muted = textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    Widget message(String text, {TextStyle? style}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
      child: Text(text, style: style),
    );
    Widget boxed(String text) => _box([
      Padding(padding: const EdgeInsets.all(AppSpace.lg), child: Text(text)),
    ]);

    if (_searchFailure case final failure?) {
      return [boxed(l10n.searchFailureText(failure))];
    }
    final result = _result;
    if (result == null) {
      return [if (widget.guide case final guide?) message(guide, style: muted)];
    }
    if (result.addresses.isEmpty) return [boxed(l10n.placeFinderEmpty)];
    const divider = Divider(
      height: 1,
      indent: AppSpace.lg,
      endIndent: AppSpace.lg,
    );
    return [
      _box([
        // 더 있으면 맨 위에 검색어를 좁히라고 쓴다.
        if (result.hasMore) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg,
              vertical: AppSpace.sm,
            ),
            child: Text(l10n.placeFinderTooMany, style: muted),
          ),
          divider,
        ],
        for (final (index, address) in result.addresses.indexed) ...[
          if (index > 0) divider,
          _row(l10n, index, address, muted),
        ],
      ]),
    ];
  }

  /// 검색 결과를 묶는 상자. 여행 카드와 같은 흰 바탕·테두리·모서리라 입력 칸(연분홍)과 구분된다.
  Widget _box(List<Widget> children) => Container(
    key: const ValueKey('addressResults'),
    margin: const EdgeInsets.only(top: AppSpace.sm),
    padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      border: Border.all(color: context.appColors.cardBorder),
      borderRadius: AppRadius.card,
    ),
    // 줄을 누를 때 물결이 상자 안에 그려지게 한다.
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  Widget _row(
    AppLocalizations l10n,
    int index,
    AddressCandidate address,
    TextStyle? muted,
  ) {
    final building = address.buildingName;
    final failed = _rowFailures.containsKey(index);
    final failure = _rowFailures[index];
    final textTheme = Theme.of(context).textTheme;
    // 동선·후보 목록의 장소 줄과 같은 글자: 굵은 이름(건물명, 없으면 도로명), 작은 회색 주소.
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      enabled: _loading == null || _loading == index,
      titleTextStyle: textTheme.titleSmall,
      subtitleTextStyle: muted,
      title: Text(building ?? address.roadAddress),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (building != null) Text(address.roadAddress),
          Text(l10n.placeFinderJibun(address.jibunAddress), style: muted),
          if (failed)
            Text(
              failure == null
                  ? l10n.placeFinderNoPosition
                  : l10n.searchFailureText(failure),
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
  }
}
