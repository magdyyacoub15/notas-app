import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // ----------------------------
  //  دوال المساعدة
  // ----------------------------

  void _handleCloudBackup(BuildContext context, TransactionProvider provider) async {
    _showLoadingDialog(context, 'جاري رفع النسخة الاحتياطية...');

    try {
      await provider.backupToCloud();

      // 🌟 التعديل: تحديث تاريخ آخر نسخة احتياطية بعد النجاح
      provider.updateLastBackupDate(DateTime.now());
      // 🌟

      Navigator.of(context).pop();
      _showSuccessSnackBar(context, '✅ تم رفع النسخة الاحتياطية إلى السحابة بنجاح');
    } catch (e) {
      Navigator.of(context).pop();
      _showErrorSnackBar(context, '❌ فشل النسخ السحابي: $e');
    }
  }

  void _handleCloudRestore(BuildContext context, TransactionProvider provider) async {
    try {
      // جلب قائمة النسخ الاحتياطية المتاحة
      final backups = await provider.getCloudBackupsList();

      if (backups.isEmpty) {
        _showErrorSnackBar(context, '❌ لا توجد نسخ احتياطية متاحة في السحابة');
        return;
      }

      // عرض قائمة الاختيار
      await _showBackupSelectionDialog(context, backups, provider);
    } catch (e) {
      _showErrorSnackBar(context, '❌ فشل جلب قائمة النسخ: $e');
    }
  }

  void _handleLocalShare(BuildContext context, TransactionProvider provider) async {
    _showLoadingDialog(context, 'جاري إنشاء النسخة الاحتياطية...');

    try {
      final result = await provider.shareLocalBackup();
      Navigator.of(context).pop();
      _showSuccessSnackBar(context, '📤 $result');
    } catch (e) {
      Navigator.of(context).pop();
      _showErrorSnackBar(context, '❌ فشل إنشاء النسخة: $e');
    }
  }

  void _handleLocalRestore(BuildContext context, TransactionProvider provider) async {
    final confirmed = await _showConfirmationDialog(
        context,
        'استعادة من ملف محلي',
        'هل أنت متأكد من استعادة البيانات من الملف المحلي؟ سيتم استبدال جميع البيانات الحالية.'
    );

    if (!confirmed) return;

    _showLoadingDialog(context, 'جاري استعادة البيانات...');

    try {
      await provider.restoreFromLocal();
      Navigator.of(context).pop();
      _showSuccessSnackBar(context, '📥 تم استعادة النسخة المحلية بنجاح');
    } catch (e) {
      Navigator.of(context).pop();
      _showErrorSnackBar(context, '❌ فشل الاستعادة المحلية: $e');
    }
  }

  // ----------------------------
  //  دوال المساعدة للعرض
  // ----------------------------

  Future<void> _showBackupSelectionDialog(
      BuildContext context,
      List<Map<String, dynamic>> backups,
      TransactionProvider provider
      ) async {
    final selectedBackup = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('اختر نسخة احتياطية'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backups.length,
              itemBuilder: (context, index) {
                final backup = backups[index];
                final backupNumber = index + 1;
                final fileName = backup['fileName'] ?? 'غير معروف';
                final uploadDate = backup['uploadDate'] ?? 'تاريخ غير معروف';

                // استخراج التاريخ والوقت من المعلومات المتاحة
                final displayInfo = _extractDateTimeFromBackupInfo(fileName, uploadDate);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(
                        '$backupNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      displayInfo['date'] ?? 'غير معروف',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      displayInfo['time'] ?? '00:00:00',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.of(context).pop(backup['fileName']),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
          ],
        );
      },
    );

    if (selectedBackup != null) {
      await _restoreSpecificBackup(context, provider, selectedBackup);
    }
  }

  // دالة مساعدة لاستخراج التاريخ والوقت من معلومات النسخة
  Map<String, String?> _extractDateTimeFromBackupInfo(String fileName, String uploadDate) {
    try {
      // أنماط للبحث عن التاريخ والوقت
      final dateTimePattern = RegExp(r'(\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}:\d{2})');
      final datePattern = RegExp(r'(\d{4}-\d{2}-\d{2})|(\d{2}-\d{2}-\d{4})');
      final timePattern = RegExp(r'(\d{2}:\d{2}:\d{2})');

      String? date;
      String? time;

      // البحث في اسم الملف أولاً
      var match = dateTimePattern.firstMatch(fileName);
      if (match != null) {
        final dateTimeStr = match.group(0)!;
        date = datePattern.firstMatch(dateTimeStr)?.group(0);
        time = timePattern.firstMatch(dateTimeStr)?.group(0);
      } else {
        // إذا لم يوجد تاريخ ووقت معاً، ابحث عنهم منفصلين
        date = datePattern.firstMatch(fileName)?.group(0);
        time = timePattern.firstMatch(fileName)?.group(0);
      }

      // إذا لم يتم العثور في اسم الملف، استخدم تاريخ الرفع
      if (date == null) {
        match = dateTimePattern.firstMatch(uploadDate);
        if (match != null) {
          final dateTimeStr = match.group(0)!;
          date = datePattern.firstMatch(dateTimeStr)?.group(0);
          time = timePattern.firstMatch(dateTimeStr)?.group(0);
        } else {
          date = datePattern.firstMatch(uploadDate)?.group(0);
          time = timePattern.firstMatch(uploadDate)?.group(0);
        }
      }

      // إذا لم يوجد وقت، ضع قيمة افتراضية
      if (time == null) {
        time = '00:00:00';
      }

      return {
        'date': date ?? 'غير معروف',
        'time': time,
      };
    } catch (e) {
      return {
        'date': 'غير معروف',
        'time': '00:00:00',
      };
    }
  }

  Future<void> _restoreSpecificBackup(
      BuildContext context,
      TransactionProvider provider,
      String fileName
      ) async {

    // استخراج الرقم من اسم الملف للعرض
    final backupInfo = _extractBackupNumberAndDate(fileName);

    final confirmed = await _showConfirmationDialog(
        context,
        'استعادة نسخة محددة',
        'هل أنت متأكد من استعادة ${backupInfo['number'] != null ? "النسخة ${backupInfo['number']}" : "النسخة المحددة"}؟\n'
            'التاريخ: ${backupInfo['date']}\n'
            'سيتم استبدال جميع البيانات الحالية.'
    );

    if (!confirmed) return;

    _showLoadingDialog(context, 'جاري استعادة البيانات...');

    try {
      await provider.restoreSpecificFromCloud(fileName);
      Navigator.of(context).pop();
      _showSuccessSnackBar(context, '✅ تم استعادة ${backupInfo['number'] != null ? "النسخة ${backupInfo['number']}" : "النسخة"} بنجاح');
    } catch (e) {
      Navigator.of(context).pop();
      _showErrorSnackBar(context, '❌ فشل استعادة النسخة: $e');
    }
  }

  // دالة مساعدة إضافية
  Map<String, String?> _extractBackupNumberAndDate(String fileName) {
    try {
      final numberPattern = RegExp(r'backup_(\d+)');
      final datePattern = RegExp(r'(\d{4}-\d{2}-\d{2})');

      final numberMatch = numberPattern.firstMatch(fileName);
      final dateMatch = datePattern.firstMatch(fileName);

      return {
        'number': numberMatch?.group(1),
        'date': dateMatch?.group(0) ?? 'غير معروف',
      };
    } catch (e) {
      return {'number': null, 'date': 'غير معروف'};
    }
  }
  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(child: Text(message)),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _showConfirmationDialog(BuildContext context, String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  // ----------------------------
  //  مكونات واجهة المستخدم
  // ----------------------------

  Widget _buildBackupSection({
    required String title,
    required String description,
    required List<Widget> buttons,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ...buttons,
          ],
        ),
      ),
    );
  }

  Widget _buildBackupButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }

  // ----------------------------
  //  واجهة المستخدم الرئيسية
  // ----------------------------

  @override
  Widget build(BuildContext context) {
    // نستخدم listen: false هنا لأننا سنستخدم Consumer للزر الذي يحتاج للتحديث
    final provider = Provider.of<TransactionProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Consumer<TransactionProvider>(
            builder: (context, provider, child) {
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: const Text(
                    ' النسخ الاحتياطي التلقائي',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  subtitle: Text(
                    provider.autoBackupEnabled
                        ? 'مفتوح : سيتم النسخ إلى السحابة كل 24 ساعة '
                        : 'مقفول: فعل الزر اذا كنت تريد تشغيل الرفع التلقائي الي السحابة ',
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: Switch(
                    // ربط قيمة الـ Switch بحالة الـ Provider الحالية
                    value: provider.autoBackupEnabled,
                    // عند التغيير، يتم استدعاء دالة الـ Provider لحفظ القيمة الجديدة
                    onChanged: (bool newValue) {
                      provider.setAutoBackupEnabled(newValue);
                    },
                    activeColor: Colors.blue,
                  ),
                ),
              );
            },
          ),
          // 🌟🌟 نهاية إضافة الزر 🌟🌟

          _buildBackupSection(
            title: 'النسخ الاحتياطي السحابي',
            description: 'احفظ نسخة احتياطية يدويا الي السحابة لضمان حفظ بياناتك ',
            buttons: [
              _buildBackupButton(
                icon: Icons.cloud_upload,
                label: 'نسخ احتياطي إلى السحابة',
                color: Colors.blue,
                onPressed: () => _handleCloudBackup(context, provider),
              ),
              _buildBackupButton(
                icon: Icons.cloud_download,
                label: 'استعادة من السحابة',
                color: Colors.teal,
                onPressed: () => _handleCloudRestore(context, provider),
              ),
            ],
          ),

          // قسم النسخ المحلي
          _buildBackupSection(
            title: 'النسخ الاحتياطي المحلي',
            description: 'شارك نسخة احتياطية لضمان حفظ نسخة اخري من بياناتك',
            buttons: [
              _buildBackupButton(
                icon: Icons.share,
                label: 'إنشاء ومشاركة نسخة احتياطية',
                color: Colors.orange,
                onPressed: () => _handleLocalShare(context, provider),
              ),
              _buildBackupButton(
                icon: Icons.history,
                label: 'استعادة من ملف محلي',
                color: Colors.blueGrey,
                onPressed: () => _handleLocalRestore(context, provider),
              ),
            ],
          ),

          // 🌟🌟 إضافة عنصر التحكم في النسخ التلقائي 🌟🌟

          // قسم المعلومات
          Card(
            elevation: 2,
            margin: const EdgeInsets.only(top: 16),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'نصائح مهمة',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• قم بمشاركة نسخ احتياطية بشكل منتظم\n'
                        '• تأكد من اتصال الإنترنت للنسخ السحابي\n'
                        '• تأكد من تفعيل النسخ التلقائي لسلامة بياناتك',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}