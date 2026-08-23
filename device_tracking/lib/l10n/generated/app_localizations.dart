import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'نظام تتبع الأجهزة'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get login;

  /// No description provided for @email.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get email;

  /// No description provided for @password.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get password;

  /// No description provided for @receiveDevice.
  ///
  /// In ar, this message translates to:
  /// **'استلام جهاز'**
  String get receiveDevice;

  /// No description provided for @trackOrders.
  ///
  /// In ar, this message translates to:
  /// **'متابعة الطلبات'**
  String get trackOrders;

  /// No description provided for @branch.
  ///
  /// In ar, this message translates to:
  /// **'الفرع'**
  String get branch;

  /// No description provided for @orderNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الطلب'**
  String get orderNumber;

  /// No description provided for @deviceType.
  ///
  /// In ar, this message translates to:
  /// **'نوع الجهاز'**
  String get deviceType;

  /// No description provided for @manufacturer.
  ///
  /// In ar, this message translates to:
  /// **'الشركة المصنعة'**
  String get manufacturer;

  /// No description provided for @productName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المنتج'**
  String get productName;

  /// No description provided for @color.
  ///
  /// In ar, this message translates to:
  /// **'لون الجهاز'**
  String get color;

  /// No description provided for @imeiOrSerial.
  ///
  /// In ar, this message translates to:
  /// **'IMEI أو Serial Number'**
  String get imeiOrSerial;

  /// No description provided for @scanBarcode.
  ///
  /// In ar, this message translates to:
  /// **'مسح الباركود'**
  String get scanBarcode;

  /// No description provided for @deviceProblem.
  ///
  /// In ar, this message translates to:
  /// **'مشكلة الجهاز'**
  String get deviceProblem;

  /// No description provided for @deviceCondition.
  ///
  /// In ar, this message translates to:
  /// **'حالة الجهاز'**
  String get deviceCondition;

  /// No description provided for @delivererName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الشخص الذي سلّم الجهاز'**
  String get delivererName;

  /// No description provided for @createOrder.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء الطلب'**
  String get createOrder;

  /// No description provided for @orderNumberUsed.
  ///
  /// In ar, this message translates to:
  /// **'رقم الطلب مستخدم مسبقاً'**
  String get orderNumberUsed;

  /// No description provided for @pendingServiceCenterDelivery.
  ///
  /// In ar, this message translates to:
  /// **'طلبات تم استلامها وفي انتظار تسليمها لمركز الصيانة'**
  String get pendingServiceCenterDelivery;

  /// No description provided for @deliveredToServiceCenter.
  ///
  /// In ar, this message translates to:
  /// **'طلبات تم تسليمها لمركز الصيانة'**
  String get deliveredToServiceCenter;

  /// No description provided for @receivedFromServiceCenter.
  ///
  /// In ar, this message translates to:
  /// **'طلبات تم استلامها من مركز الصيانة'**
  String get receivedFromServiceCenter;

  /// No description provided for @deliveredToBranch.
  ///
  /// In ar, this message translates to:
  /// **'طلبات تم تسليمها للفرع وتكون مكتمله'**
  String get deliveredToBranch;

  /// No description provided for @completed.
  ///
  /// In ar, this message translates to:
  /// **'مكتمل'**
  String get completed;

  /// No description provided for @search.
  ///
  /// In ar, this message translates to:
  /// **'بحث...'**
  String get search;

  /// No description provided for @status.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get status;

  /// No description provided for @date.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get date;

  /// No description provided for @deliverToServiceCenterBtn.
  ///
  /// In ar, this message translates to:
  /// **'تسليم لمركز الصيانة'**
  String get deliverToServiceCenterBtn;

  /// No description provided for @receiveFromServiceCenterBtn.
  ///
  /// In ar, this message translates to:
  /// **'استلام من مركز الصيانة'**
  String get receiveFromServiceCenterBtn;

  /// No description provided for @deliverToBranchBtn.
  ///
  /// In ar, this message translates to:
  /// **'تسليم الجهاز للفرع'**
  String get deliverToBranchBtn;

  /// No description provided for @closeOrderBtn.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق الطلب'**
  String get closeOrderBtn;

  /// No description provided for @maintenanceResult.
  ///
  /// In ar, this message translates to:
  /// **'نتيجة الصيانة'**
  String get maintenanceResult;

  /// No description provided for @fixed.
  ///
  /// In ar, this message translates to:
  /// **'تم الإصلاح'**
  String get fixed;

  /// No description provided for @unfixable.
  ///
  /// In ar, this message translates to:
  /// **'غير قابل للإصلاح'**
  String get unfixable;

  /// No description provided for @needsCustomerApproval.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج موافقة العميل'**
  String get needsCustomerApproval;

  /// No description provided for @replaced.
  ///
  /// In ar, this message translates to:
  /// **'تم الاستبدال'**
  String get replaced;

  /// No description provided for @systemUpdated.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث النظام'**
  String get systemUpdated;

  /// No description provided for @other.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get other;

  /// No description provided for @notes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get notes;

  /// No description provided for @receiverName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستلم'**
  String get receiverName;

  /// No description provided for @receiverPhone.
  ///
  /// In ar, this message translates to:
  /// **'رقم جوال المستلم'**
  String get receiverPhone;

  /// No description provided for @signature.
  ///
  /// In ar, this message translates to:
  /// **'التوقيع الإلكتروني'**
  String get signature;

  /// No description provided for @reports.
  ///
  /// In ar, this message translates to:
  /// **'التقارير'**
  String get reports;

  /// No description provided for @exportExcel.
  ///
  /// In ar, this message translates to:
  /// **'تصدير Excel'**
  String get exportExcel;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @selectLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اختر اللغة'**
  String get selectLanguage;

  /// No description provided for @mobile.
  ///
  /// In ar, this message translates to:
  /// **'جوال'**
  String get mobile;

  /// No description provided for @laptop.
  ///
  /// In ar, this message translates to:
  /// **'لابتوب'**
  String get laptop;

  /// No description provided for @tablet.
  ///
  /// In ar, this message translates to:
  /// **'تابليت'**
  String get tablet;

  /// No description provided for @accessories.
  ///
  /// In ar, this message translates to:
  /// **'اكسسوارات'**
  String get accessories;

  /// No description provided for @requiredField.
  ///
  /// In ar, this message translates to:
  /// **'حقل مطلوب'**
  String get requiredField;

  /// No description provided for @underMaintenanceTab.
  ///
  /// In ar, this message translates to:
  /// **'قيد الصيانة'**
  String get underMaintenanceTab;

  /// No description provided for @waitingCustomerApprovalTab.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار موافقة العميل'**
  String get waitingCustomerApprovalTab;

  /// No description provided for @outOfWarrantyTab.
  ///
  /// In ar, this message translates to:
  /// **'خارج الضمان'**
  String get outOfWarrantyTab;

  /// No description provided for @rejectedPendingDeliveryTab.
  ///
  /// In ar, this message translates to:
  /// **'مرفوض - بانتظار التسليم'**
  String get rejectedPendingDeliveryTab;

  /// No description provided for @markAsOutOfWarrantyBtn.
  ///
  /// In ar, this message translates to:
  /// **'تعيين كخارج الضمان'**
  String get markAsOutOfWarrantyBtn;

  /// No description provided for @requestCustomerApprovalBtn.
  ///
  /// In ar, this message translates to:
  /// **'طلب موافقة العميل'**
  String get requestCustomerApprovalBtn;

  /// No description provided for @customerApprovedBtn.
  ///
  /// In ar, this message translates to:
  /// **'موافقة العميل'**
  String get customerApprovedBtn;

  /// No description provided for @customerRejectedBtn.
  ///
  /// In ar, this message translates to:
  /// **'رفض العميل'**
  String get customerRejectedBtn;

  /// No description provided for @deliverToStoreBtn.
  ///
  /// In ar, this message translates to:
  /// **'تسليم الجهاز للمتجر'**
  String get deliverToStoreBtn;

  /// No description provided for @receiverNameDialogTitle.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستلم'**
  String get receiverNameDialogTitle;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
