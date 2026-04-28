import 'package:flutter_test/flutter_test.dart';
import 'package:asset_scanning_system/main.dart';

void main() {
  testWidgets('App loads and shows main menu', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AssetTrackerApp());

    // Verify that the main menu text is present.
    expect(find.text('Security Asset Tracker'), findsOneWidget);
    
    // Verify that the scan button is present.
    expect(find.text('START SCANNING'), findsOneWidget);
  });
}
