import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:okibi/utils/stream_utils.dart';

void main() {
  group('switchMap', () {
    test('新しい値が来たら、前の内側のストリームはやめて最新のものに切り替わる', () async {
      final source = StreamController<int>();
      final inners = <int, StreamController<String>>{
        1: StreamController<String>(),
        2: StreamController<String>(),
      };
      final received = <String>[];
      final sub = switchMap(source.stream, (n) => inners[n]!.stream).listen(received.add);

      source.add(1);
      await pumpEventQueue();
      inners[1]!.add('1-a');
      await pumpEventQueue();

      source.add(2);
      await pumpEventQueue();
      inners[1]!.add('1-b'); // 切り替え後なので届かない
      inners[2]!.add('2-a');
      await pumpEventQueue();

      expect(received, ['1-a', '2-a']);
      await sub.cancel();
    });

    test('内側のストリームが終わらなくても、次の値で切り替わる(asyncExpandとの違い)', () async {
      final source = StreamController<int>();
      final received = <int>[];
      // 各内側は値を1つ出したあと、終わらずに開いたまま。
      final sub = switchMap<int, int>(
        source.stream,
        (n) => (StreamController<int>()..add(n * 10)).stream,
      ).listen(received.add);

      source.add(1);
      await pumpEventQueue();
      source.add(2);
      await pumpEventQueue();
      source.add(3);
      await pumpEventQueue();

      expect(received, [10, 20, 30]);
      await sub.cancel();
    });

    test('元のストリームと内側のストリームが両方終わったら、結果も閉じる', () async {
      final source = StreamController<int>();
      final inner = StreamController<String>();
      var done = false;
      final sub = switchMap(source.stream, (_) => inner.stream)
          .listen((_) {}, onDone: () => done = true);

      source.add(1);
      await pumpEventQueue();
      await source.close();
      await pumpEventQueue();
      expect(done, isFalse); // 内側がまだ続いている

      await inner.close();
      await pumpEventQueue();
      expect(done, isTrue);
      await sub.cancel();
    });

    test('内側のストリームのエラーは、そのまま流れてくる', () async {
      final source = StreamController<int>();
      final errors = <Object>[];
      final sub = switchMap<int, int>(
        source.stream,
        (_) => Stream<int>.error('失敗'),
      ).listen((_) {}, onError: errors.add);

      source.add(1);
      await pumpEventQueue();

      expect(errors, ['失敗']);
      await sub.cancel();
    });

    test('購読をやめると、内側の購読もやめる', () async {
      final source = StreamController<int>();
      final inner = StreamController<String>();
      final sub = switchMap(source.stream, (_) => inner.stream).listen((_) {});

      source.add(1);
      await pumpEventQueue();
      expect(inner.hasListener, isTrue);

      await sub.cancel();
      expect(inner.hasListener, isFalse);
      expect(source.hasListener, isFalse);
    });
  });
}
