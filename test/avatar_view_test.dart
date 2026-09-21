import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:okibi/data/avatar_options.dart';
import 'package:okibi/data/user_repository.dart';
import 'package:okibi/widgets/avatar_view.dart';

Future<void> pumpAvatar(WidgetTester tester, UserProfile? profile) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: AvatarView(profile: profile))),
  );
}

Color circleColor(WidgetTester tester) =>
    tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundColor!;

void main() {
  group('AvatarView', () {
    testWidgets('選んだアイコンと色で描く', (tester) async {
      await pumpAvatar(
        tester,
        const UserProfile(
          displayName: 'あ',
          avatarIconId: 'book',
          avatarColorId: 'rose',
        ),
      );

      expect(find.byIcon(Icons.menu_book), findsOneWidget);
      expect(circleColor(tester), avatarColorFor('rose'));
    });

    testWidgets('未設定・未知のIDは人型アイコンとネイビーにする', (tester) async {
      await pumpAvatar(
        tester,
        const UserProfile(displayName: 'あ', avatarIconId: 'default'),
      );

      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(circleColor(tester), avatarColors.first.color);
    });

    testWidgets('読み込み中(null)はグレーの丸を出す', (tester) async {
      await pumpAvatar(tester, null);

      expect(find.byType(Icon), findsNothing);
      expect(circleColor(tester), Colors.grey.shade300);
    });
  });

  group('avatar_options', () {
    test('アイコンと色のIDは重複しない', () {
      expect(avatarIcons.map((o) => o.id).toSet().length, avatarIcons.length);
      expect(avatarColors.map((o) => o.id).toSet().length, avatarColors.length);
    });

    test('既定のアイコン・色が選択肢に含まれている', () {
      expect(avatarIcons.any((o) => o.id == defaultAvatarIconId), isTrue);
      expect(avatarColors.any((o) => o.id == defaultAvatarColorId), isTrue);
    });
  });
}
