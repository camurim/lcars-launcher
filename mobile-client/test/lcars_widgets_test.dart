import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lcars_mobile_client/theme/lcars_theme.dart';
import 'package:lcars_mobile_client/widgets/lcars_button.dart';
import 'package:lcars_mobile_client/widgets/lcars_elbow.dart';
import 'package:lcars_mobile_client/widgets/lcars_info_panel.dart';
import 'package:lcars_mobile_client/widgets/lcars_pill_bar.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('LcarsButton exibe rótulo, estado offline e dispara onPressed',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 110,
            child: LcarsButton(
              label: 'VS CODE',
              code: '47-100',
              color: LcarsColors.amber,
              offline: true,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('VS CODE'), findsOneWidget);
    expect(find.text('STANDBY / OFFLINE'), findsOneWidget);

    await tester.tap(find.byType(LcarsButton));
    expect(tapped, isTrue);
  });

  testWidgets('LcarsInfoPanel diferencia modo PC offline e sensor local ativo',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              LcarsInfoPanel(
                label: 'PC CPU LOAD',
                value: '45.0%',
                sourceTag: 'PC',
                color: LcarsColors.skyBlue,
                progress: 0.45,
                offline: true,
              ),
              LcarsInfoPanel(
                label: 'STARDATE',
                value: '26904.1',
                sourceTag: 'LOCAL',
                color: LcarsColors.lavender,
                offline: false,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('STANDBY / OFFLINE'), findsOneWidget);
    expect(find.text('26904.1'), findsOneWidget);
  });

  testWidgets('LcarsElbow e LcarsPillBar renderizam sem erros', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              LcarsElbow(color: LcarsColors.amber, label: 'LCARS 47'),
              LcarsPillBar(
                color: LcarsColors.lavender,
                label: 'OPS DECK 01',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('LCARS 47'), findsOneWidget);
    expect(find.text('OPS DECK 01'), findsOneWidget);
  });
}
