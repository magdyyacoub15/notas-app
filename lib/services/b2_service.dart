import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'b2_config.dart';

class B2Service {
  String? apiUrl;
  String? downloadUrl;
  String? authToken;
  String? bucketId;

  B2Service() {
    // تعيين bucketId من ملف الإعدادات
    bucketId = B2Config.bucketId;
  }

  // ------------------------------------------
  // 1️⃣ تسجيل الدخول Backblaze (authorize)
  // ------------------------------------------
  Future<void> authorizeAccount() async {
    final keyId = B2Config.keyId;
    final applicationKey = B2Config.applicationKey;
    final basicAuth = base64Encode(utf8.encode("$keyId:$applicationKey"));

    final uri = Uri.parse("https://api.backblazeb2.com/b2api/v2/b2_authorize_account");

    print("🔵 [B2Service] Authorizing account...");

    final response = await http.get(
      uri,
      headers: {
        "Authorization": "Basic $basicAuth",
      },
    );

    if (response.statusCode != 200) {
      print("❌ [B2Service] Authorization failed: ${response.statusCode} ${response.body}");
      throw Exception("Authorization Failed: ${response.body}");
    }

    final data = jsonDecode(response.body);
    apiUrl = data["apiUrl"] as String?;
    downloadUrl = data["downloadUrl"] as String?;
    authToken = data["authorizationToken"] as String?;

    print("🟢 [B2Service] Authorized.");
  }

  // ------------------------------------------
  // 2️⃣ الحصول على Upload URL
  // ------------------------------------------
  Future<Map<String, dynamic>> _getUploadUrl() async {
    if (apiUrl == null || authToken == null) {
      await authorizeAccount();
    }

    final uri = Uri.parse("${apiUrl!}/b2api/v2/b2_get_upload_url");

    final res = await http.post(
      uri,
      headers: {
        "Authorization": authToken!,
        "Content-Type": "application/json",
      },
      body: jsonEncode({"bucketId": bucketId}),
    );

    if (res.statusCode != 200) {
      print("❌ [B2Service] b2_get_upload_url failed: ${res.statusCode} ${res.body}");
      throw Exception("b2_get_upload_url failed: ${res.body}");
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // حساب SHA1 لبايتس الملف
  String _sha1OfBytes(List<int> bytes) {
    final digest = sha1.convert(bytes);
    return digest.toString();
  }

  // ------------------------------------------
  // 3️⃣ رفع ملف
  // ------------------------------------------
  Future<bool> uploadFile({
    required String filePath,
    required String fileName,
  }) async {
    if (apiUrl == null || authToken == null) {
      await authorizeAccount();
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception("Local file not found: $filePath");
    }

    final bytes = await file.readAsBytes();

    final uploadInfo = await _getUploadUrl();
    final uploadUrl = uploadInfo["uploadUrl"] as String;
    final uploadAuth = uploadInfo["authorizationToken"] as String;

    final res = await http.post(
      Uri.parse(uploadUrl),
      headers: {
        "Authorization": uploadAuth,
        "X-Bz-File-Name": fileName,
        "Content-Type": "b2/x-auto", // يحدد النوع تلقائياً
        "Content-Length": bytes.length.toString(),
        "X-Bz-Content-Sha1": _sha1OfBytes(bytes),
      },
      body: bytes,
    );

    if (res.statusCode == 200) {
      print("🟢 [B2Service] uploadFile succeeded.");
      return true;
    } else {
      print("❌ [B2Service] uploadFile failed: ${res.statusCode} ${res.body}");
      return false;
    }
  }

  // ------------------------------------------
  // 4️⃣ جلب قائمة الملفات داخل فولدر (prefix) - تم التعديل لجلب fileId
  // ------------------------------------------
  Future<List<Map<String, dynamic>>> listFiles({required String prefix}) async {
    if (apiUrl == null || authToken == null) {
      await authorizeAccount();
    }

    final uri = Uri.parse("${apiUrl!}/b2api/v2/b2_list_file_names");

    final res = await http.post(
      uri,
      headers: {
        "Authorization": authToken!,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "bucketId": bucketId,
        "prefix": prefix,
        "maxFileCount": 1000,
      }),
    );

    if (res.statusCode != 200) {
      print("❌ [B2Service] b2_list_file_names failed: ${res.statusCode} ${res.body}");
      return [];
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final files = (data["files"] as List<dynamic>).cast<Map<String, dynamic>>();

    // إعادة القائمة مع حقول بسيطة (الآن تتضمن fileId)
    return files.map((f) {
      return {
        "fileName": f["fileName"] as String,
        "uploadTimestamp": f["uploadTimestamp"] ?? 0,
        "fileId": f["fileId"] as String, // 🌟 إضافة حقل fileId
      };
    }).toList();
  }

  // ------------------------------------------
  // 5️⃣ تحميل ملف من Backblaze
  // ------------------------------------------
  Future<Uint8List?> downloadFile(String fileName) async {
    if (downloadUrl == null || authToken == null) {
      await authorizeAccount();
    }

    final bucketName = B2Config.bucketName;
    final encodedFileName = Uri.encodeComponent(fileName);

    final url = "${downloadUrl!}/file/$bucketName/$encodedFileName";
    print("🔵 [B2Service] downloadFile URL: $url");

    final res = await http.get(
      Uri.parse(url),
      headers: {
        // نستخدم authToken لأن الـ Bucket الخاص بك يفترض أنه Private
        if (authToken != null) "Authorization": authToken!,
      },
    );

    if (res.statusCode == 200) {
      print("🟢 [B2Service] downloadFile succeeded.");
      return res.bodyBytes;
    } else {
      print("❌ [B2Service] downloadFile failed: ${res.statusCode} ${res.body}");
      return null;
    }
  }

  // ------------------------------------------
  // 6️⃣ حذف ملف (نسخة احتياطية) 🌟 الدالة الجديدة 🌟
  // ------------------------------------------
  Future<bool> deleteFile({required String fileName, required String fileId}) async {
    if (apiUrl == null || authToken == null) {
      await authorizeAccount();
    }

    final uri = Uri.parse("${apiUrl!}/b2api/v2/b2_delete_file_version");

    final res = await http.post(
      uri,
      headers: {
        "Authorization": authToken!,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "fileName": fileName,
        "fileId": fileId,
      }),
    );

    if (res.statusCode == 200) {
      print("🟢 [B2Service] deleteFile succeeded for $fileName.");
      return true;
    } else {
      print("❌ [B2Service] deleteFile failed: ${res.statusCode} ${res.body}");
      return false;
    }
  }
}