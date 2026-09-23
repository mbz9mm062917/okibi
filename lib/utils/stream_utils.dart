import 'dart:async';

/// [source] から値が届くたびに、前の内側のストリームをやめて、
/// [project] が返す新しいストリームに切り替える(RxのswitchMap)。
///
/// 例:「フォロー中の人の一覧」が変わるたびに、「その人たちの投稿」を取り直す。
/// `asyncExpand` だと内側のストリームが終わるまで次の値を待ってしまい、
/// 終わらないFirestoreのストリームでは切り替わらないので、これが必要になる。
Stream<R> switchMap<T, R>(Stream<T> source, Stream<R> Function(T value) project) {
  late final StreamController<R> controller;
  StreamSubscription<T>? outer;
  StreamSubscription<R>? inner;
  var outerDone = false;

  controller = StreamController<R>(
    onListen: () {
      outer = source.listen(
        (value) {
          inner?.cancel();
          inner = project(value).listen(
            controller.add,
            onError: controller.addError,
            onDone: () {
              inner = null;
              if (outerDone) controller.close();
            },
          );
        },
        onError: controller.addError,
        onDone: () {
          outerDone = true;
          if (inner == null) controller.close();
        },
      );
    },
    onCancel: () async {
      await inner?.cancel();
      await outer?.cancel();
    },
  );

  return controller.stream;
}
