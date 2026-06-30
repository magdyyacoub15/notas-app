import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';

class AddTransactionDialog extends StatefulWidget {
  final String partyType;
  final String? initialAccountName;
  final Transaction? transactionToEdit;
  final bool showPhoneField;

  const AddTransactionDialog({
    super.key,
    required this.partyType,
    this.initialAccountName,
    this.transactionToEdit,
    this.showPhoneField = false,
  });

  @override
  State<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _detailsController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedType = 'Expense';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.transactionToEdit != null) {
      final t = widget.transactionToEdit!;
      _titleController.text = t.title;
      _amountController.text = t.amount.toString();
      _selectedType = t.type;
      _selectedDate = t.date;
      _detailsController.text = t.category;
      _phoneController.text = t.phoneNumber ?? '';
    } else if (widget.initialAccountName != null) {
      _titleController.text = widget.initialAccountName!;
    }
  }

  void _presentDateTimePicker() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );

    if (pickedDate == null) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );

    if (pickedTime == null) return;

    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    final type = _selectedType == 'Expense' ? 'Expense' : 'Income';

    final double amountValue = double.parse(_amountController.text.trim());
    final String title = _titleController.text.trim();
    final String detailsText = _detailsController.text.trim();

    final String categoryValue = detailsText.isEmpty
        ? 'لا توجد تفاصيل'
        : detailsText;

    final String? phoneNumberValue = widget.showPhoneField && _phoneController.text.trim().isNotEmpty
        ? _phoneController.text.trim()
        : null;

    final transactionData = Transaction(
      id: widget.transactionToEdit?.id,
      category: categoryValue,
      title: title,
      amount: amountValue,
      type: type,
      date: _selectedDate,
      partyType: widget.partyType,
      notes: detailsText,
      phoneNumber: phoneNumberValue,
    );

    final provider = Provider.of<TransactionProvider>(context, listen: false);

    try {
      if (widget.transactionToEdit != null) {
        await provider.updateTransaction(transactionData);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تعديل المعاملة بنجاح.')),
        );
      } else {
        await provider.addTransaction(transactionData);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تسجيل المعاملة لحساب ${widget.partyType}.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في حفظ المعاملة. يرجى التأكد من تشغيل التطبيق مجدداً: $e')),
      );
    }
  }

  // 🌟 الدالة المعدلة مع تأكيد الحذف
  void _deleteTransaction() async {
    final bool confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
            'هل أنت متأكد من حذف هذه المعاملة؟\nالمبلغ: ${_amountController.text} \$'),
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
    ) ?? false;

    if (confirm) {
      final provider = Provider.of<TransactionProvider>(context, listen: false);
      if (widget.transactionToEdit != null && widget.transactionToEdit!.id != null) {
        try {
          await provider.deleteTransaction(widget.transactionToEdit!.id!);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف المعاملة بنجاح.')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل في حذف المعاملة: $e')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _detailsController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.transactionToEdit != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(15.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildHeader(isEditing),
              const SizedBox(height: 10),

              _buildTextField(
                controller: _titleController,
                label: 'اسم الحساب',
                icon: Icons.person,
                keyboardType: TextInputType.text,
                readOnly: isEditing || widget.initialAccountName != null,
                validator: (value) => value!.isEmpty ? 'اسم الحساب مطلوب' : null,
              ),
              const SizedBox(height: 10),

              if (widget.showPhoneField)
                Column(
                  children: [
                    _buildTextField(
                      controller: _phoneController,
                      label: 'رقم الهاتف (اختياري)',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: null,
                    ),
                    const SizedBox(height: 10),
                  ],
                ),

              _buildTextField(
                controller: _amountController,
                label: 'المبلغ',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (double.tryParse(value ?? '') == null || double.parse(value!) <= 0) {
                    return 'أدخل مبلغاً صحيحاً';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              _buildDateRow(),
              const SizedBox(height: 10),

              _buildTextField(
                controller: _detailsController,
                label: 'التفاصيل',
                icon: Icons.description,
                keyboardType: TextInputType.text,
                validator: null,
              ),
              const SizedBox(height: 20),

              _buildTypeSelector(),
              const SizedBox(height: 15),

              _buildSaveButton(isEditing),

              const SizedBox(height: 10),

              if (isEditing) _buildDeleteButton(),
            ],
          ),
        ),
      ),
    );
  }

  // 🔑 دالة _buildHeader المُعدَّلة: العنوان الآن "إضافة معاملة" أو "تعديل المعاملة" فقط.
  Widget _buildHeader(bool isEditing) {
    final String title = isEditing ? 'تعديل المعاملة' : 'إضافة معاملة';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(Icons.grid_on, color: Colors.blue),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.share, color: Colors.blue),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextInputType keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      style: const TextStyle(fontSize: 16, height: 1.5),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        border: InputBorder.none,
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue, width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
      ),
      validator: validator,
    );
  }

  // 🔑 دالة _buildDateRow المُعدَّلة: حذف كلمة "التاريخ والوقت".
  Widget _buildDateRow() {
    return GestureDetector(
      onTap: _presentDateTimePicker,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.grey),
              // ❌ تم حذف النص "التاريخ والوقت:"
              SizedBox(width: 5),
            ],
          ),

          Flexible(
            child: Text(
              DateFormat('yyyy-MM-dd HH:mm').format(_selectedDate),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        GestureDetector(
          onTap: () { setState(() { _selectedType = 'Expense'; }); },
          child: Row(
            children: [
              Icon(
                _selectedType == 'Expense' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: _selectedType == 'Expense' ? Colors.red : Colors.grey,
              ),
              const SizedBox(width: 5),
              const Text('عليه', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),

        GestureDetector(
          onTap: () { setState(() { _selectedType = 'Income'; }); },
          child: Row(
            children: [
              Icon(
                _selectedType == 'Income' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: _selectedType == 'Income' ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 5),
              const Text('له', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(bool isEditing) {
    String label = isEditing ? 'تعديل وحفظ' : 'حفظ المعاملة';
    if (!isEditing && widget.initialAccountName == null && widget.showPhoneField) {
      label = 'إضافة الحساب والمعاملة';
    }

    return ElevatedButton.icon(
      onPressed: _submitData,
      icon: Icon(isEditing ? Icons.edit : Icons.save, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 18)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return TextButton.icon(
      onPressed: _deleteTransaction,
      icon: const Icon(Icons.delete_forever, color: Colors.red),
      label: const Text('حذف المعاملة', style: TextStyle(color: Colors.red, fontSize: 16)),
    );
  }
}