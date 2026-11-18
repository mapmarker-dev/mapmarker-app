import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/data/models/candidate.dart';
import 'package:mapmarker_app/features/trip_detail/candidate_draft.dart';

void main() {
  const udo = Candidate(
    id: 'udo',
    tripId: 'jeju',
    latitude: 33.5,
    longitude: 126.95,
    name: '우도',
    address: '제주 우도면',
  );

  test('limits the address to 200 letters', () {
    const ok = CandidateDraft(name: '우도');

    expect(ok.copyWith(address: 'a' * 200).isValid, isTrue);
    expect(ok.copyWith(address: 'a' * 201).isValid, isFalse);
  });

  test('edits the address with trimmed text but keeps the place', () {
    final edited = CandidateDraft.of(
      udo,
    ).copyWith(address: ' 제주시 우도면 우도해안길 1 ').applyTo(udo);

    expect(edited.address, '제주시 우도면 우도해안길 1');
    expect(edited.position, udo.position);
  });

  test('moves the place only when it was found again by address', () {
    final draft = CandidateDraft.of(
      udo,
    ).copyWith(relocatedTo: () => const LatLng(33.45, 126.56));

    expect(draft, isNot(CandidateDraft.of(udo)));
    expect(draft.applyTo(udo).position, const LatLng(33.45, 126.56));
  });

  test('a new candidate goes where the address field found it, if it did', () {
    const tapped = LatLng(33.51, 126.51);
    const found = LatLng(33.45, 126.56);
    const draft = CandidateDraft(name: '카페');

    expect(
      draft.toNewCandidate(id: 'n', tripId: 'jeju', position: tapped).position,
      tapped,
    );
    expect(
      draft
          .copyWith(relocatedTo: () => found)
          .toNewCandidate(id: 'n', tripId: 'jeju', position: tapped)
          .position,
      found,
    );
  });
}
