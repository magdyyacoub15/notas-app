import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/database_helper.dart';
import '../models/transaction.dart';
import '../models/custom_page.dart';
import '../services/backup_manager.dart';

class TransactionProvider with ChangeNotifier {
  List<Transaction> _transactions = [];
  List<CustomPage> _customPages = [];
  double _totalBalance = 0.0;
  static const int _maxCloudBackups = 60; // ⭐ تغيير من 30 إلى 60

  DateTime? _lastBackupDate;
  static const String _lastBackupKey = 'lastCloudBackupDate';
  DateTime? get lastBackupDate => _lastBackupDate;

  DateTime? _lastManualReminderDate;
  static const String _lastManualReminderKey = 'lastManualReminderDate';
  DateTime? get lastManualReminderDate => _lastManualReminderDate;

  // ⭐ إضافة مفتاح للنسخ التلقائي
  static const String _lastAutoBackupKey = 'last_auto_backup';
  bool _autoBackupEnabled = true;
  bool get autoBackupEnabled => _autoBackupEnabled;

  final dbHelper = DatabaseHelper.instance;
  final _backupManager = BackupManager();

  List<Transaction> get transactions => _transactions;
  List<CustomPage> get customPages => _customPages;
  double get totalBalance => _totalBalance;

  // ----------------------------------------------------
  // ⭐ دوال إدارة النسخ التلقائي
  // ----------------------------------------------------

