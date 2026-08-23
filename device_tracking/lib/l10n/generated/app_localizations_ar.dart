// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'نظام تتبع الأجهزة';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get receiveDevice => 'استلام جهاز';

  @override
  String get trackOrders => 'متابعة الطلبات';

  @override
  String get branch => 'الفرع';

  @override
  String get orderNumber => 'رقم الطلب';

  @override
  String get deviceType => 'نوع الجهاز';

  @override
  String get manufacturer => 'الشركة المصنعة';

  @override
  String get productName => 'اسم المنتج';

  @override
  String get color => 'لون الجهاز';

  @override
  String get imeiOrSerial => 'IMEI أو Serial Number';

  @override
  String get scanBarcode => 'مسح الباركود';

  @override
  String get deviceProblem => 'مشكلة الجهاز';

  @override
  String get deviceCondition => 'حالة الجهاز';

  @override
  String get delivererName => 'اسم الشخص الذي سلّم الجهاز';

  @override
  String get createOrder => 'إنشاء الطلب';

  @override
  String get orderNumberUsed => 'رقم الطلب مستخدم مسبقاً';

  @override
  String get pendingServiceCenterDelivery =>
      'طلبات تم استلامها وفي انتظار تسليمها لمركز الصيانة';

  @override
  String get deliveredToServiceCenter => 'طلبات تم تسليمها لمركز الصيانة';

  @override
  String get receivedFromServiceCenter => 'طلبات تم استلامها من مركز الصيانة';

  @override
  String get deliveredToBranch => 'طلبات تم تسليمها للفرع وتكون مكتمله';

  @override
  String get completed => 'مكتمل';

  @override
  String get search => 'بحث...';

  @override
  String get status => 'الحالة';

  @override
  String get date => 'التاريخ';

  @override
  String get deliverToServiceCenterBtn => 'تسليم لمركز الصيانة';

  @override
  String get receiveFromServiceCenterBtn => 'استلام من مركز الصيانة';

  @override
  String get deliverToBranchBtn => 'تسليم الجهاز للفرع';

  @override
  String get closeOrderBtn => 'إغلاق الطلب';

  @override
  String get maintenanceResult => 'نتيجة الصيانة';

  @override
  String get fixed => 'تم الإصلاح';

  @override
  String get unfixable => 'غير قابل للإصلاح';

  @override
  String get needsCustomerApproval => 'يحتاج موافقة العميل';

  @override
  String get replaced => 'تم الاستبدال';

  @override
  String get systemUpdated => 'تم تحديث النظام';

  @override
  String get other => 'أخرى';

  @override
  String get notes => 'ملاحظات';

  @override
  String get receiverName => 'اسم المستلم';

  @override
  String get receiverPhone => 'رقم جوال المستلم';

  @override
  String get signature => 'التوقيع الإلكتروني';

  @override
  String get reports => 'التقارير';

  @override
  String get exportExcel => 'تصدير Excel';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get selectLanguage => 'اختر اللغة';

  @override
  String get mobile => 'جوال';

  @override
  String get laptop => 'لابتوب';

  @override
  String get tablet => 'تابليت';

  @override
  String get accessories => 'اكسسوارات';

  @override
  String get requiredField => 'حقل مطلوب';

  @override
  String get underMaintenanceTab => 'قيد الصيانة';

  @override
  String get waitingCustomerApprovalTab => 'بانتظار موافقة العميل';

  @override
  String get outOfWarrantyTab => 'خارج الضمان';

  @override
  String get rejectedPendingDeliveryTab => 'مرفوض - بانتظار التسليم';

  @override
  String get markAsOutOfWarrantyBtn => 'تعيين كخارج الضمان';

  @override
  String get requestCustomerApprovalBtn => 'طلب موافقة العميل';

  @override
  String get customerApprovedBtn => 'موافقة العميل';

  @override
  String get customerRejectedBtn => 'رفض العميل';

  @override
  String get deliverToStoreBtn => 'تسليم الجهاز للمتجر';

  @override
  String get receiverNameDialogTitle => 'اسم المستلم';
}
