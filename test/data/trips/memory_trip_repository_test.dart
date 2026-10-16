import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/data/trips/memory_trip_repository.dart';

Trip _trip(String id, {String title = '부산 2박 3일 봄 여행'}) {
  final placeholder = DateTime.utc(2000);
  return Trip(
    id: id,
    title: title,
    region: '부산',
    nights: 2,
    season: Season.spring,
    createdAt: placeholder,
    updatedAt: placeholder,
  );
}

void main() {
  late DateTime now;
  late MemoryTripRepository repository;

  setUp(() {
    now = DateTime.utc(2026, 10, 15, 9);
    repository = MemoryTripRepository(clock: () => now);
  });

  tearDown(() => repository.dispose());

  test('stamps created and updated times when creating', () async {
    final saved = await repository.createTrip(_trip('a'));

    expect(saved.createdAt, now);
    expect(saved.updatedAt, now);
  });

  test('refuses to create the same trip twice', () async {
    await repository.createTrip(_trip('a'));

    expect(repository.createTrip(_trip('a')), throwsStateError);
  });

  test('lists the most recently changed trip first', () async {
    await repository.createTrip(_trip('a'));
    now = now.add(const Duration(minutes: 1));
    await repository.createTrip(_trip('b'));

    expect((await repository.watchTrips().first).map((t) => t.id), ['b', 'a']);

    now = now.add(const Duration(minutes: 1));
    final a = (await repository.watchTrip('a').first)!;
    await repository.updateTrip(a.copyWith(title: '새 제목'));

    expect((await repository.watchTrips().first).map((t) => t.id), ['a', 'b']);
  });

  test('keeps the created time when updating', () async {
    final created = await repository.createTrip(_trip('a'));
    now = now.add(const Duration(hours: 1));

    final updated = await repository.updateTrip(
      created.copyWith(createdAt: DateTime.utc(1999)),
    );

    expect(updated.createdAt, created.createdAt);
    expect(updated.updatedAt, now);
  });

  test('refuses to update a trip that does not exist', () {
    expect(repository.updateTrip(_trip('missing')), throwsStateError);
  });

  test('emits the trip list again after each change', () async {
    final lists = repository.watchTrips().map((trips) => trips.length);
    final expectation = expectLater(lists, emitsInOrder([0, 1, 2]));

    await repository.createTrip(_trip('a'));
    await repository.createTrip(_trip('b'));
    await expectation;
  });

  test('emits null for a trip that does not exist', () async {
    expect(await repository.watchTrip('missing').first, isNull);
  });

  test('emits a trip again after it changes', () async {
    await repository.createTrip(_trip('a'));
    final titles = repository.watchTrip('a').map((trip) => trip?.title);
    final expectation = expectLater(
      titles,
      emitsInOrder(['부산 2박 3일 봄 여행', '새 제목']),
    );

    final a = (await repository.watchTrip('a').first)!;
    await repository.updateTrip(a.copyWith(title: '새 제목'));
    await expectation;
  });

  test('starts with the seed trips', () async {
    final seeded = MemoryTripRepository(seed: [_trip('a'), _trip('b')]);
    addTearDown(seeded.dispose);

    expect(await seeded.watchTrips().first, hasLength(2));
  });
}
