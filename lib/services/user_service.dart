import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();

  static const String usersCollection = 'users';

  /// 🔑 الآن نربط البيانات بالإيميل بدلاً من UID
  Future<String> getOrCreateCustomerId() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("User must be logged in to get or create a customer ID.");
    }

    if (user.email == null || user.email!.isEmpty) {
      throw Exception("User must have an email address.");
    }

    // ⭐⭐ التعديل الرئيسي: استخدام الإيميل كمعرف بدلاً من UID ⭐⭐
    final userEmail = user.email!;
    final userDocRef = _firestore.collection(usersCollection).doc(userEmail);

    // 1. محاولة قراءة البيانات الحالية
    final docSnapshot = await userDocRef.get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data();
      final existingId = data?['customer_id'] as String?;

      if (existingId != null) {
        print('🟢 [UserService] Retrieved existing customer ID from Firestore: $existingId');
        return existingId;
      }
    }

    // 2. إذا لم يكن المستند موجوداً أو لم يكن يحتوي على customer_id، ننشئ واحداً جديداً
    final newCustomerId = _uuid.v4();

    // البيانات التي سيتم حفظها في Firestore
    final userData = {
      'customer_id': newCustomerId,
      'email': userEmail,
      'uid': user.uid, // ⭐ نخزن الـ UID كمجرد بيانات إضافية
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
    };

    // حفظ أو تحديث المستند في Firestore
    await userDocRef.set(userData, SetOptions(merge: true));

    print('✨ [UserService] Generated and saved NEW customer ID to Firestore for email: $userEmail');

    return newCustomerId;
  }

  /// 🔍 دالة مساعدة للبحث عن بيانات مستخدم بالإيميل
  Future<Map<String, dynamic>?> getUserDataByEmail(String email) async {
    try {
      final doc = await _firestore.collection(usersCollection).doc(email).get();
      return doc.data();
    } catch (e) {
      print('❌ Error getting user data by email: $e');
      return null;
    }
  }

  /// 🔄 ربط بيانات مستخدم قديم بحساب جديد (بنفس الإيميل)
  Future<void> linkOldAccountData(String email, String oldPassword) async {
    try {
      // 1. محاولة تسجيل الدخول بالإيميل والرقم السري القديم
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: oldPassword,
      );

      // 2. إذا نجح التسجيل، البيانات ستظهر تلقائياً
      print('🟢 تم ربط البيانات القديمة بنجاح');

    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        throw Exception('الإيميل أو كلمة المرور غير صحيحة');
      } else {
        throw Exception('فشل في ربط البيانات: ${e.message}');
      }
    }
  }

  /// 🔍 التحقق مما إذا كان هناك بيانات قديمة لهذا الإيميل
  Future<bool> hasOldAccountData(String email) async {
    try {
      final userData = await getUserDataByEmail(email);
      return userData != null && userData['customer_id'] != null;
    } catch (e) {
      return false;
    }
  }
}