  /// 🔄 الحصول على تاريخ آخر نسخ تلقائي
  Future<DateTime?> getLastAutoBackupDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastBackupString = prefs.getString(_lastAutoBackupKey);
      return lastBackupString != null ? DateTime.parse(lastBackupString) : null;
    } catch (e) {
      debugPrint('❌ خطأ في جلب تاريخ النسخ التلقائي: $e');
      return null;
    }
  }

  /// 🔄 التحقق من ضرورة النسخ التلقائي
  Future<bool> shouldPerformAutoBackup() async {
    if (!_autoBackupEnabled) return false;
    if (_transactions.isEmpty) return false;

    final lastBackup = await getLastAutoBackupDate();
    final now = DateTime.now();

    // التحقق إذا مرت 24 ساعة منذ آخر نسخ احتياطي
    if (lastBackup == null || now.difference(lastBackup).inHours >= 24) {
      return true;
    }
    return false;
  }

  /// ⭐ دالة النسخ إلى السحابة مع التحكم في العدد
  Future<void> backupToCloud() async {
    try {
      debugPrint('🔄 بدء النسخ الاحتياطي إلى السحابة...');

      // 1. التحقق من عدد النسخ الحالية وحذف القديمة إذا لزم الأمر
      await _manageBackupLimit();

      // 2. إنشاء ورفع النسخة الجديدة
      final dbPath = await dbHelper.getDatabasePath();
      await _backupManager.uploadDbFile(dbPath);

      // 3. حفظ تاريخ النسخ التلقائي
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastAutoBackupKey, DateTime.now().toIso8601String());

      // 4. تحديث تاريخ آخر نسخة احتياطية (للعرض في الواجهة)
      updateLastBackupDate(DateTime.now());

      debugPrint('✅ تم النسخ إلى السحابة بنجاح');

    } catch (e) {
      debugPrint('❌ فشل النسخ السحابي: $e');
      throw Exception('فشل النسخ السحابي: $e');
    }
  }

  /// 🗑️ إدارة الحد الأقصى للنسخ وحذف القديمة
  /// 🗑️ إدارة الحد الأقصى للنسخ (البديل المبسط)
  /// 🗑️ إدارة الحد الأقصى للنسخ وحذف القديمة
  Future<void> _manageBackupLimit() async {
    try {
      // 1. جلب قائمة النسخ
      List<Map<String, dynamic>> backups = await _backupManager.listAllBackups();

      // ⭐⭐ التعديل الرئيسي: إعادة ترتيب القائمة من الأقدم إلى الأحدث ⭐⭐
      backups = _sortBackupsByDate(backups);

      if (backups.length >= _maxCloudBackups) {
        debugPrint('📊 عدد النسخ الحالية: ${backups.length} - الحد الأقصى: $_maxCloudBackups');

        // حساب عدد النسخ المطلوب حذفها (لتفادي الوصول للحد)
        final backupsToKeep = _maxCloudBackups - 1;
        final backupsToDelete = backups.length - backupsToKeep;

        debugPrint('🗑️ سيتم حذف $backupsToDelete نسخة قديمة');

        // الآن الحلقة ستبدأ من العنصر رقم 0، وهو الأقدم بعد إعادة الترتيب
        for (int i = 0; i < backupsToDelete; i++) {
          final backupToDelete = backups[i];
          final fileName = backupToDelete['fileName'] as String?;
          final fileId = backupToDelete['fileId'] as String?;

          if (fileName != null && fileId != null) {
            await _backupManager.deleteBackup(
              fileName: fileName,
              fileId: fileId,
            );
            debugPrint('🗑️ تم حذف النسخة: $fileName');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ خطأ في إدارة حد النسخ: $e');
    }
  }
  /// 📅 ترتيب النسخ من الأقدم إلى الأحدث
  List<Map<String, dynamic>> _sortBackupsByDate(List<Map<String, dynamic>> backups) {
    return backups..sort((a, b) {
      final dateA = _extractDateTimeFromBackup(a);
      final dateB = _extractDateTimeFromBackup(b);
      return dateA.compareTo(dateB); // ترتيب تصاعدي (الأقدم أولاً)
    });
  }

  /// 📅 استخراج التاريخ من معلومات النسخة
  /// 📅 استخراج التاريخ من معلومات النسخة
  DateTime _extractDateTimeFromBackup(Map<String, dynamic> backup) {
    try {
      final fileName = backup['fileName']?.toString() ?? '';

      // 🌟 التعديل هنا: البحث عن التاريخ بعد آخر "/" ويتضمن أجزاء الثانية
      // النمط يبحث عن (YYYY-MM-DDTHH:MM:SS) متبوعة بنقطة وأرقام (.xxx...)
      final datePattern = RegExp(r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+)');
      final match = datePattern.firstMatch(fileName);

      if (match != null) {
        final dateString = match.group(1);
        return DateTime.parse(dateString!);
      }

      // إذا فشل استخراج التاريخ من اسم الملف (وهو مصدر التاريخ الأكثر دقة)
      // نعتمد على uploadTimestamp أو uploadDate (الأقل دقة في الترتيب)
      final uploadTimestamp = backup['uploadTimestamp'];
      if (uploadTimestamp is int) {
        // B2 ترجع uploadTimestamp كـ Milliseconds since epoch
        return DateTime.fromMillisecondsSinceEpoch(uploadTimestamp);
      }

      // إذا فشل كل شيء، نرجع تاريخاً قديماً.
      return DateTime(2000);
    } catch (e) {
      debugPrint('❌ خطأ في استخراج تاريخ النسخة: $e');
      return DateTime(2000);
    }
  }
  // في ملف transaction_provider.dart (ضمن كلاس TransactionProvider)

  static const String _lastModifiedKey = 'lastDataModificationDate';

  /// 🔄 دالة الاسترداد: لاسترجاع تاريخ آخر تعديل للبيانات.
  Future<DateTime?> getLastDataModificationDate() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_lastModifiedKey);
    if (timestamp != null) {
      return DateTime.tryParse(timestamp);
    }
    return null;
  }

  /// 💾 دالة التحديث: لحفظ التاريخ الحالي عند أي تغيير في قاعدة البيانات.
  Future<void> updateLastDataModificationDate() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    await prefs.setString(_lastModifiedKey, now);
    debugPrint('🟢 تم تحديث تاريخ آخر تعديل للبيانات.');
  }
  /// 🔧 تفعيل/تعطيل النسخ التلقائي
  Future<void> setAutoBackupEnabled(bool enabled) async {
    _autoBackupEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup_enabled', enabled);
    notifyListeners();
  }

  /// 🔧 تحميل إعدادات النسخ التلقائي
  Future<void> loadAutoBackupSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoBackupEnabled = prefs.getBool('auto_backup_enabled') ?? true;
    } catch (e) {
      _autoBackupEnabled = true;
    }
  }

  // ----------------------------------------------------
  // ⭐ دوال إدارة الصفحات المخصصة (من قاعدة البيانات)
  // ----------------------------------------------------

  Future<void> fetchCustomPages() async {
    await dbHelper.database;
    _customPages = await dbHelper.getCustomPages();
    debugPrint('🟢 تم جلب ${_customPages.length} صفحة مخصصة من قاعدة البيانات');
    notifyListeners();
  }

  Future<void> addCustomPage(CustomPage page) async {
    await dbHelper.insertCustomPage(page);
    await fetchCustomPages();
    debugPrint('🟢 تم إضافة صفحة جديدة: ${page.title}');
  }

  Future<void> deleteCustomPage(String id) async {
    await dbHelper.deleteCustomPage(id);
    await fetchCustomPages();
    debugPrint('🟢 تم حذف الصفحة: $id');
  }

  // ----------------------------------------------------
  // دوال المعاملات
  // ----------------------------------------------------

  Future<void> fetchTransactions() async {
    await dbHelper.database;
    _transactions = await dbHelper.getTransactions();
    _calculateBalance();
    notifyListeners();
  }

  // ⭐ دالة شاملة لجلب كل البيانات
  Future<void> fetchAllData() async {
    await dbHelper.database;
    await fetchTransactions();
    await fetchCustomPages();
    await loadAutoBackupSettings(); // ⭐ تحميل إعدادات النسخ التلقائي

    debugPrint('📊 بيانات التطبيق بعد التحميل:');
    debugPrint('📊 عدد المعاملات: ${_transactions.length}');
    debugPrint('📊 عدد الصفحات: ${_customPages.length}');
    debugPrint('📊 النسخ التلقائي مفعل: $_autoBackupEnabled');
  }

  Future<void> addTransaction(Transaction transaction) async {
    await dbHelper.insertTransaction(transaction);
    await fetchTransactions();
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await dbHelper.updateTransaction(transaction);
    await fetchTransactions();
  }

  Future<void> deleteTransaction(int id) async {
    await dbHelper.deleteTransaction(id);
    await fetchTransactions();
  }

  void _calculateBalance() {
    _totalBalance = 0.0;
    for (var t in _transactions) {
      if (t.type == 'Income') {
        _totalBalance += t.amount;
      } else if (t.type == 'Expense') {
        _totalBalance -= t.amount;
      }
    }
  }

  // ----------------------------------------------------
  // دوال إدارة الحسابات
  // ----------------------------------------------------

  Future<void> deleteTransactionsByAccount(
      String accountName, String partyType) async {
    await dbHelper.deleteTransactionsByAccount(accountName, partyType);
  }

  Future<void> deleteAccountAndTransactions(String accountName, String partyType) async {
    debugPrint('🟡 Provider: Starting deletion for $accountName, $partyType');

    try {
      await dbHelper.deleteTransactionsByAccount(accountName, partyType);
      debugPrint('🟡 Provider: Deleted transactions for account: $accountName');

      await fetchTransactions();
      notifyListeners();

      debugPrint('🟢 Provider: Deletion completed successfully');

    } catch (e) {
      debugPrint('🔴 Provider: Deletion error: $e');
      rethrow;
    }
  }

  Future<void> updateCustomPage(CustomPage page) async {
    await dbHelper.updateCustomPage(page);
    await fetchCustomPages();
    debugPrint('🟢 تم تعديل صفحة: ${page.title}');
  }

  Future<void> updateAccountDetails(
      String oldName,
      String newName,
      String partyType,
      String? newPhoneNumber) async {
    await dbHelper.updateAccountDetails(
        oldName, newName, partyType, newPhoneNumber);
    await fetchTransactions();
  }

  Future<String?> fetchAccountPhoneNumber(
      String accountName, String partyType) async {
    final dynamic result =
    await dbHelper.getAccountPhoneNumber(accountName, partyType);
    return result?.toString();
  }

  // ----------------------------------------------------
  // ⭐ دوال الاستعادة والنسخ الاحتياطي (المعدلة)
  // ----------------------------------------------------

  /// ⭐ تنظيف الذاكرة المؤقتة قبل الاستعادة
  Future<void> clearCacheBeforeRestore() async {
    _transactions = [];
    _customPages = [];
    _totalBalance = 0.0;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 100));
    debugPrint('🔄 تم تنظيف الذاكرة المؤقتة للبيانات');
  }

  /// ⭐ مسح البيانات وإغلاق قاعدة البيانات عند تسجيل الخروج
  Future<void> clearOnLogout() async {
    _transactions = [];
    _customPages = [];
    _totalBalance = 0.0;
    _lastBackupDate = null;
    _lastManualReminderDate = null;
    await dbHelper.closeDatabase();
    notifyListeners();
    debugPrint('🔄 تم مسح البيانات المؤقتة وإغلاق قاعدة البيانات بعد تسجيل الخروج');
  }

  /// استعادة نسخة محددة من السحابة
  Future<void> restoreSpecificFromCloud(String fileName) async {
    debugPrint('🌐 بدء استعادة النسخة السحابية: $fileName');

    await clearCacheBeforeRestore();

    final dbPath = await dbHelper.getDatabasePath();
    final success = await _backupManager.downloadSpecificBackup(fileName, dbPath);

    if (!success) {
      throw Exception("فشل في استعادة النسخة الاحتياطية من السحابة");
    }

    await fetchAllData();

    debugPrint('🟢 استعادة سحابية ناجحة');
    debugPrint('🟢 عدد الصفحات بعد الاستعادة: ${_customPages.length}');
    debugPrint('🟢 عدد المعاملات بعد الاستعادة: ${_transactions.length}');
  }

  /// استعادة النسخة من ملف محلي
  Future<void> restoreFromLocal() async {
    debugPrint('📁 بدء استعادة النسخة المحلية');

    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) {
      throw Exception("لم يتم اختيار ملف نسخة احتياطية");
    }

    await clearCacheBeforeRestore();

    final selectedBackupPath = result.files.single.path!;
    final dbPath = await dbHelper.getDatabasePath();

    final ok = await _backupManager.restoreBackupLocally(
      backupFileFullPath: selectedBackupPath,
      localDbPath: dbPath,
    );

    if (!ok) throw Exception("فشل في استعادة النسخة الاحتياطية");

    await fetchAllData();

    debugPrint('🟢 استعادة محلية ناجحة');
    debugPrint('🟢 عدد الصفحات بعد الاستعادة: ${_customPages.length}');
  }

  // ----------------------------------------------------
  // دوال النسخ الاحتياطي الأخرى
  // ----------------------------------------------------
