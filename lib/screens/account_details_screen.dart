import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../widgets/add_transaction_dialog.dart';

class AccountDetailsScreen extends StatefulWidget {
  final String accountName;
  final String partyType;

  const AccountDetailsScreen({
    super.key,
    required this.accountName,
    required this.partyType,
  });

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  bool _isMultiSelectionMode = false;
  Set<String> _selectedTransactionIds = {};
  final ScrollController _scrollController = ScrollController();
  List<Transaction> _currentTransactions = [];
  List<Transaction> _filteredTransactions = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadTransactions();
  }

  void _loadTransactions() {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    _updateTransactions(provider);
    provider.addListener(_onProviderUpdate);
  }

  void _onProviderUpdate() {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    _updateTransactions(provider);
  }

  void _updateTransactions(TransactionProvider provider) {
    final newTransactions = provider.transactions
        .where((t) => t.title == widget.accountName && t.partyType == widget.partyType)
        .toList();

    if (_needUpdate(_currentTransactions, newTransactions)) {
      setState(() {
        _currentTransactions = newTransactions;
        _filterTransactions();
      });
    }
  }

  bool _needUpdate(List<Transaction> oldList, List<Transaction> newList) {
    if (oldList.length != newList.length) return true;

    for (int i = 0; i < oldList.length; i++) {
      if (oldList[i].id != newList[i].id ||
          oldList[i].amount != newList[i].amount ||
          oldList[i].category != newList[i].category ||
          oldList[i].date != newList[i].date) {
        return true;
      }
    }

    return false;
  }

  void _onSearchChanged() {
    _filterTransactions();
  }

  void _filterTransactions() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _filteredTransactions = List.from(_currentTransactions);
      });
      return;
    }

    setState(() {
      _filteredTransactions = _currentTransactions.where((transaction) {
        final categoryMatch = transaction.category.toLowerCase().contains(query);
        final notesMatch = transaction.notes?.toLowerCase().contains(query) ?? false;
        final amountMatch = transaction.amount.toString().contains(query);

        return categoryMatch || notesMatch || amountMatch;
      }).toList();
    });
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _filteredTransactions = List.from(_currentTransactions);
    });
  }

  void _exitMultiSelectionMode() {
    setState(() {
      _isMultiSelectionMode = false;
      _selectedTransactionIds.clear();
    });
  }

  void _enterMultiSelectionMode() {
    setState(() {
      _isMultiSelectionMode = true;
    });
  }

  void _toggleSelection(Transaction transaction) {
    if (transaction.id == null) return;

    setState(() {
      final String transactionId = transaction.id!.toString();

      if (_selectedTransactionIds.contains(transactionId)) {
        _selectedTransactionIds.remove(transactionId);
      } else {
        _selectedTransactionIds.add(transactionId);
      }

      if (_selectedTransactionIds.isEmpty) {
        _isMultiSelectionMode = false;
      } else if (!_isMultiSelectionMode) {
        _isMultiSelectionMode = true;
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedTransactionIds = _filteredTransactions
          .where((t) => t.id != null)
          .map((t) => t.id!.toString())
          .toSet();
      if (!_isMultiSelectionMode) {
        _isMultiSelectionMode = true;
      }
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedTransactionIds.clear();
      _isMultiSelectionMode = false;
    });
  }

  Future<bool> _onWillPop() async {
    if (_isSearching) {
      _stopSearch();
      return false;
    }
    if (_isMultiSelectionMode) {
      _exitMultiSelectionMode();
      return false;
    }
    return true;
  }

  void _deleteSelectedTransactions(BuildContext context) async {
    if (_selectedTransactionIds.isEmpty) return;

    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final count = _selectedTransactionIds.length;

    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العمليات المحددة'),
        content: Text('هل أنت متأكد من حذف $count عملية؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        for (String id in _selectedTransactionIds) {
          await provider.deleteTransaction(int.parse(id));
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف $count عملية بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        _exitMultiSelectionMode();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء الحذف'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void showTransactionDialog(BuildContext context, {Transaction? transaction}) {
    showDialog(
      context: context,
      builder: (ctx) => AddTransactionDialog(
        partyType: widget.partyType,
        initialAccountName: widget.accountName,
        transactionToEdit: transaction,
        showPhoneField: false,
      ),
    ).then((_) {
      _onProviderUpdate();
    });
  }

  Future<String?> _getPhoneNumber(BuildContext context) {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    return provider.fetchAccountPhoneNumber(widget.accountName, widget.partyType);
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  Future<void> _sendWhatsApp(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    final numberWithCountryCode = cleanNumber.startsWith('0') ? '20' + cleanNumber.substring(1) : cleanNumber;

    final url = Uri.parse('https://wa.me/$numberWithCountryCode');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ رقم الهاتف بنجاح.')),
    );
  }

  void _showExportOptionsDialog(BuildContext context) {
    final transactionsToExport = _isMultiSelectionMode && _selectedTransactionIds.isNotEmpty
        ? _filteredTransactions.where((t) => _selectedTransactionIds.contains(t.id.toString())).toList()
        : _filteredTransactions;

    final int count = transactionsToExport.length;

    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد عمليات لتصديرها.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تصدير العمليات'),
        content: Text('سيتم تصدير $count عملية كملف PDF.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _exportToPdf(context, transactionsToExport);
            },
            child: const Text('تصدير PDF'),
          ),
        ],
      ),
    );
  }

  Color _getBalanceColor(double balance) {
    return balance >= 0 ? Colors.green : Colors.red;
  }

  Future<void> _exportToPdf(BuildContext context, List<Transaction> transactionsToExport) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جارٍ إنشاء ملف PDF...')),
    );

    try {
      final pdf = pw.Document();

      // 1. تحميل خط Alfares للغة العربية (مهم جداً)
      final fontData = await rootBundle.load('assets/fonts/Alfares.ttf');
      final alfareesFont = pw.Font.ttf(fontData);

      // 2. حساب الرصيد الجاري والبيانات
      final balanceData = _calculateRunningBalance(transactionsToExport);
      final sortedDataForPdf = balanceData.reversed.toList(); // عرض الأحدث أولاً في الجدول

      // 3. رؤوس الجدول
      final headers = [
        'الرصيد', // الرصيد الجاري
        'المبلغ',
        'البيان',
        'التاريخ',
        'النوع',
      ];

      // 4. دالة لتحويل لون Flutter إلى لون PdfColor
      PdfColor _getpdfColor(Color color) {
        return PdfColor.fromInt(color.value);
      }

      // 5. البيانات مع تنسيق الألوان
      final data = sortedDataForPdf.map((item) {
        final t = item['transaction'] as Transaction;
        final currentBalance = item['currentBalance'] as double;
        final amount = t.amount;
        final isIncome = t.type == 'Income';

        // تحديد لون المبلغ: أخضر للدخل/له، أحمر للمصروف/عليه
        final amountColor = isIncome ? _getpdfColor(Colors.green.shade700) : _getpdfColor(Colors.red.shade700);

        // **تصحيح الخطأ:** استخدام PdfColors.green900/red900 بدلاً من darken()
        final balanceTextColor = currentBalance >= 0 ? PdfColors.green900 : PdfColors.red900;

        // تحديد مصطلح النوع (له/عليه)
        final typeText = isIncome ? 'له' : 'عليه';
        final typeColor = isIncome ? PdfColors.green700 : PdfColors.red700;


        return [
          // عمود الرصيد الجاري
          pw.Text(
            _formatNumberForDisplay(currentBalance),
            textDirection: pw.TextDirection.ltr,
            style: pw.TextStyle(
              font: alfareesFont,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: balanceTextColor,
            ),
          ),

          // عمود المبلغ (مع علامة + أو - والتنسيق اللوني)
          pw.Text(
            '${isIncome ? '+' : '-'}${_formatNumberForDisplay(amount)}',
            textDirection: pw.TextDirection.ltr,
            style: pw.TextStyle(
              font: alfareesFont,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: amountColor,
            ),
          ),

          // عمود البيان
          pw.Text(
            t.notes ?? t.category,
            style: pw.TextStyle(font: alfareesFont, fontSize: 10),
          ),

          // عمود التاريخ
          pw.Text(
            DateFormat('yyyy/MM/dd HH:mm').format(t.date),
            textDirection: pw.TextDirection.ltr,
            style: pw.TextStyle(font: alfareesFont, fontSize: 10, color: PdfColors.grey700),
          ),

          // عمود النوع (له / عليه)
          pw.Text(
            typeText,
            style: pw.TextStyle(
              font: alfareesFont,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: typeColor,
            ),
          ),
        ];
      }).toList();


      // 6. إضافة الصفحة والمحتوى
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            final finalBalance = _calculateBalance(transactionsToExport);

            // **تصحيح الخطأ:** استخدام الألوان المعرفة مسبقاً
            final finalBackgroundColor = finalBalance >= 0 ? PdfColors.green100 : PdfColors.red100;
            final finalTextColor = finalBalance >= 0 ? PdfColors.green900 : PdfColors.red900;

            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'كشف حساب: ${widget.accountName}',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      font: alfareesFont,
                      color: _getpdfColor(Color(0xFF0D47A1)),
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'نوع الحساب: ${widget.partyType == 'Customer' ? 'عميل' : 'مورد'}',
                    style: pw.TextStyle(font: alfareesFont, fontSize: 14, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 20),

                  // الجدول
                  pw.Table.fromTextArray(
                    headers: headers,
                    data: data,
                    border: pw.TableBorder.all(color: PdfColors.blueGrey100),
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      font: alfareesFont,
                      fontSize: 10,
                      color: PdfColors.white,
                    ),
                    headerDecoration: pw.BoxDecoration(color: _getpdfColor(Color(0xFF42A5F5))),
                    cellStyle: pw.TextStyle(font: alfareesFont, fontSize: 10),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2),    // الرصيد
                      1: const pw.FlexColumnWidth(1.8),  // المبلغ
                      2: const pw.FlexColumnWidth(3.5),  // البيان
                      3: const pw.FlexColumnWidth(2.7),  // التاريخ
                      4: const pw.FlexColumnWidth(1),    // النوع
                    },
                    cellAlignment: pw.Alignment.centerRight,
                    headerAlignment: pw.Alignment.center,
                  ),
                  pw.SizedBox(height: 20),

                  // الرصيد النهائي
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: finalTextColor, width: 2),
                      borderRadius: pw.BorderRadius.circular(8),
                      color: finalBackgroundColor, // لون الخلفية الفاتح
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'الرصيد النهائي (الصافي):',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            font: alfareesFont,
                            color: finalTextColor, // لون النص الداكن
                          ),
                        ),
                        pw.Text(
                          _formatNumberForDisplay(finalBalance),
                          textDirection: pw.TextDirection.ltr,
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            font: alfareesFont,
                            color: finalTextColor, // لون النص الداكن
                          ),
                        ),
                      ],
                    ),
                  ),

                  // تذييل بسيط
                  pw.Spacer(),
                  pw.Divider(color: PdfColors.grey300),
                  pw.Center(
                    child: pw.Text(
                      'تم التوليد في: ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}',
                      style: pw.TextStyle(font: alfareesFont, fontSize: 8, color: PdfColors.grey500),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // 7. حفظ ومشاركة الملف
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.accountName}_transactions.pdf');
      final bytes = await pdf.save();
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(file.path)], text: 'كشف حساب ${widget.accountName}');

      _exitMultiSelectionMode();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تصدير ومشاركة ملف PDF بنجاح.')),
      );
    } catch (e) {
      debugPrint("❌ خطأ في تصدير PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء التصدير.')),
      );
    }
  }
  List<Map<String, dynamic>> _calculateRunningBalance(List<Transaction> transactions) {
    double runningBalance = 0.0;
    List<Map<String, dynamic>> result = [];

    List<Transaction> sortedTransactions = List.from(transactions);
    sortedTransactions.sort((a, b) => a.date.compareTo(b.date));

    for (var t in sortedTransactions) {
      double previousBalance = runningBalance;

      if (t.type == 'Income') {
        runningBalance += t.amount;
      } else if (t.type == 'Expense') {
        runningBalance -= t.amount;
      }

      result.add({
        'transaction': t,
        'previousBalance': previousBalance,
        'currentBalance': runningBalance,
      });
    }

    return result;
  }

  Map<String, double> _calculateDebitCredit() {
    double totalDebit = 0.0;
    double totalCredit = 0.0;

    for (var t in _currentTransactions) {
      if (t.type == 'Expense') {
        totalDebit += t.amount;
      } else if (t.type == 'Income') {
        totalCredit += t.amount;
      }
    }

    return {
      'debit': totalDebit,
      'credit': totalCredit,
    };
  }

  // دالة مساعدة للحصول على حجم الخط المناسب
  double _getFontSize(double small, double normal, bool isSmallScreen) {
    // زيادة جميع الأحجام بمقدار 2 نقطة تقريباً
    return isSmallScreen ? small + 1 : normal + 2;
  }

  // دالة مساعدة للحصول على flex value مناسب
  int _getFlexValue(int normal, bool isSmallScreen) {
    return isSmallScreen ? normal - 1 : normal;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, child) {
        _updateTransactions(provider);

        final balanceData = _calculateRunningBalance(_filteredTransactions);
        final reversedBalanceData = balanceData.reversed.toList();

        final double accountBalance = _calculateBalance(_currentTransactions);
        final Color balanceColor = _getBalanceColor(accountBalance);

        final debitCredit = _calculateDebitCredit();

        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 360;

        return WillPopScope(
          onWillPop: _onWillPop,
          child: Scaffold(
            appBar: AppBar(
              title: _isSearching
                  ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ابحث في الوصف أو المبلغ...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center, // ⭐ توسيط
                children: [
                  Expanded( // ⭐ يأخذ المساحة المتاحة
                    child: Text(
                      _isMultiSelectionMode
                          ? 'محدد: ${_selectedTransactionIds.length}'
                          : widget.accountName,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                      ),
                      textAlign: TextAlign.center, // ⭐ توسيط النص
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              backgroundColor: _isMultiSelectionMode
                  ? Colors.blue
                  : Color(0xFF42A5F5),
              actions: _buildAppBarActions(context),
            ),

            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFE0F2F7),
                    Color(0xFFBBDEFB),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),

              child: Column(
                children: [
                  FutureBuilder<String?>(
                    future: _getPhoneNumber(context),
                    builder: (ctx, snapshot) {
                      final String? phoneNumber = snapshot.data;
                      if (phoneNumber != null && phoneNumber.isNotEmpty) {
                        return _buildCompactPhoneCard(context, phoneNumber, isSmallScreen);
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  if (_isMultiSelectionMode) _buildSelectionActions(context, isSmallScreen),

                  _buildTableHeader(isSmallScreen),

                  if (_isSearching && _searchController.text.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      color: Colors.blue.shade50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, size: isSmallScreen ? 14 : 16, color: Colors.blue.shade700),
                          SizedBox(width: isSmallScreen ? 6 : 8),
                          Text(
                            'تم العثور على ${_filteredTransactions.length} عملية',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 11 : 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),

                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: _filteredTransactions.isEmpty
                              ? Center(
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isSearching ? Icons.search_off : Icons.receipt_long,
                                      size: isSmallScreen ? 48 : 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _isSearching
                                          ? 'لم يتم العثور على عمليات تطابق "${_searchController.text}"'
                                          : 'لا توجد معاملات مسجلة لحساب ${widget.accountName}.',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 14 : 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (_isSearching) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'جرب البحث في: الوصف، الملاحظات، أو المبلغ',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 10 : 12,
                                          color: Colors.grey.shade500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          )
                              : ListView.builder(
                            controller: _scrollController,
                            itemCount: reversedBalanceData.length,
                            itemBuilder: (ctx, i) {
                              final data = reversedBalanceData[i];
                              return _buildTransactionTile(
                                data['transaction'],
                                data['previousBalance'],
                                data['currentBalance'],
                                context,
                                showTransactionDialog,
                                isSmallScreen,
                              );
                            },
                          ),
                        ),

                        _buildBottomBalanceCard(accountBalance, debitCredit, balanceColor, isSmallScreen),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            floatingActionButton: _buildFloatingActionButton(context, balanceColor),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,          ),
        );
      },
    );
  }

  Widget _buildCompactPhoneCard(BuildContext context, String phoneNumber, bool isSmallScreen) {
    return Card(
      margin: EdgeInsets.all(isSmallScreen ? 6 : 8),
      color: Colors.blue.shade50,
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.phone, size: isSmallScreen ? 18 : 20, color: Colors.blue.shade700),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Expanded(
                    child: Text(
                      phoneNumber,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.call, size: isSmallScreen ? 20 : 22, color: Colors.green.shade700),
                  tooltip: 'اتصال',
                  onPressed: () => _makePhoneCall(phoneNumber),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36),
                ),
                IconButton(
                  icon: Icon(FontAwesomeIcons.whatsapp, color: Colors.green.shade600, size: isSmallScreen ? 18 : 20),
                  tooltip: 'واتساب',
                  onPressed: () => _sendWhatsApp(phoneNumber),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36),
                ),
                IconButton(
                  icon: Icon(Icons.copy, size: isSmallScreen ? 18 : 20, color: Colors.grey),
                  tooltip: 'نسخ الرقم',
                  onPressed: () => _copyToClipboard(context, phoneNumber),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBalanceCard(
      double balance,
      Map<String, double> debitCredit,
      Color color,
      bool isSmallScreen,
      ) {
    final bool isCredit = balance >= 0;
    final Color balanceColor = isCredit ? Colors.green : Colors.red;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 12,
        vertical: isSmallScreen ? 6 : 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // الرصيد الصافي - زيادة السماكة والحجم
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'الرصيد الصافي: ',
                      style: TextStyle(
                        fontSize: _getFontSize(16, 18, isSmallScreen),
                        fontWeight: FontWeight.w900,
                        color: balanceColor,
                      ),
                    ),
                    Text(
                      _formatNumberForDisplay(balance.abs()),
                      style: TextStyle(
                        fontSize: _getFontSize(18, 22, isSmallScreen),
                        fontWeight: FontWeight.w900,
                        color: balanceColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // إجمالي الدائن والمدين
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'إجمالي الدائن',
                            style: TextStyle(
                              fontSize: _getFontSize(12, 14, isSmallScreen),
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            _formatNumberForDisplay(debitCredit['credit']!.abs()),
                            style: TextStyle(
                              fontSize: _getFontSize(14, 16, isSmallScreen),
                              fontWeight: FontWeight.w900,
                              color: Colors.green.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    Container(
                      width: 1,
                      height: 25,
                      color: Colors.white.withOpacity(0.3),
                    ),

                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'إجمالي المدين',
                            style: TextStyle(
                              fontSize: _getFontSize(12, 14, isSmallScreen),
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            _formatNumberForDisplay(debitCredit['debit']!.abs()),
                            style: TextStyle(
                              fontSize: _getFontSize(14, 16, isSmallScreen),
                              fontWeight: FontWeight.w900,
                              color: Colors.red.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 6 : 8,
        vertical: isSmallScreen ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: const Border(
          bottom: BorderSide(color: Colors.blue, width: 2),
        ),
      ),
      child: Row(
        children: [
          // الرصيد بعد
          Expanded(
            flex: _getFlexValue(2, isSmallScreen),
            child: Text(
              'الرصيد',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: _getFontSize(12, 14, isSmallScreen),
                color: Colors.blue.shade800,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // الوصف
          Expanded(
            flex: _getFlexValue(3, isSmallScreen),
            child: Text(
              'الوصف',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: _getFontSize(12, 14, isSmallScreen),
                color: Colors.blue.shade800,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // المبلغ
          Expanded(
            flex: _getFlexValue(2, isSmallScreen),
            child: Text(
              'المبلغ',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: _getFontSize(12, 14, isSmallScreen),
                color: Colors.blue.shade800,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // التاريخ
          Expanded(
            flex: _getFlexValue(3, isSmallScreen),
            child: Text(
              'التاريخ',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: _getFontSize(12, 14, isSmallScreen),
                color: Colors.blue.shade800,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // مكان فارغ لأيقونة التحديد
          if (_isMultiSelectionMode)
            Container(width: isSmallScreen ? 20 : 24),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    if (_isSearching) {
      return [
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _stopSearch,
        ),
      ];
    } else if (_isMultiSelectionMode) {
      return [
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _exitMultiSelectionMode,
        ),
      ];
    } else {
      return [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: _startSearch,
          tooltip: 'بحث في العمليات',
        ),
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white),
          onPressed: () => _showExportOptionsDialog(context),
          tooltip: 'تصدير',
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'add_transaction':
                showTransactionDialog(context);
                break;
              case 'select_all':
                _selectAll();
                break;
              case 'multi_select':
                _enterMultiSelectionMode();
                break;
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(
              value: 'add_transaction',
              child: Row(
                children: [
                  Icon(Icons.add, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('إضافة عملية'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'select_all',
              child: Row(
                children: [
                  Icon(Icons.select_all, color: Colors.green),
                  SizedBox(width: 8),
                  Text('تحديد الكل'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'multi_select',
              child: Row(
                children: [
                  Icon(Icons.check_box, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('وضع التحديد المتعدد'),
                ],
              ),
            ),
          ],
        ),
      ];
    }
  }

  Widget _buildSelectionActions(BuildContext context, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: isSmallScreen ? 6 : 8,
      ),
      color: Colors.blue.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.delete, size: isSmallScreen ? 20 : 24, color: Colors.red),
                onPressed: _selectedTransactionIds.isNotEmpty
                    ? () => _deleteSelectedTransactions(context)
                    : null,
                tooltip: 'حذف المحدد',
              ),
              IconButton(
                icon: Icon(Icons.share, size: isSmallScreen ? 20 : 24, color: Colors.blue),
                onPressed: _selectedTransactionIds.isNotEmpty
                    ? () => _showExportOptionsDialog(context)
                    : null,
                tooltip: 'تصدير المحدد',
              ),
            ],
          ),
          Row(
            children: [
              TextButton(
                onPressed: _selectAll,
                child: Text(
                  'تحديد الكل',
                  style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                ),
              ),
              TextButton(
                onPressed: _deselectAll,
                child: Text(
                  'إلغاء الكل',
                  style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: FloatingActionButton(
        onPressed: () => showTransactionDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTransactionTile(
      Transaction t,
      double previousBalance,
      double currentBalance,
      BuildContext context,
      void Function(BuildContext, {Transaction? transaction}) showDialogCallback,
      bool isSmallScreen,
      ) {
    final bool isIncome = t.type == 'Income';
    final Color color = isIncome ? Colors.green.shade700 : Colors.red.shade700;

    final isSelected = _selectedTransactionIds.contains(t.id.toString());

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 4 : 6,
        vertical: isSmallScreen ? 2 : 3,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(6),
        color: isSelected ? color.withOpacity(0.3) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_isMultiSelectionMode) {
              _toggleSelection(t);
            } else {
              showDialogCallback(context, transaction: t);
            }
          },
          onLongPress: () => _toggleSelection(t),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 6 : 8,
              vertical: isSmallScreen ? 8 : 10,
            ),
            child: Row(
              children: [
                // الرصيد بعد
                Expanded(
                  flex: _getFlexValue(2, isSmallScreen),
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 2),
                    padding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: currentBalance >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: currentBalance >= 0 ? Colors.green.shade200 : Colors.red.shade200,
                        width: 1,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _formatNumberForDisplay(currentBalance.abs()),
                        style: TextStyle(
                          fontSize: _getFontSize(11, 13, isSmallScreen),
                          fontWeight: FontWeight.w900,
                          color: currentBalance >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),

                // الوصف
                Expanded(
                  flex: _getFlexValue(3, isSmallScreen),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Center(
                      child: Text(
                        t.notes?.isNotEmpty == true ? t.notes! : t.category,
                        style: TextStyle(
                          fontSize: _getFontSize(12, 14, isSmallScreen),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),

                // المبلغ
                Expanded(
                  flex: _getFlexValue(2, isSmallScreen),
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 2),
                    padding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: color.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _formatNumberForDisplay(t.amount.abs()),
                        style: TextStyle(
                          fontSize: _getFontSize(12, 14, isSmallScreen),
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),

                // التاريخ والوقت - تم تصغير الحجم فقط
                // التاريخ والوقت - حجم صغير ولكن بولد سميك
                Expanded(
                  flex: _getFlexValue(3, isSmallScreen),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('yyyy/MM/dd').format(t.date),
                          style: TextStyle(
                            fontSize: _getFontSize(9, 11, isSmallScreen), // حجم صغير
                            fontWeight: FontWeight.w900, // بولد سميك
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          DateFormat('HH:mm').format(t.date),
                          style: TextStyle(
                            fontSize: _getFontSize(7, 9, isSmallScreen), // حجم صغير
                            fontWeight: FontWeight.w900, // بولد سميك
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                // أيقونة التحديد
                if (_isMultiSelectionMode && t.id != null)
                  Container(
                    width: isSmallScreen ? 20 : 24,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(t),
                      activeColor: color,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _calculateBalance(List<Transaction> transactions) {
    double balance = 0.0;
    for (var t in transactions) {
      if (t.type == 'Income') {
        balance += t.amount;
      } else if (t.type == 'Expense') {
        balance -= t.amount;
      }
    }
    return balance;
  }

  // تحديث دالة التنسيق لإزالة العلامات نهائياً
  String _formatNumberForDisplay(double number) {
    // استخدام abs() لإزالة الإشارة السالبة
    double absoluteNumber = number.abs();

    if (absoluteNumber == absoluteNumber.truncateToDouble()) {
      return NumberFormat('#,##0', 'en_US').format(absoluteNumber);
    } else {
      return NumberFormat('#,##0.00', 'en_US').format(absoluteNumber);
    }
  }

  @override
  void dispose() {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    provider.removeListener(_onProviderUpdate);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}