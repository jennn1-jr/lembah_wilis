import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lembah_wilis/Screen/Auth/login_screen.dart';
import 'package:lembah_wilis/core/theme/app_theme.dart';
import 'package:lembah_wilis/shared/widgets/brand_avatar.dart';
import 'package:lembah_wilis/shared/widgets/role_scaffold.dart';

Widget _testApp() {
  return MaterialApp(
    theme: AppTheme.light,
    home: RoleScaffold(
      title: 'Laporan operasional',
      userName: 'Petugas',
      destinations: const [
        RoleNavigationDestination(
          label: 'Ringkasan',
          icon: Icons.dashboard_outlined,
        ),
        RoleNavigationDestination(
          label: 'Kategori',
          icon: Icons.confirmation_number_outlined,
        ),
      ],
      selectedIndex: 0,
      onDestinationSelected: (_) {},
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Konten responsif'),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _pumpAtSize(
  WidgetTester tester, {
  required double width,
  required double height,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_testApp());
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets('shows all branding highlights on a mobile login screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Proses laporan yang terstruktur'), findsOneWidget);
    expect(find.text('Pemeriksaan berlapis'), findsOneWidget);
    expect(find.text('Ringkasan operasional terverifikasi'), findsOneWidget);
    expect(find.byType(BrandAvatar), findsOneWidget);
    final logoImage = tester.widget<Image>(find.byType(Image));
    expect(logoImage.width, 92);
    expect(logoImage.height, 92);
    expect(logoImage.filterQuality, FilterQuality.high);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses bottom navigation on a phone', (tester) async {
    await _pumpAtSize(tester, width: 360, height: 800);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a navigation rail on a tablet', (tester) async {
    await _pumpAtSize(tester, width: 800, height: 1024);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a collapsible sidebar on desktop', (tester) async {
    await _pumpAtSize(tester, width: 1280, height: 800);

    expect(find.text('LEMBAH WILIS'), findsOneWidget);
    expect(find.byTooltip('Ciutkan navigasi'), findsOneWidget);
    expect(find.byType(BrandAvatar), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
