import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../models/custom_page.dart';
import '../widgets/add_transaction_dialog.dart';
import 'settings_screen.dart';
import 'account_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ⭐ تحميل كل البيانات (المعاملات + الصفحات)
      Provider.of<TransactionProvider>(context, listen: false).fetchAllData();
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }


// ⭐ دالة مساعدة للحصول على الصفحات بشكل آمن
  List<CustomPage> get _safeCustomPages {
    final provider = Provider.of<TransactionProvider>(context, listen: true);
    return [
      CustomPage(id: 'customers', title: 'العملاء', partyType: 'Customer'),
      ...provider.customPages,
    ];
  }

  CustomPage get _currentPage {
    final pages = _safeCustomPages;
    if (_currentIndex < pages.length) {
      return pages[_currentIndex];
    } else {
      return pages.first; // العودة للصفحة الأولى إذا كان الفهرس غير صالح
    }
  }
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _searchController.clear();
    });
  }

  // ⭐ استخدام listen: false داخل دالة الحدث لتجنب خطأ Provider
  void _navigateToAddTransactionAndAccount() {
    // 🚀 نقرأ القائمة مباشرة من الـ Provider باستخدام listen: false
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final List<CustomPage> pages = [
      CustomPage(id: 'customers', title: 'العملاء', partyType: 'Customer'),
      ...provider.customPages,
    ];

    final String partyType = pages[_currentIndex].partyType;

    showDialog(
      context: context,
      builder: (ctx) => AddTransactionDialog(
        partyType: partyType,
        initialAccountName: null,
        transactionToEdit: null,
        showPhoneField: true,
      ),
    );
  }

  void _navigateToSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showEditAccountDialog(BuildContext context, String accountName, String partyType) {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => _EditAccountDialog(
        accountName: accountName,
        partyType: partyType,
        provider: provider,
      ),
    );
  }

  void _confirmAccountDeletion(BuildContext context, String accountName, String partyType, TransactionProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد حذف الحساب؟'),
        content: Text('هل أنت متأكد من حذف جميع معاملات حساب "$accountName" من فئة "$partyType"؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('حذف نهائي', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              print('🔴 HomeScreen: Starting deletion for account: $accountName, type: $partyType');

              try {
                // ✅ إضافة await و try-catch للتحقق من النتيجة
                await provider.deleteAccountAndTransactions(accountName, partyType);

                print('🔴 HomeScreen: Deletion completed successfully for $accountName.');

                // ✅ إغلاق جميع الديالوجات المفتوحة
                Navigator.of(ctx).pop(); // إغلاق ديالوج التأكيد
                Navigator.of(context).pop(); // إغلاق ديالوج التعديل

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم حذف حساب $accountName بالكامل.')),
                );
              } catch (e) {
                print('🔴 HomeScreen: Deletion failed: $e');
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('فشل في حذف الحساب: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ⭐ إضافة صفحة جديدة عبر الـ Provider
  void _addNewPage() {
    // 🚀 نقرأ القائمة الحالية باستخدام listen: false لعدم إطلاق خطأ Provider
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final List<CustomPage> pages = [
      CustomPage(id: 'customers', title: 'العملاء', partyType: 'Customer'),
      ...provider.customPages,
    ];

    showDialog(
      context: context,
      builder: (ctx) => _AddPageDialog(
        onPageAdded: (newPage) async {
          // ⭐ الحفظ في قاعدة البيانات عبر الـ Provider
          await Provider.of<TransactionProvider>(context, listen: false).addCustomPage(newPage);
        },
        existingPages: pages, // نمرر القائمة التي قرأناها بـ listen: false
      ),
    );
  }

  // ⭐ حذف صفحة عبر الـ Provider
  // ⭐ حذف صفحة عبر الـ Provider مع التحقق من الفهرس
  void _deletePage(int index) {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final List<CustomPage> pages = [
      CustomPage(id: 'customers', title: 'العملاء', partyType: 'Customer'),
      ...provider.customPages,
    ];

    // ⭐ التحقق من أن الفهرس صالح
    if (index < 0 || index >= pages.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الصفحة غير موجودة')),
      );
      return;
    }

    if (pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن حذف جميع الصفحات')),
      );
      return;
    }

    final pageToDelete = pages[index];

    // منع حذف صفحة العملاء الافتراضية
    if (pageToDelete.id == 'customers') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن حذف صفحة العملاء الأساسية')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد حذف الصفحة'),
        content: Text('هل أنت متأكد من حذف صفحة "${pageToDelete.title}"؟'),
        actions: [
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              await Provider.of<TransactionProvider>(context, listen: false)
                  .deleteCustomPage(pageToDelete.id);

              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم حذف صفحة ${pageToDelete.title}')),
              );

              // ⭐ إعادة تعيين الفهرس إذا لزم الأمر
              if (_currentIndex >= _safeCustomPages.length) {
                setState(() {
                  _currentIndex = 0;
                });
              }
            },
          ),
        ],
      ),
    );
  }
  // ⭐ دالة تعديل الصفحة عبر الـ Provider
  // ⭐ دالة تعديل الصفحة عبر الـ Provider مع التحقق من الفهرس
  void _showEditPageDialog(int index) {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final List<CustomPage> pages = [
      CustomPage(id: 'customers', title: 'العملاء', partyType: 'Customer'),
      ...provider.customPages,
    ];

    // ⭐ التحقق من أن الفهرس صالح
    if (index < 0 || index >= pages.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الصفحة غير موجودة')),
      );
      return;
    }

    final pageToEdit = pages[index];

    showDialog(
      context: context,
      builder: (ctx) => _EditPageDialog(
        page: pageToEdit,
        onPageUpdated: (updatedPage) async {
          await Provider.of<TransactionProvider>(context, listen: false)
              .updateCustomPage(updatedPage);
        },
        onPageDeleted: () {
          _deletePage(index);
        },
        existingPages: pages,
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    // 🔴 نقطة طباعة 3: عند إعادة بناء HomeScreen
    print('🔴 HomeScreen: Build method called. Current Index: $_currentIndex');

    // ⭐ التحقق من أن الفهرس الحالي صالح
    final safePages = _safeCustomPages;
    if (_currentIndex >= safePages.length && safePages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _currentIndex = 0;
        });
      });
    }

    return Scaffold(
      appBar: AppBar(
        // ⭐ استخدام _currentPage بدلاً من _customPages[_currentIndex]
        title: Text(_currentPage.title),
        centerTitle: true,
        actions: [
          if (_currentPage.id != 'customers')
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showEditPageDialog(_currentIndex),
              tooltip: 'تعديل هذه الصفحة',
            ),

          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNewPage,
            tooltip: 'إضافة صفحة جديدة',
          ),

          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _navigateToSettings,
          ),
        ],
      ),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: FloatingActionButton(
          onPressed: _navigateToAddTransactionAndAccount,
          child: const Icon(Icons.add),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

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
            _buildSearchBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                // ⭐ استخدام _safeCustomPages بدلاً من _customPages
                children: _safeCustomPages.map((page) => _CustomPageView(
                  page: page,
                  searchQuery: _searchQuery,
                  onDeletePage: () => _deletePage(_safeCustomPages.indexOf(page)),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '🔍 ابحث باسم الحساب...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------------
// الدوال المساعدة (Helper Functions)
// ----------------------------------------------------------------------------------

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

Map<String, double> _calculateGroupedBalances(List<Transaction> transactions) {
  final Map<String, double> balances = {};
  for (var t in transactions) {
    balances.putIfAbsent(t.title, () => 0.0);
    if (t.type == 'Income') {
      balances[t.title] = balances[t.title]! + t.amount;
    } else if (t.type == 'Expense') {
      balances[t.title] = balances[t.title]! - t.amount;
    }
  }
  return balances;
}

Map<String, int> _calculateTransactionCounts(List<Transaction> transactions) {
  final Map<String, int> counts = {};
  for (var t in transactions) {
    counts[t.title] = (counts[t.title] ?? 0) + 1;
  }
  return counts;
}

Map<String, double> _calculateDebitCredit(List<Transaction> transactions) {
  double totalDebit = 0.0;
  double totalCredit = 0.0;

  for (var t in transactions) {
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

Widget _buildBottomBalanceCard(
    double balance, double totalDebit, double totalCredit, BuildContext context) {
  final bool isCredit = balance >= 0;
  final Color color = isCredit ? Colors.green : Colors.red;

  return Container(
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'الرصيد الصافي: ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              balance.abs().toStringAsFixed(0),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'إجمالي الدائن',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    totalCredit.abs().toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 16,
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'إجمالي المدين',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    totalDebit.abs().toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 16,
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
  );
}

Widget _buildGroupedBalanceTile(
    BuildContext context,
    String accountName,
    double balance,
    String partyType,
    int transactionCount) {
  final bool isCredit = balance >= 0;
  final Color color = isCredit ? Colors.green.shade700 : Colors.red.shade700;
  final IconData icon =
  isCredit ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down;

  final String balanceText = balance.abs().toStringAsFixed(0);

  final homeState = context.findAncestorStateOfType<_HomeScreenState>();

  void navigateToAddTransactionForAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AddTransactionDialog(
        partyType: partyType,
        initialAccountName: accountName,
        transactionToEdit: null,
        showPhoneField: false,
      ),
    );
  }

  void navigateToAccountDetails() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => AccountDetailsScreen(
          accountName: accountName,
          partyType: partyType,
        ),
      ),
    );
  }

  void showEditAccountDialog() {
    if (homeState != null) {
      homeState._showEditAccountDialog(context, accountName, partyType);
    }
  }

  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    child: InkWell(
      onTap: navigateToAccountDetails,
      onLongPress: showEditAccountDialog,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. أيقونة نوع الحساب (السهم)
              CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 10),

              // الاسم والمبلغ ومربع العمليات في Column واحد
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- السطر الأول داخلياً: الاسم وزر الإضافة ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // الاسم
                        Expanded(
                          child: Text(
                            accountName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.end,
                            softWrap: true,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),

                        // ⭐ حاوية أيقونة الإضافة - خلفية زرقاء
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.shade700,
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add, color: Colors.white, size: 14),
                            onPressed: navigateToAddTransactionForAccount,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // --- السطر الثاني داخلياً: المبلغ ومربع العمليات ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // المبلغ
                        Expanded(
                          child: Text(
                            balanceText,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: color,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),

                        const SizedBox(width: 6),

                        // ⭐ حاوية عدد العمليات - خلفية زرقاء
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.shade700,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              transactionCount.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ----------------------------------------------------------------------------------
// View للصفحات المخصصة
// ----------------------------------------------------------------------------------

class _CustomPageView extends StatelessWidget {
  final CustomPage page;
  final String searchQuery;
  final VoidCallback onDeletePage;

  const _CustomPageView({
    required this.page,
    required this.searchQuery,
    required this.onDeletePage,
  });

  @override
  Widget build(BuildContext context) {
    // يستمع للتغييرات في المعاملات (listen: true هو الافتراضي)
    final provider = Provider.of<TransactionProvider>(context);
    final pageTransactions = provider.transactions
        .where((t) => t.partyType == page.partyType)
        .toList();

    // 🔴 نقطة طباعة 4: عند بناء الصفحة الداخلية
    print('🔴 CustomPageView: Building page "${page.title}". Total transactions found: ${pageTransactions.length}');


    final Map<String, double> groupedBalances =
    _calculateGroupedBalances(pageTransactions);

    final Map<String, int> transactionCounts =
    _calculateTransactionCounts(pageTransactions);

    // تطبيق البحث
    final filteredEntries = groupedBalances.entries.where((entry) {
      if (searchQuery.isEmpty) return true;
      return entry.key.toLowerCase().contains(searchQuery);
    }).toList();

    // 🔴 نقطة طباعة 5: عدد الحسابات المعروضة في القائمة
    print('🔴 CustomPageView: Accounts count for "${page.title}": ${filteredEntries.length}');

    final totalBalance = _calculateBalance(pageTransactions);
    final debitCredit = _calculateDebitCredit(pageTransactions);

    return Container(
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
        children: <Widget>[
          // مؤشر نتائج البحث
          if (searchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: Colors.blue.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 14, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'تم العثور على ${filteredEntries.length} حساب',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Container(
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
                  Expanded(
                    child: groupedBalances.isEmpty
                        ? const Center(
                      child: Text(
                        'لا توجد حسابات مسجلة بعد.',
                        style:
                        TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                        : filteredEntries.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'لم يتم العثور على حساب "$searchQuery"',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                        : ListView.builder(
                      itemCount: filteredEntries.length,
                      itemBuilder: (ctx, i) {
                        final entry = filteredEntries[i];
                        final transactionCount = transactionCounts[entry.key] ?? 0;
                        return _buildGroupedBalanceTile(
                          context,
                          entry.key,
                          entry.value,
                          page.partyType,
                          transactionCount,
                        );
                      },
                    ),
                  ),

                  // كرت الرصيد في الأسفل
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: _buildBottomBalanceCard(
                      totalBalance,
                      debitCredit['debit']!,
                      debitCredit['credit']!,
                      context,
                    ),
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

// ----------------------------------------------------------------------------------
// ديلوج إضافة صفحة جديدة (_AddPageDialog)
// ----------------------------------------------------------------------------------

class _AddPageDialog extends StatefulWidget {
  final Function(CustomPage) onPageAdded;
  final List<CustomPage> existingPages;

  const _AddPageDialog({
    required this.onPageAdded,
    required this.existingPages,
  });

  @override
  State<_AddPageDialog> createState() => _AddPageDialogState();
}

class _AddPageDialogState extends State<_AddPageDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submitData() {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final partyType = _generatePartyType(title);

    if (widget.existingPages.any((page) => page.title == title)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا العنوان موجود مسبقاً')),
      );
      return;
    }

    if (widget.existingPages.any((page) => page.partyType == partyType)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نوع الحساب هذا موجود مسبقاً')),
      );
      return;
    }

    final newPage = CustomPage(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      partyType: partyType,
    );

    widget.onPageAdded(newPage);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم إضافة صفحة "$title" بنجاح')),
    );
  }

  String _generatePartyType(String title) {
    String englishTitle = _convertToEnglish(title);
    return englishTitle.replaceAll(' ', '_');
  }

  String _convertToEnglish(String text) {
    Map<String, String> arabicToEnglish = {
      'العملاء': 'Customers',
      'الموردين': 'Suppliers',
      'الموظفين': 'Employees',
      'البنوك': 'Banks',
      'المشاريع': 'Projects',
      'الفروع': 'Branches',
    };

    if (arabicToEnglish.containsKey(text)) {
      return arabicToEnglish[text]!;
    }

    return text.replaceAll(' ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'إضافة صفحة جديدة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'اسم الصفحة',
                  border: OutlineInputBorder(),
                  hintText: 'مثال: الموردين, الموظفين, البنوك',
                ),
                validator: (value) =>
                value!.isEmpty ? 'اسم الصفحة مطلوب' : null,
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitData,
                      child: const Text('إضافة'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------------
// ديلوج تعديل الحساب (_EditAccountDialog)
// ----------------------------------------------------------------------------------

class _EditAccountDialog extends StatefulWidget {
  final String accountName;
  final String partyType;
  final TransactionProvider provider;

  const _EditAccountDialog({
    required this.accountName,
    required this.partyType,
    required this.provider,
  });

  @override
  State<_EditAccountDialog> createState() => _EditAccountDialogState();
}

class _EditAccountDialogState extends State<_EditAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _currentPhoneNumber;
  late Future<String?> _phoneFuture;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.accountName;

    _phoneFuture =
        widget.provider.fetchAccountPhoneNumber(widget.accountName, widget.partyType);
  }

  void _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    final newName = _nameController.text.trim();

    final newPhoneNumber = _phoneController.text.trim().isEmpty
        ? null
        : _phoneController.text.trim();

    if (newName == widget.accountName && newPhoneNumber == _currentPhoneNumber) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم إجراء أي تغيير.')),
      );
      return;
    }

    try {
      await widget.provider.updateAccountDetails(
          widget.accountName, newName, widget.partyType, newPhoneNumber
      );

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تعديل تفاصيل الحساب إلى $newName بنجاح.')),
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التعديل: $e')),
      );
    }
  }

  void _deleteAccount() {
    print('🟡 EditDialog: Delete button pressed for ${widget.accountName}');

    // استخدام root navigator للوصول إلى الـ context الصحيح
    final homeState = Navigator.of(context, rootNavigator: true)
        .context
        .findAncestorStateOfType<_HomeScreenState>();

    if (homeState != null) {
      print('🟡 EditDialog: Calling confirmation dialog');
      homeState._confirmAccountDeletion(
          context, widget.accountName, widget.partyType, widget.provider);
    } else {
      print('🔴 EditDialog: homeState is null!');
      // حل بديل: استدعاء الدالة مباشرة من الـ Provider
      _showDirectDeletionDialog();
    }
  }

// حل بديل إذا فشل الوصول إلى homeState
  void _showDirectDeletionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد حذف الحساب؟'),
        content: Text('هل أنت متأكد من حذف جميع معاملات حساب "${widget.accountName}" من فئة "${widget.partyType}"؟'),
        actions: [
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('حذف نهائي', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              print('🔴 DirectDialog: Starting deletion for account: ${widget.accountName}');

              try {
                await widget.provider.deleteAccountAndTransactions(
                    widget.accountName, widget.partyType);

                print('🔴 DirectDialog: Deletion completed successfully');

                Navigator.of(ctx).pop(); // إغلاق ديالوج التأكيد
                Navigator.of(context).pop(); // إغلاق ديالوج التعديل

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم حذف حساب ${widget.accountName} بالكامل.')),
                );
              } catch (e) {
                print('🔴 DirectDialog: Deletion failed: $e');
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('فشل في حذف الحساب: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(15.0),
          child: Form(
            key: _formKey,
            child: FutureBuilder<String?>(
              future: _phoneFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  _currentPhoneNumber = snapshot.data;

                  // ⭐ الإصلاح: تأجيل تعيين قيمة Controller حتى بعد اكتمال البناء
                  if (_phoneController.text.isEmpty && _currentPhoneNumber != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _phoneController.text = _currentPhoneNumber!;
                    });
                  }
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _buildHeader(),
                    const SizedBox(height: 10),

                    _buildTextField(
                      controller: _nameController,
                      label: 'اسم الحساب',
                      icon: Icons.person,
                      keyboardType: TextInputType.text,
                      validator: (value) =>
                      value!.isEmpty ? 'اسم الحساب مطلوب' : null,
                    ),
                    const SizedBox(height: 10),

                    _buildTextField(
                      controller: _phoneController,
                      label: 'رقم الهاتف (اختياري)',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: null,
                    ),

                    if (snapshot.connectionState == ConnectionState.waiting)
                      const LinearProgressIndicator(),

                    const SizedBox(height: 20),

                    _buildSaveButton(),
                    const SizedBox(height: 10),

                    _buildDeleteButton(), // زر حذف الحساب
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.person_outline, color: Colors.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'تعديل حساب: ${widget.accountName}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextInputType keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 16, height: 1.5),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        border: InputBorder.none,
        enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.blue, width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
      ),
      validator: validator,
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: _submitData,
      icon: const Icon(Icons.save, color: Colors.white),
      label: const Text('حفظ التعديلات',
          style: TextStyle(color: Colors.white, fontSize: 18)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return TextButton.icon(
      onPressed: _deleteAccount,
      icon: const Icon(Icons.delete_forever, color: Color(0xFFC62828)),
      label: const Text('حذف الحساب والمعاملات',
          style: TextStyle(color: Color(0xFFC62828), fontSize: 16)),
    );
  }
}

// ----------------------------------------------------------------------------------
// ديلوج تعديل الصفحة (_EditPageDialog)
// ----------------------------------------------------------------------------------

class _EditPageDialog extends StatefulWidget {
  final CustomPage page;
  final Function(CustomPage) onPageUpdated;
  final VoidCallback onPageDeleted;
  final List<CustomPage> existingPages;

  const _EditPageDialog({
    required this.page,
    required this.onPageUpdated,
    required this.onPageDeleted,
    required this.existingPages,
  });

  @override
  State<_EditPageDialog> createState() => _EditPageDialogState();
}

class _EditPageDialogState extends State<_EditPageDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.page.title;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submitData() {
    if (!_formKey.currentState!.validate()) return;

    final newTitle = _titleController.text.trim();

    // التحقق من عدم وجود عنوان مكرر (باستثناء الصفحة الحالية)
    if (widget.existingPages.any((page) =>
    page.title == newTitle && page.id != widget.page.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا العنوان موجود مسبقاً')),
      );
      return;
    }

    final updatedPage = CustomPage(
      id: widget.page.id,
      title: newTitle,
      partyType: widget.page.partyType,
    );

    widget.onPageUpdated(updatedPage);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تعديل صفحة "$newTitle" بنجاح')),
    );
  }

  void _deletePage() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد حذف الصفحة'),
        content: Text('هل أنت متأكد من حذف صفحة "${widget.page.title}"؟'),
        actions: [
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.of(ctx).pop(); // إغلاق ديالوج التأكيد
              Navigator.of(context).pop(); // إغلاق ديالوج التعديل
              widget.onPageDeleted(); // استدعاء دالة الحذف
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'تعديل الصفحة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'اسم الصفحة',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                value!.isEmpty ? 'اسم الصفحة مطلوب' : null,
              ),
              const SizedBox(height: 24),

              // أزرار الحفظ والحذف
              Row(
                children: [
                  // زر الحذف
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _deletePage,
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('حذف', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // زر الإلغاء
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // زر الحفظ
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitData,
                      child: const Text('حفظ'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}