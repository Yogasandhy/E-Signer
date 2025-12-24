import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttd/features/document/presentation/screens/home_screen.dart';

void main() {
  testWidgets(
    'profile icon opens ProfileScreen and logout calls callback',
    (tester) async {
      var logoutCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentUploadInformationWidget(
              tenantId: 'demo',
              userId: 'user-1',
              userEmail: 'user@example.com',
              onLogout: () async {
                logoutCalls++;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Profil'));
      await tester.pumpAndSettle();

      expect(find.text('Profil'), findsOneWidget);

      final logoutButtonIcon = find.byIcon(Icons.logout_rounded);
      expect(logoutButtonIcon, findsOneWidget);

      await tester.tap(logoutButtonIcon);
      await tester.pumpAndSettle();

      final dialogLogoutButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Logout'),
      );

      expect(dialogLogoutButton, findsOneWidget);

      await tester.tap(dialogLogoutButton);
      await tester.pumpAndSettle();

      expect(logoutCalls, 1);
      expect(find.text('Profil'), findsNothing);
    },
  );
}
