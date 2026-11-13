import 'stop_draft.dart';

/// 지도 앱에서 복사해 붙여 넣은 글을 주소 검색어와 이름 후보로 나눈다.
///
/// "주소 복사"는 주소 한 줄이지만, [공유]로 받은 글은 "이름 / 주소 / 링크"처럼 여러 줄이다.
/// 링크와 "[네이버 지도]" 같은 꼬리표 줄은 버리고, 주소처럼 보이는 줄을 검색어로, 남은 첫 줄을 이름 후보로 둔다.
/// 주소처럼 보이는 줄이 없으면 첫 줄이 검색어다(건물명을 붙여 넣었을 수 있다).
/// 상세 주소("1,2층") 떼기와 검색어 다듬기는 서버가 한다.
({String query, String? nameHint}) parsePastedPlace(String text) {
  final lines = [
    for (final line in text.split(RegExp(r'\r?\n')))
      if (line.trim() case final trimmed
          when trimmed.isNotEmpty && !_isLink(trimmed) && !_isTag(trimmed))
        trimmed,
  ];
  if (lines.isEmpty) return (query: '', nameHint: null);
  if (lines.length == 1) return (query: lines.single, nameHint: null);

  final address = lines.where(_looksLikeAddress).firstOrNull;
  if (address == null) return (query: lines.first, nameHint: null);
  final name = lines.where((line) => !_looksLikeAddress(line)).firstOrNull;
  return (
    query: address,
    nameHint: name != null && name.length <= StopDraft.nameMaxLength
        ? name
        : null,
  );
}

/// 주소처럼 보이는 줄. 서버의 검색어 다듬기(address-query.ts)와 같은 도로명·지번 모양이거나 시·도로 시작한다.
bool _looksLikeAddress(String line) =>
    _road.hasMatch(line) || _jibun.hasMatch(line) || _province.hasMatch(line);

final _road = RegExp(r'\S(?:로|길)\s*\d+(?:-\d+)?(?=$|[\s,])');
final _jibun = RegExp(r'\S(?:동|리|가)\s+(?:산\s*)?\d+(?:-\d+)?(?=$|[\s,])');
final _province = RegExp(
  r'^(?:대한민국\s+)?(?:서울|부산|대구|인천|광주|대전|울산|세종|경기|강원|충북|충남|충청|전북|전남|전라|경북|경남|경상|제주)',
);

bool _isLink(String line) =>
    line.contains('://') || RegExp(r'^[\w-]+(?:\.[\w-]+)+/\S*$').hasMatch(line);

bool _isTag(String line) => RegExp(r'^\[[^\]]*\]$').hasMatch(line);
