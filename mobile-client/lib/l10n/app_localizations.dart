import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'LCARS Launcher'**
  String get appTitle;

  /// No description provided for @backButton.
  ///
  /// In en, this message translates to:
  /// **'◄ BACK'**
  String get backButton;

  /// No description provided for @statusOnline.
  ///
  /// In en, this message translates to:
  /// **'ONLINE'**
  String get statusOnline;

  /// No description provided for @statusStandalone.
  ///
  /// In en, this message translates to:
  /// **'STANDALONE (LOCAL)'**
  String get statusStandalone;

  /// No description provided for @statusStandbyOffline.
  ///
  /// In en, this message translates to:
  /// **'STANDBY / OFFLINE'**
  String get statusStandbyOffline;

  /// No description provided for @sideConnect.
  ///
  /// In en, this message translates to:
  /// **'CONNECT'**
  String get sideConnect;

  /// No description provided for @sideStandalone.
  ///
  /// In en, this message translates to:
  /// **'STANDALONE'**
  String get sideStandalone;

  /// No description provided for @sidePcLink.
  ///
  /// In en, this message translates to:
  /// **'PC LINK'**
  String get sidePcLink;

  /// No description provided for @sideScreenOn.
  ///
  /// In en, this message translates to:
  /// **'SCREEN ON'**
  String get sideScreenOn;

  /// No description provided for @sideScreenAuto.
  ///
  /// In en, this message translates to:
  /// **'SCREEN AUTO'**
  String get sideScreenAuto;

  /// No description provided for @sideEditPanel.
  ///
  /// In en, this message translates to:
  /// **'EDIT PANEL'**
  String get sideEditPanel;

  /// No description provided for @sideDone.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get sideDone;

  /// No description provided for @sideAddBlock.
  ///
  /// In en, this message translates to:
  /// **'+ BLOCK'**
  String get sideAddBlock;

  /// No description provided for @blueprintHeader.
  ///
  /// In en, this message translates to:
  /// **'BLUEPRINT'**
  String get blueprintHeader;

  /// No description provided for @connectionHeader.
  ///
  /// In en, this message translates to:
  /// **'SUBSPACE LINK • PAIRING'**
  String get connectionHeader;

  /// No description provided for @scanQrButton.
  ///
  /// In en, this message translates to:
  /// **'SCAN QR CODE'**
  String get scanQrButton;

  /// No description provided for @usbModeButton.
  ///
  /// In en, this message translates to:
  /// **'USB MODE (127.0.0.1)'**
  String get usbModeButton;

  /// No description provided for @testingUsbButton.
  ///
  /// In en, this message translates to:
  /// **'TESTING USB...'**
  String get testingUsbButton;

  /// No description provided for @discoveredAgentsTitle.
  ///
  /// In en, this message translates to:
  /// **'DISCOVERED AGENTS ON NETWORK (mDNS)'**
  String get discoveredAgentsTitle;

  /// No description provided for @searchingMdns.
  ///
  /// In en, this message translates to:
  /// **'SEARCHING _lcars-agent._tcp ON LOCAL NETWORK...'**
  String get searchingMdns;

  /// No description provided for @manualConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'MANUAL CONNECTION / 6-DIGIT PIN'**
  String get manualConnectionTitle;

  /// No description provided for @usbPinNotice.
  ///
  /// In en, this message translates to:
  /// **'IMPORTANT: EVEN IN USB MODE (127.0.0.1), THE 6-DIGIT PIN SHOWN IN THE DESKTOP AGENT IS REQUIRED TO AUTHORIZE THIS DEVICE.'**
  String get usbPinNotice;

  /// No description provided for @ipAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'IP ADDRESS'**
  String get ipAddressLabel;

  /// No description provided for @portLabel.
  ///
  /// In en, this message translates to:
  /// **'PORT'**
  String get portLabel;

  /// No description provided for @pinLabel.
  ///
  /// In en, this message translates to:
  /// **'TEMPORARY PIN (6 DIGITS — REQUIRED)'**
  String get pinLabel;

  /// No description provided for @authorizeConnectButton.
  ///
  /// In en, this message translates to:
  /// **'AUTHORIZE & CONNECT'**
  String get authorizeConnectButton;

  /// No description provided for @connectingButton.
  ///
  /// In en, this message translates to:
  /// **'CONNECTING...'**
  String get connectingButton;

  /// No description provided for @qrScannerHeader.
  ///
  /// In en, this message translates to:
  /// **'SCAN DESKTOP AGENT QR CODE'**
  String get qrScannerHeader;

  /// No description provided for @invalidIpOrPinError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid IP and a 6-digit PIN.'**
  String get invalidIpOrPinError;

  /// No description provided for @usbTunnelChecking.
  ///
  /// In en, this message translates to:
  /// **'CHECKING USB TUNNEL AT {host}:{port}...'**
  String usbTunnelChecking(String host, int port);

  /// No description provided for @usbTunnelActiveConnecting.
  ///
  /// In en, this message translates to:
  /// **'USB TUNNEL ACTIVE! CONNECTING...'**
  String get usbTunnelActiveConnecting;

  /// No description provided for @usbTunnelActiveEnterPin.
  ///
  /// In en, this message translates to:
  /// **'USB TUNNEL ACTIVE AT {host}:{port}! EVEN OVER USB, ENTER THE 6-DIGIT PIN FROM THE DESKTOP AGENT BELOW AND TAP AUTHORIZE.'**
  String usbTunnelActiveEnterPin(String host, int port);

  /// No description provided for @usbTunnelNotFound.
  ///
  /// In en, this message translates to:
  /// **'USB tunnel not detected at {host}:{port}. On your PC, run:\nadb reverse tcp:{port} tcp:{port}'**
  String usbTunnelNotFound(String host, int port);

  /// No description provided for @dialogNewBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'BLUEPRINT • NEW BLOCK'**
  String get dialogNewBlockTitle;

  /// No description provided for @dialogEditBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'BLUEPRINT • EDIT BLOCK'**
  String get dialogEditBlockTitle;

  /// No description provided for @fieldBlockType.
  ///
  /// In en, this message translates to:
  /// **'BLOCK TYPE'**
  String get fieldBlockType;

  /// No description provided for @blockTypePcAction.
  ///
  /// In en, this message translates to:
  /// **'PC Action (Remote Execution)'**
  String get blockTypePcAction;

  /// No description provided for @blockTypeLocalApp.
  ///
  /// In en, this message translates to:
  /// **'Device App (Launch Local App)'**
  String get blockTypeLocalApp;

  /// No description provided for @blockTypeLocalControl.
  ///
  /// In en, this message translates to:
  /// **'Device Control (Brightness/Volume/BT)'**
  String get blockTypeLocalControl;

  /// No description provided for @blockTypeInfo.
  ///
  /// In en, this message translates to:
  /// **'Info Panel (PC / Local)'**
  String get blockTypeInfo;

  /// No description provided for @blockTypeHttpJson.
  ///
  /// In en, this message translates to:
  /// **'HTTP / REST Panel (JSON)'**
  String get blockTypeHttpJson;

  /// No description provided for @fieldPcAction.
  ///
  /// In en, this message translates to:
  /// **'SYNCED PC ACTION'**
  String get fieldPcAction;

  /// No description provided for @fieldInstalledApp.
  ///
  /// In en, this message translates to:
  /// **'INSTALLED APP'**
  String get fieldInstalledApp;

  /// No description provided for @loadingApps.
  ///
  /// In en, this message translates to:
  /// **'LOADING INSTALLED APPS...'**
  String get loadingApps;

  /// No description provided for @fieldDeviceControl.
  ///
  /// In en, this message translates to:
  /// **'DEVICE CONTROL'**
  String get fieldDeviceControl;

  /// No description provided for @fieldDataSource.
  ///
  /// In en, this message translates to:
  /// **'DATA SOURCE'**
  String get fieldDataSource;

  /// No description provided for @sourcePcTelemetry.
  ///
  /// In en, this message translates to:
  /// **'PC Telemetry / Commands'**
  String get sourcePcTelemetry;

  /// No description provided for @sourceLocalDevice.
  ///
  /// In en, this message translates to:
  /// **'Tablet Local Sensor'**
  String get sourceLocalDevice;

  /// No description provided for @fieldMetric.
  ///
  /// In en, this message translates to:
  /// **'METRIC'**
  String get fieldMetric;

  /// No description provided for @metricPcCpu.
  ///
  /// In en, this message translates to:
  /// **'PC: CPU Usage (%)'**
  String get metricPcCpu;

  /// No description provided for @metricPcRamFree.
  ///
  /// In en, this message translates to:
  /// **'PC: Free RAM (GB)'**
  String get metricPcRamFree;

  /// No description provided for @metricPcTemp.
  ///
  /// In en, this message translates to:
  /// **'PC: CPU Temperature (°C)'**
  String get metricPcTemp;

  /// No description provided for @metricLocalClock.
  ///
  /// In en, this message translates to:
  /// **'Local: Time'**
  String get metricLocalClock;

  /// No description provided for @metricLocalStardate.
  ///
  /// In en, this message translates to:
  /// **'Local: Stardate'**
  String get metricLocalStardate;

  /// No description provided for @metricLocalBattery.
  ///
  /// In en, this message translates to:
  /// **'Local: Battery Level'**
  String get metricLocalBattery;

  /// No description provided for @fieldHttpUrl.
  ///
  /// In en, this message translates to:
  /// **'REST URL (GET JSON)'**
  String get fieldHttpUrl;

  /// No description provided for @fieldHttpPath.
  ///
  /// In en, this message translates to:
  /// **'JSON PROPERTY PATH'**
  String get fieldHttpPath;

  /// No description provided for @fieldHttpPrefix.
  ///
  /// In en, this message translates to:
  /// **'PREFIX'**
  String get fieldHttpPrefix;

  /// No description provided for @fieldHttpSuffix.
  ///
  /// In en, this message translates to:
  /// **'SUFFIX'**
  String get fieldHttpSuffix;

  /// No description provided for @testRequestButton.
  ///
  /// In en, this message translates to:
  /// **'TEST REQUEST'**
  String get testRequestButton;

  /// No description provided for @testingRequestButton.
  ///
  /// In en, this message translates to:
  /// **'TESTING...'**
  String get testingRequestButton;

  /// No description provided for @fieldPanelLabel.
  ///
  /// In en, this message translates to:
  /// **'PANEL LABEL'**
  String get fieldPanelLabel;

  /// No description provided for @fieldLcarsColor.
  ///
  /// In en, this message translates to:
  /// **'LCARS COLOR'**
  String get fieldLcarsColor;

  /// No description provided for @btnRemove.
  ///
  /// In en, this message translates to:
  /// **'REMOVE'**
  String get btnRemove;

  /// No description provided for @btnCancel.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get btnCancel;

  /// No description provided for @btnSaveSync.
  ///
  /// In en, this message translates to:
  /// **'SAVE & SYNC'**
  String get btnSaveSync;

  /// No description provided for @tapToRefresh.
  ///
  /// In en, this message translates to:
  /// **'TAP TO REFRESH'**
  String get tapToRefresh;

  /// No description provided for @waiting.
  ///
  /// In en, this message translates to:
  /// **'WAITING...'**
  String get waiting;

  /// No description provided for @ctrlVolumeUp.
  ///
  /// In en, this message translates to:
  /// **'Volume +'**
  String get ctrlVolumeUp;

  /// No description provided for @ctrlVolumeDown.
  ///
  /// In en, this message translates to:
  /// **'Volume -'**
  String get ctrlVolumeDown;

  /// No description provided for @ctrlVolumeMute.
  ///
  /// In en, this message translates to:
  /// **'Mute / Sound'**
  String get ctrlVolumeMute;

  /// No description provided for @ctrlBrightnessUp.
  ///
  /// In en, this message translates to:
  /// **'Brightness +'**
  String get ctrlBrightnessUp;

  /// No description provided for @ctrlBrightnessDown.
  ///
  /// In en, this message translates to:
  /// **'Brightness -'**
  String get ctrlBrightnessDown;

  /// No description provided for @ctrlBrightnessAuto.
  ///
  /// In en, this message translates to:
  /// **'Brightness Auto'**
  String get ctrlBrightnessAuto;

  /// No description provided for @ctrlBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth (Enable / Panel)'**
  String get ctrlBluetooth;

  /// No description provided for @ctrlWifiPanel.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi / Internet (Panel)'**
  String get ctrlWifiPanel;

  /// No description provided for @fieldDisplayFormat.
  ///
  /// In en, this message translates to:
  /// **'DISPLAY STYLE'**
  String get fieldDisplayFormat;

  /// No description provided for @formatBar.
  ///
  /// In en, this message translates to:
  /// **'Segmented Bar'**
  String get formatBar;

  /// No description provided for @formatSparkline.
  ///
  /// In en, this message translates to:
  /// **'Line Chart (Sparkline)'**
  String get formatSparkline;

  /// No description provided for @formatGauge.
  ///
  /// In en, this message translates to:
  /// **'Radial Gauge'**
  String get formatGauge;

  /// No description provided for @formatValue.
  ///
  /// In en, this message translates to:
  /// **'Numeric Only'**
  String get formatValue;

  /// No description provided for @sideAlarmMute.
  ///
  /// In en, this message translates to:
  /// **'MUTE ALERT'**
  String get sideAlarmMute;

  /// No description provided for @sideAlarmUnmute.
  ///
  /// In en, this message translates to:
  /// **'SOUND ALERT'**
  String get sideAlarmUnmute;

  /// No description provided for @fieldAlarmMode.
  ///
  /// In en, this message translates to:
  /// **'ALARM MODE (RED ALERT)'**
  String get fieldAlarmMode;

  /// No description provided for @alarmNone.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get alarmNone;

  /// No description provided for @alarmVisual.
  ///
  /// In en, this message translates to:
  /// **'Visual (Flashing Red Lights)'**
  String get alarmVisual;

  /// No description provided for @alarmSound.
  ///
  /// In en, this message translates to:
  /// **'Sound (Red Alert Klaxon)'**
  String get alarmSound;

  /// No description provided for @alarmBoth.
  ///
  /// In en, this message translates to:
  /// **'Visual + Sound'**
  String get alarmBoth;

  /// No description provided for @fieldAlarmMin.
  ///
  /// In en, this message translates to:
  /// **'MIN (≤)'**
  String get fieldAlarmMin;

  /// No description provided for @fieldAlarmMax.
  ///
  /// In en, this message translates to:
  /// **'MAX (≥)'**
  String get fieldAlarmMax;

  /// No description provided for @sideBackup.
  ///
  /// In en, this message translates to:
  /// **'BACKUP'**
  String get sideBackup;

  /// No description provided for @backupDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'BACKUP & RESTORE'**
  String get backupDialogTitle;

  /// No description provided for @btnExportFile.
  ///
  /// In en, this message translates to:
  /// **'SAVE .JSON FILE'**
  String get btnExportFile;

  /// No description provided for @btnCopyJson.
  ///
  /// In en, this message translates to:
  /// **'COPY JSON'**
  String get btnCopyJson;

  /// No description provided for @btnImportFile.
  ///
  /// In en, this message translates to:
  /// **'OPEN .JSON FILE'**
  String get btnImportFile;

  /// No description provided for @btnPushPc.
  ///
  /// In en, this message translates to:
  /// **'SEND TO PC'**
  String get btnPushPc;

  /// No description provided for @btnPullPc.
  ///
  /// In en, this message translates to:
  /// **'RESTORE FROM PC'**
  String get btnPullPc;

  /// No description provided for @fieldPasteBackupJson.
  ///
  /// In en, this message translates to:
  /// **'OR PASTE BACKUP JSON'**
  String get fieldPasteBackupJson;

  /// No description provided for @btnRestoreJsonText.
  ///
  /// In en, this message translates to:
  /// **'RESTORE FROM TEXT'**
  String get btnRestoreJsonText;

  /// No description provided for @backupSavedOk.
  ///
  /// In en, this message translates to:
  /// **'Backup file saved successfully!'**
  String get backupSavedOk;

  /// No description provided for @backupCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export cancelled.'**
  String get backupCancelled;

  /// No description provided for @backupCopiedOk.
  ///
  /// In en, this message translates to:
  /// **'Backup JSON copied to clipboard!'**
  String get backupCopiedOk;

  /// No description provided for @backupRestoredOk.
  ///
  /// In en, this message translates to:
  /// **'Backup restored successfully!'**
  String get backupRestoredOk;

  /// No description provided for @backupInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Invalid backup JSON'**
  String get backupInvalidError;

  /// No description provided for @backupPushedPc.
  ///
  /// In en, this message translates to:
  /// **'Layout backup sent to PC!'**
  String get backupPushedPc;

  /// No description provided for @backupPulledPc.
  ///
  /// In en, this message translates to:
  /// **'Requesting backup from PC...'**
  String get backupPulledPc;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