// ⭐ أضف هذه الدالة داخل class TransactionProvider

  /// نقل حساب من صفحة إلى صفحة أخرى
  // ⭐ أضف هذه الدالة داخل class TransactionProvider

  /// نقل حساب من صفحة إلى صفحة أخرى
  Future<void> moveAccountToNewPage(
      String accountName,
      String currentPartyType,
      String newPartyType
      ) async {
    try {
      debugPrint('🟢 Moving account "$accountName" from $currentPartyType to $newPartyType');

      // الحصول على جميع معاملات الحساب من النوع الحالي
      final currentTransactions = _transactions.where((t) =>
      t.title == accountName && t.partyType == currentPartyType
      ).toList();

      if (currentTransactions.isEmpty) {
        debugPrint('🔴 No transactions found for account: $accountName');
        return;
      }

      debugPrint('🟢 Found ${currentTransactions.length} transactions to move');

      // تحديث نوع الحزب لجميع المعاملات
      for (var transaction in currentTransactions) {
        final updatedTransaction = Transaction(
          id: transaction.id,
          title: transaction.title,
          amount: transaction.amount,
          date: transaction.date,
          type: transaction.type,
          partyType: newPartyType, // ⭐ التغيير هنا
          category: transaction.category, // ⭐ إضافة category
          notes: transaction.notes, // ⭐ إضافة notes بدلاً من description
          phoneNumber: transaction.phoneNumber,
        );

        // تحديث في قاعدة البيانات
        await dbHelper.updateTransaction(updatedTransaction);

        // تحديث في القائمة المحلية
        final index = _transactions.indexWhere((t) => t.id == transaction.id);
        if (index != -1) {
          _transactions[index] = updatedTransaction;
        }
      }

      debugPrint('🟢 Successfully moved ${currentTransactions.length} transactions for account: $accountName');

      // إعادة حساب الرصيد
      _calculateBalance();

      // إشعار المستمعين بالتغيير
      notifyListeners();

    } catch (e) {
      debugPrint('🔴 Error moving account: $e');
      throw Exception('فشل في نقل الحساب: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCloudBackupsList() async {
    return await _backupManager.listAllBackups();
  }

  Future<String> shareLocalBackup() async {
    final dbPath = await dbHelper.getDatabasePath();
    return await _backupManager.shareLocalBackup(dbPath);
  }

  // ----------------------------------------------------
  // دوال Shared Preferences (للتواريخ فقط)
  // ----------------------------------------------------

  Future<void> loadLastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_lastBackupKey);

    if (dateString != null) {
      try {
        _lastBackupDate = DateTime.parse(dateString);
      } catch (_) {
        _lastBackupDate = null;
      }
    } else {
      _lastBackupDate = null;
    }
  }

  void updateLastBackupDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackupKey, date.toIso8601String());
    _lastBackupDate = date;
    notifyListeners();
  }

  Future<void> loadLastManualReminderDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_lastManualReminderKey);

    if (dateString != null) {
      try {
        _lastManualReminderDate = DateTime.parse(dateString);
      } catch (_) {
        _lastManualReminderDate = null;
      }
    } else {
      _lastManualReminderDate = null;
    }
  }

  void updateLastManualReminderDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastManualReminderKey, date.toIso8601String());
    _lastManualReminderDate = date;
    notifyListeners();
  }
}