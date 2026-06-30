import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'b2_service.dart';

class BackupManager {
  // اسم افتراضي لقاعدة البيانات المحلية
  static const String backupFileName = "finance_backup_data.db";

  final B2Service b2 = B2Service();

  BackupManager() {
    // استدعاء التصريح عند إنشاء الكلاس
    _init();
  }

  // --------------------------------------------------------
  // 0️⃣ التشغيل الأولي والتصريح بالدخول
  // --------------------------------------------------------
  Future<void> _init() async {
    print("🔵 [BackupManager] Initializing B2 authorization...");
    try {
      // محاولة التصريح بالدخول
      await b2.authorizeAccount();
      print("🟢 [BackupManager] B2 authorization completed.");
    } catch (e) {
      print("❌ [BackupManager] Initialization failed: $e");
    }
  }

  // --------------------------------------------------------
  // 1️⃣ رفع النسخة الاحتياطية إلى Backblaze
  // --------------------------------------------------------
  Future<bool> uploadDbFile(String localDbPath) async {
    print("🔵 [UPLOAD] Preparing to upload DB file...");

    final file = File(localDbPath);
    if (!await file.exists()) {
      print("❌ [UPLOAD] ERROR: DB file not found!");
      throw Exception("DB file not found.");
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print("❌ [UPLOAD] ERROR: User not logged in.");
      return false;
    }

    // حفظ باسم التاريخ والوقت لتمكين نسخ متعددة
    final backupName = "${DateTime.now().toIso8601String()}.db";
    final remoteName = "$uid/$backupName";

    print("📤 [UPLOAD] Uploading file as: $remoteName");

    final ok = await b2.uploadFile(
      filePath: localDbPath,
      fileName: remoteName,
    );

    print(ok
        ? "🟢 [UPLOAD] Upload successful."
        : "❌ [UPLOAD] Upload FAILED.");

    return ok;
  }

  // --------------------------------------------------------
  // 2️⃣ جلب قائمة النسخ الاحتياطية المتاحة (يُستخدم لفتح Dialog)
  // --------------------------------------------------------
  /// ترجع قائمة بجميع ملفات النسخ الاحتياطي الخاصة بهذا المستخدم
  Future<List<Map<String, dynamic>>> listAllBackups() async {
    print("🔵 [LIST] Fetching all available backups...");

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print("❌ [LIST] ERROR: User not logged in.");
      return [];
    }

    // استخدام الـ uid كـ prefix لجلب ملفات هذا المستخدم فقط
    final files = await b2.listFiles(prefix: uid);

    if (files.isEmpty) {
      print("❌ [LIST] No backups found on cloud.");
      return [];
    }

    // فرز القائمة من الأحدث إلى الأقدم بناءً على uploadTimestamp
    // (لذلك، سيكون أقدم ملف في نهاية القائمة)
    files.sort(
          (a, b) => b['uploadTimestamp'].compareTo(a['uploadTimestamp']),
    );

    return files;
  }

  // --------------------------------------------------------
  // 3️⃣ تنزيل نسخة احتياطية محددة
  // --------------------------------------------------------
  /// تنزيل ملف محدد باسمه الكامل وحفظه في مسار قاعدة البيانات
  Future<bool> downloadSpecificBackup(String fileName, String destinationDbPath) async {
    print("📥 [DOWNLOAD SPECIFIC] Downloading backup: $fileName");

    final fileBytes = await b2.downloadFile(fileName);

    if (fileBytes == null) {
      print("❌ [DOWNLOAD SPECIFIC] Failed to download file bytes for $fileName.");
      return false;
    }

    final restoredFile = File(destinationDbPath);
    await restoredFile.writeAsBytes(fileBytes);

    print("🟢 [DOWNLOAD SPECIFIC] Database restored successfully from $fileName.");

    return true;
  }

  // --------------------------------------------------------
  // 6️⃣ حذف نسخة احتياطية محددة (لإدارة حد الـ 30 نسخة) 🌟 تم التصحيح 🌟
  // --------------------------------------------------------
  /// حذف ملف نسخة احتياطية محدد باسمه الكامل
  Future<bool> deleteBackup({required String fileName, required String fileId}) async {
    print("🗑️ [DELETE] Deleting backup: $fileName");

    try {
      // 🟢 الاستدعاء الصحيح للـ B2Service بالوسائط المسماة
      final success = await b2.deleteFile(fileName: fileName, fileId: fileId);

      if(success) {
        print("🟢 [DELETE] Successfully deleted $fileName.");
      } else {
        print("❌ [DELETE] B2Service reported failure for $fileName.");
      }
      return success;
    } catch (e) {
      print("❌ [DELETE] Failed to delete $fileName: $e");
      return false;
    }
  }

  // --------------------------------------------------------
  // 4️⃣ إنشاء نسخة محلية ومشاركتها (تم تصحيح موضعها)
  // --------------------------------------------------------
  /// هذه الدالة مطلوبة للاستدعاء القديم shareLocalBackup
  Future<String> shareLocalBackup(String localDbPath) async {
    print("🔵 [LOCAL BACKUP] Preparing local backup...");

    final file = File(localDbPath);

    if (!await file.exists()) {
      print("❌ [LOCAL BACKUP] Local DB file not found.");
      throw Exception("DB file not found.");
    }

    print("📤 [LOCAL BACKUP] Opening share dialog...");

    await Share.shareXFiles(
      [XFile(localDbPath)],
      text: "📦 نسخة احتياطية من التطبيق",
    );

    print("🟢 [LOCAL BACKUP] Share dialog opened.");

    return localDbPath;
  }

  // --------------------------------------------------------
  // 5️⃣ استعادة نسخة احتياطية محلية (تم تصحيح موضعها)
  // --------------------------------------------------------
  /// هذه الدالة مطلوبة للاستدعاء القديم restoreBackupLocally
  Future<bool> restoreBackupLocally({
    required String backupFileFullPath,
    required String localDbPath,
  }) async {
    print("🔵 [RESTORE LOCAL] Starting restore...");

    final backupFile = File(backupFileFullPath);

    if (!backupFile.existsSync()) {
      print("❌ [RESTORE LOCAL] Backup file does NOT exist!");
      throw Exception("Backup file not found.");
    }

    final localDbFile = File(localDbPath);

    print("🔄 [RESTORE LOCAL] Copying file...");
    await localDbFile.writeAsBytes(await backupFile.readAsBytes());

    print("🟢 [RESTORE LOCAL] Restore completed successfully.");

    return true;
  }
}