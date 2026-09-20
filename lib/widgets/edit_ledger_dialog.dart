import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/ledger_models.dart';
import '../services/ledger_provider.dart';

class EditLedgerDialog extends StatefulWidget {
  final DailyLedger? initialRecord;

  const EditLedgerDialog({super.key, this.initialRecord});

  @override
  State<EditLedgerDialog> createState() => _EditLedgerDialogState();
}

class _EditLedgerDialogState extends State<EditLedgerDialog> {
  late String _date;
  late TextEditingController _incomeCtrl;
  late TextEditingController _specialNoteCtrl;
  late List<ExpenseItem> _expenses;

  final List<String> _commonPersons = ['红章', '坤茹', '烨文', '坤艳'];
  final List<String> _commonCategories = ['食材采购', '调料备料', '零星开支', '水电租金', '物料耗材', '日常支出'];

  @override
  void initState() {
    super.initState();
    final rec = widget.initialRecord;
    _date = rec?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    _incomeCtrl = TextEditingController(text: rec != null ? rec.totalIncome.toString() : '');
    _specialNoteCtrl = TextEditingController(text: rec?.specialNote ?? '');
    _expenses = rec != null
        ? rec.expenses.map((e) => e.copyWith()).toList()
        : [ExpenseItem(personName: '红章', amount: 0.0, category: '食材采购')];
  }

  @override
  void dispose() {
    _incomeCtrl.dispose();
    _specialNoteCtrl.dispose();
    super.dispose();
  }

  double get _currentTotalExpense {
    return _expenses.fold<double>(0.0, (sum, item) => sum + item.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // 标题栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.initialRecord != null ? '编辑单日账目' : '新增单日记账',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 日期选择
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: Colors.indigo),
                        const SizedBox(width: 8),
                        const Text('记账日期:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.edit_calendar, size: 16),
                          label: Text(_date),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 单日总收入
                    TextField(
                      controller: _incomeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: '单日总收入 (元)',
                        hintText: '如 473.5',
                        prefixIcon: const Icon(Icons.account_balance_wallet, color: Colors.green),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 成员支出明细表
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '各成员支出明细',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          '支出合计: ¥${_currentTotalExpense.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 成员支出动态列表
                    ...List.generate(_expenses.length, (index) {
                      return _buildExpenseItemRow(index);
                    }),

                    const SizedBox(height: 8),
                    // 添加支出项按钮
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _expenses.add(ExpenseItem(personName: '坤茹', amount: 0.0, category: '零星开支'));
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('添加一位成员支出'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 每日特殊情况备注
                    TextField(
                      controller: _specialNoteCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: '每日特殊情况备注 (选填)',
                        hintText: '例如：向爸转账已被接收、下雨客流少、特殊进料等...',
                        prefixIcon: const Icon(Icons.note_alt_outlined, color: Colors.amber),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            // 底部保存按钮
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _saveRecord,
                child: const Text('保存记账记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseItemRow(int index) {
    final item = _expenses[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // 成员姓名下拉/输入
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _commonPersons.contains(item.personName) ? item.personName : null,
                  decoration: const InputDecoration(
                    labelText: '支出成员',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  hint: Text(item.personName.isNotEmpty ? item.personName : '选人名'),
                  items: _commonPersons.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => item.personName = val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // 金额输入
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: item.amount > 0 ? item.amount.toString() : '',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '支出金额(元)',
                    isDense: true,
                    prefixText: '¥',
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onChanged: (val) {
                    setState(() {
                      item.amount = double.tryParse(val) ?? 0.0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              // 类别选择
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _commonCategories.contains(item.category) ? item.category : '日常支出',
                  decoration: const InputDecoration(
                    labelText: '分类',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: _commonCategories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => item.category = val);
                    }
                  },
                ),
              ),
              // 删除单行
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                onPressed: () {
                  setState(() {
                    _expenses.removeAt(index);
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final cur = DateTime.tryParse(_date) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _date = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveRecord() async {
    final income = double.tryParse(_incomeCtrl.text.trim()) ?? 0.0;
    final note = _specialNoteCtrl.text.trim();

    // 过滤掉金额为0且无名字的行
    final validExpenses = _expenses.where((e) => e.personName.isNotEmpty && e.amount > 0).toList();

    final record = DailyLedger(
      id: widget.initialRecord?.id,
      date: _date,
      totalIncome: income,
      expenses: validExpenses,
      specialNote: note,
      createdAt: widget.initialRecord?.createdAt,
    );

    final provider = context.read<LedgerProvider>();
    await provider.saveRecord(record);

    if (mounted) {
      Navigator.pop(context);
    }
  }
}
