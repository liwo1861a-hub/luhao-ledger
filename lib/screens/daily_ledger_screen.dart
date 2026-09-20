import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/ledger_models.dart';
import '../services/ledger_provider.dart';
import '../widgets/edit_ledger_dialog.dart';

class DailyLedgerScreen extends StatelessWidget {
  const DailyLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final records = provider.dailyRecords;
    final stats = provider.monthlyStats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('每日账目明细', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // 月份选择器
          if (provider.availableMonths.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: provider.selectedMonth,
                  icon: const Icon(Icons.calendar_month, color: Colors.indigo),
                  items: provider.availableMonths.map((m) {
                    return DropdownMenuItem<String>(
                      value: m,
                      child: Text(
                        m,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      provider.setSelectedMonth(val);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // 当月顶部汇总条
                if (stats != null)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.all(12.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${provider.selectedMonth} 月度概览',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '共 ${stats.recordCount} 天记录',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMiniStat('当月总收入', '¥${stats.totalIncome.toStringAsFixed(2)}', Colors.greenAccent),
                              Container(width: 1, height: 32, color: Colors.white24),
                              _buildMiniStat('当月总支出', '¥${stats.totalExpense.toStringAsFixed(2)}', Colors.amberAccent),
                              Container(width: 1, height: 32, color: Colors.white24),
                              _buildMiniStat(
                                '当月结余',
                                '¥${stats.netProfit.toStringAsFixed(2)}',
                                stats.netProfit >= 0 ? Colors.cyanAccent : Colors.redAccent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                // 账单列表
                if (records.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('当前月份暂无记账记录', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _openAddRecordDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('手动添加单日记账'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final record = records[index];
                        return _buildDailyRecordCard(context, record, provider);
                      },
                      childCount: records.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddRecordDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildDailyRecordCard(BuildContext context, DailyLedger record, LedgerProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 卡片头部：日期与总收支
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        record.date,
                        style: TextStyle(
                          color: Colors.indigo.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blueGrey),
                      onPressed: () => _openEditRecordDialog(context, record),
                      tooltip: '编辑',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                      onPressed: () => _confirmDelete(context, record, provider),
                      tooltip: '删除',
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),

            // 收支总览行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text.rich(
                  TextSpan(
                    text: '单日收入: ',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    children: [
                      TextSpan(
                        text: '+¥${record.totalIncome.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    text: '单日总支出: ',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    children: [
                      TextSpan(
                        text: '-¥${record.totalExpense.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    text: '净结余: ',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    children: [
                      TextSpan(
                        text: '¥${record.netProfit.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: record.netProfit >= 0 ? Colors.blue : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 成员支出标签列表
            if (record.expenses.isNotEmpty) ...[
              const Text('成员支出明细：', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: record.expenses.map((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _getPersonColor(item.personName).withOpacity(0.12),
                      border: Border.all(color: _getPersonColor(item.personName).withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item.personName}: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _getPersonColor(item.personName),
                          ),
                        ),
                        Text(
                          '¥${item.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        if (item.category.isNotEmpty && item.category != '日常支出')
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Text(
                              '(${item.category})',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],

            // 每日特殊情况备注
            if (record.specialNote.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '特殊情况备注: ${record.specialNote}',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getPersonColor(String name) {
    switch (name) {
      case '红章':
        return Colors.red.shade700;
      case '坤茹':
        return Colors.indigo.shade700;
      case '烨文':
        return Colors.teal.shade700;
      case '坤艳':
        return Colors.purple.shade700;
      default:
        final hash = name.hashCode;
        final colors = [Colors.blue, Colors.orange, Colors.cyan, Colors.pink, Colors.brown];
        return colors[hash.abs() % colors.length];
    }
  }

  void _openAddRecordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const EditLedgerDialog(),
    );
  }

  void _openEditRecordDialog(BuildContext context, DailyLedger record) {
    showDialog(
      context: context,
      builder: (_) => EditLedgerDialog(initialRecord: record),
    );
  }

  void _confirmDelete(BuildContext context, DailyLedger record, LedgerProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${record.date} 的记账记录吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deleteRecord(record.id);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
