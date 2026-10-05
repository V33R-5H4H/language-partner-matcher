import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:test1/main.dart';
import 'package:test1/providers/auth_provider.dart';
import 'package:test1/providers/call_provider.dart';
import 'package:test1/providers/match_provider.dart';

void main() {
  testWidgets('App launches and displays matchmaking tab smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => MatchProvider()),
          ChangeNotifierProvider(create: (_) => CallProvider()),
        ],
        child: const LanguageMatcherApp(),
      ),
    );

    // Verify that the title and matchmaking action button are present
    expect(find.text('Find Conversation Partner'), findsOneWidget);
    expect(find.text('Start Matchmaking'), findsOneWidget);
  });
}
