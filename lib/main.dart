import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'providers/transaction_provider.dart';

import 'screens/main_layout.dart';
import 'screens/login_page.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🟦 تهيئة Firebase
  await Firebase.initializeApp();

  runApp(
    ChangeNotifierProvider(
      create: (context) => TransactionProvider()
        ..fetchTransactions(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // ----------------------------------------------------
  // 1. منطق النسخ الاحتياطي التلقائي كل 24 ساعة
  // ----------------------------------------------------
  void _checkAndRunAutoBackup(BuildContext context) async {
    final provider = Provider.of<TransactionProvider>(context, listen: false);

    final lastBackup = await provider.getLastAutoBackupDate();
    final lastModified = await provider.getLastDataModificationDate(); // ⬅️ افتراض إضافة هذه الدالة

    final now = DateTime.now();

    // 1. الشرط الأساسي: هل مر وقت كافي (24 ساعة)؟
    final isTimeForBackup = (lastBackup == null || now.difference(lastBackup).inHours >= 24);

    // 2. الشرط الإضافي: هل حدث تغيير في البيانات منذ آخر نسخ؟
    // نتحقق إذا كان تاريخ التعديل أحدث من تاريخ آخر نسخ ناجح
    final hasDataChanged = (lastModified != null && (lastBackup == null || lastModified.isAfter(lastBackup)));

    if (isTimeForBackup && hasDataChanged) {
      print('🔄 بدء النسخ التلقائي: تم تجاوز الحد الزمني ووجود تغييرات جديدة.');
      await provider.backupToCloud();
      print('✅ تم النسخ التلقائي بنجاح');
    } else {
      print('ℹ️ لم يتم تشغيل النسخ التلقائي: (لم يمر 24 ساعة أو لا توجد تغييرات جديدة).');
    }
  }
  // ----------------------------------------------------
  // 2. منطق عرض تذكير النسخ اليدوي (Manual Reminder) - كـ Dialog
  // ----------------------------------------------------
  void _checkAndShowManualBackupReminder(BuildContext context) async {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final lastReminder = provider.lastManualReminderDate;
    final now = DateTime.now();

    const Duration requiredInterval = Duration(hours: 24);

    if (lastReminder == null || now.difference(lastReminder) > requiredInterval) {

      // إظهار AlertDialog بدلاً من SnackBar ليظهر في المنتصف
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: Colors.indigo.shade700,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_active, color: Colors.yellow, size: 28),
                SizedBox(width: 10),
                Text(
                  'تذكير هام!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            content: const Text(
              'لا تنس مشاركة نسخة احتياطية يدويا على الواتساب أو التليجرام لضمان نسخة احتياطية إضافية في حالة حدوث أي مشكلة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () {
                  // تحديث تاريخ التذكير لمنع الظهور مجدداً لمدة 24 ساعة
                  provider.updateLastManualReminderDate(now);

                  // 1. إغلاق الـ Dialog
                  Navigator.of(dialogContext).pop();

                  // 2. الانتقال إلى صفحة الإعدادات (SettingsScreen)
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => const SettingsScreen(),
                    ),
                  );
                },
                child: const Text(
                  'مشاركة الآن',
                  style: TextStyle(
                    color: Colors.yellowAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  // تحديث التاريخ حتى لو لم تتم المشاركة لتجنب الظهور المتكرر
                  provider.updateLastManualReminderDate(now);
                  Navigator.of(dialogContext).pop();
                },
                child: const Text(
                  'تذكيري لاحقاً',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          );
        },
      );

      provider.updateLastManualReminderDate(now);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finance Tracker',

      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Alfares',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.bold),
          displayMedium: TextStyle(fontWeight: FontWeight.bold),
          displaySmall: TextStyle(fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(fontWeight: FontWeight.bold),
          titleLarge: TextStyle(fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontWeight: FontWeight.bold),
          titleSmall: TextStyle(fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(fontWeight: FontWeight.bold),
          bodySmall: TextStyle(fontWeight: FontWeight.bold),
          labelLarge: TextStyle(fontWeight: FontWeight.bold),
          labelMedium: TextStyle(fontWeight: FontWeight.bold),
          labelSmall: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            // ⭐ تشغيل منطق النسخ التلقائي والتذكير ⭐
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // 1. تشغيل التحقق وعرض النسخ التلقائي كل 24 ساعة
              _checkAndRunAutoBackup(context);

              // 2. تشغيل التحقق وعرض تذكير النسخ اليدوي
              _checkAndShowManualBackupReminder(context);
            });
            return const MainLayout();
          }

          return LoginPage();
        },
      ),
    );
  }
}