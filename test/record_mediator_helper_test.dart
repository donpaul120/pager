import 'package:flutter_test/flutter_test.dart';
import 'package:pagerx/pagerx.dart';

PagerRecordMediator<int, String> mediatorReturning(PagerRecordData<String> data,
    {List<String>? store}) {
  return pagerRecordMediator<int, String>(
    fetch: (page) async => data,
    save: (records) async => store?.addAll(records),
    clear: (records) async => store?.clear(),
  );
}

PagingState<int, String> refreshState() =>
    PagingState<int, String>(null, const PagingConfig.fromDefault());

void main() {
  group('pagerRecordMediator totalItems', () {
    test('forwards PagerRecordData.totalItems to MediatorResult.success',
        () async {
      final mediator = mediatorReturning(
          const PagerRecordData(records: ['a', 'b'], totalItems: 42));

      final result = await mediator.load(LoadType.REFRESH, refreshState());

      expect(result, isA<MediatorSuccess>());
      expect((result as MediatorSuccess).totalItems, 42);
    });

    test('leaves totalItems unset when PagerRecordData reports 0', () async {
      final mediator =
          mediatorReturning(const PagerRecordData(records: ['a', 'b']));

      final result = await mediator.load(LoadType.REFRESH, refreshState());

      expect((result as MediatorSuccess).totalItems, isNull);
    });

    test('controller.totalItems reflects the server total', () async {
      final store = <String>[];
      final source = PagingSource<int, String>(
        localSource: (params) async* {
          yield Page(List.of(store), null, null);
        },
        remoteMediator: mediatorReturning(
            const PagerRecordData(records: ['a', 'b', 'c'], totalItems: 500),
            store: store),
      );
      final controller = PagerController<int, String>(source: source);
      controller.initialize();
      await pumpEventQueue();

      expect(controller.totalItems, 500);

      controller.dispose();
    });
  });
}
