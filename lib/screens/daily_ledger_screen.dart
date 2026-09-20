import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/ledger_models.dart';
import '../services/ledger_provider.dart';
import '../widgets/edit_ledger_dialog.dart';

class DailyLedgerScreen extends StatefulWidget {
  const DailyLedgerScreen({super.key});

  @override
  State<DailyLedgerScreen> createState() => _DailyLedgerScreenState();
}

class _DailyLedgerScreenState extends State<DailyLedgerScreen> {
  final TextEditingController _chatTextCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _isOcrSectionExpanded = false; // OCR 识图独立开关
  bool _isProcessing = false;
  String _statusMessage = '';
  double _batchProgress = 0.0;
  List<DailyLedger> _extractedResults = [];

  @override
  void dispose() {
    _chatTextCtrl.dispose();
    super.dispose();
  }

  // 微信聊天记录一键粘贴
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.trim().isNotEmpty) {
      setState(() {
        _chatTextCtrl.text = data.text!.trim();
      });
      _processChatText();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('剪贴板中暂无文本内容')),
      );
    }
  }

  // 一键 AI 智能提取微信聊天记录（绑定当前年份）
  Future<void> _processChatText() async {
    final text = _chatTextCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先粘贴或输入微信聊天记录')),
      );
      return;
    }

    final provider = context.read<LedgerProvider>();
    setState(() {
      _isProcessing = true;
      _statusMessage = 'AI 正在自动解析【${provider.selectedYear}年】人名、别名映射与收支金额...';
    });

    try {
      final result = await provider.processText(text, year: provider.selectedYear);
      setState(() {
        _extractedResults = [result];
        _isProcessing = false;
        _statusMessage = '';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = '提取失败: $e';
      });
    }
  }

  // 批量相册选图 OCR（绑定当前年份）
  Future<void> _pickBatchImages() async {
    final provider = context.read<LedgerProvider>();
    try {
      final List<XFile> pickedList = await _picker.pickMultiImage();
      if (pickedList.isNotEmpty) {
        setState(() {
          _isProcessing = true;
          _extractedResults = [];
          _batchProgress = 0.0;
        });

        final List<File> files = pickedList.map((x) => File(x.path)).toList();
        final results = await provider.processBatchImages(
          files,
          year: provider.selectedYear,
          onProgress: (current, total, status) {
            setState(() {
              _statusMessage = status;
              _batchProgress = current / total;
            });
          },
        );

        setState(() {
          _extractedResults = results;
          _isProcessing = false;
          _statusMessage = '';
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = '处理失败: $e';
      });
    }
  }

  // 拍照识图 OCR（绑定当前年份）
  Future<void> _pickCameraImage() async {
    final provider = context.read<LedgerProvider>();
    try {
      final picked = await _picker.pickImage(source: ImageSource.camera);
      if (picked != null) {
        setState(() {
          _isProcessing = true;
          _statusMessage = '正在 OCR 识别并按【${provider.selectedYear}年】自动 AI 整理...';
        });

        final result = await provider.processImage(File(picked.path), year: provider.selectedYear);
        setState(() {
          _extractedResults = [result];
          _isProcessing = false;
          _statusMessage = '';
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = '拍照识别失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final records = provider.dailyRecords;
    final stats = provider.monthlyStats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('账目明细与智能记账', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // 月份选择下拉
          if (provider.availableMonths.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: provider.selectedMonth,
                  icon: const Icon(Icons.calendar_month, color: Colors.indigo),
                  items: provider.availableMonths.map((m) {
                    return DropdownMenuItem<String>(
                      value: m,
                      child: Text(
                        m,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                // 1. 年份切换栏（支持自定义设置与切换哪一年）
                SliverToBoxAdapter(
                  child: _buildYearSelectionBar(context, provider),
                ),

                // 2. 嵌入当前年份栏目的【核心主功能：微信聊天记录快速粘贴 & AI 一键整理】
                SliverToBoxAdapter(
                  child: _buildSmartExtractionSection(context, provider),
                ),

                // 3. AI 结构化提取结果临时预览卡片（确认后入账）
                if (_extractedResults.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildExtractedResultsPreview(context, provider),
                  ),

                // 4. 当月财务总览卡片
                if (stats != null)
                  SliverToBoxAdapter(
                    child: _buildMonthlySummaryCard(provider, stats),
                  ),

                // 5. 每日账目明细列表
                if (records.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('${provider.selectedMonth} 暂无记账明细', style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
                            const SizedBox(height: 6),
                            const Text('在上方粘贴微信记录或开启OCR即可一键记账', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
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

                const SliverToBoxAdapter(child: SizedBox(height: 90)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddRecordDialog(context, provider.selectedYear),
        icon: const Icon(Icons.add),
        label: const Text('手动记一笔'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }

  // 年份切换与自定义年份栏
  Widget _buildYearSelectionBar(BuildContext context, LedgerProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.indigo.shade50.withOpacity(0.6),
      child: Row(
        children: [
          const Icon(Icons.history_toggle_off, color: Colors.indigo, size: 20),
          const SizedBox(width: 8),
          const Text('所属年份:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...provider.availableYears.map((year) {
                    final isSelected = year == provider.selectedYear;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text('$year年', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
                        selected: isSelected,
                        selectedColor: Colors.indigo,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                        onSelected: (selected) {
                          if (selected) {
                            provider.setSelectedYear(year);
                          }
                        },
                      ),
                    );
                  }),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 14),
                    label: const Text('自定年份', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showAddCustomYearDialog(context, provider),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 核心功能卡片：微信聊天记录粘贴 & 独立 OCR 开关
  Widget _buildSmartExtractionSection(BuildContext context, LedgerProvider provider) {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：主功能标题与当前年份标识
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.amber, size: 22),
                    const SizedBox(width: 6),
                    Text(
                      '微信聊天记录 AI 一键提取整理',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo.shade900),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.indigo.shade100, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    '默认绑定 ${provider.selectedYear}年',
                    style: TextStyle(color: Colors.indigo.shade900, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 主功能输入框（支持直接粘贴微信聊天记录）
            TextField(
              controller: _chatTextCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '直接在此粘贴微信聊天记录...\n如：9月19日红章支出 333.5元，我支出 6.5元，收入 473.5元',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey.shade50,
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),

            // 快捷操作按钮行：一键粘贴并提取 / 快速提取
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste, size: 16),
                  label: const Text('一键粘贴剪贴板'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isProcessing ? null : _processChatText,
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('AI 提取整理', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 独立 OCR 识图功能开关栏（与微信文字提取彻底分开）
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.document_scanner, size: 18, color: Colors.blueGrey.shade700),
                    const SizedBox(width: 6),
                    const Text('图片 / 小票 OCR 识图模块', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
                Switch.adaptive(
                  value: _isOcrSectionExpanded,
                  activeColor: Colors.indigo,
                  onChanged: (val) => setState(() => _isOcrSectionExpanded = val),
                ),
              ],
            ),

            // 展开的 OCR 操作按钮
            if (_isOcrSectionExpanded) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isProcessing ? null : _pickBatchImages,
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text('批量相册选图'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isProcessing ? null : _pickCameraImage,
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('拍照识图'),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 加载处理提示
            if (_isProcessing) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _batchProgress > 0 ? _batchProgress : null),
              const SizedBox(height: 6),
              Center(child: Text(_statusMessage, style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.bold))),
            ],
          ],
        ),
      ),
    );
  }

  // 提取完成临时预览卡片
  Widget _buildExtractedResultsPreview(BuildContext context, LedgerProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 6),
                  Text('AI 提取成功 (${_extractedResults.length} 笔)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () async {
                  await provider.saveBatchRecords(_extractedResults);
                  setState(() {
                    _extractedResults = [];
                    _chatTextCtrl.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已成功保存入账！'), backgroundColor: Colors.green),
                  );
                },
                child: const Text('确认保存入账'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ..._extractedResults.map((r) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(r.date, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                      Text('收入: +¥${r.totalIncome}  |  支出: -¥${r.totalExpense}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: r.expenses.map((e) => Text('${e.personName}: ¥${e.amount}', style: const TextStyle(fontSize: 12, color: Colors.black87))).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // 月度财务概览
  Widget _buildMonthlySummaryCard(LedgerProvider provider, MonthlyStats stats) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${provider.selectedMonth} 月度报表', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              Text('共 ${stats.recordCount} 天记录', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat('当月总收入', '¥${stats.totalIncome.toStringAsFixed(2)}', Colors.greenAccent),
              Container(width: 1, height: 28, color: Colors.white24),
              _buildMiniStat('当月总支出', '¥${stats.totalExpense.toStringAsFixed(2)}', Colors.amberAccent),
              Container(width: 1, height: 28, color: Colors.white24),
              _buildMiniStat('当月结余', '¥${stats.netProfit.toStringAsFixed(2)}', stats.netProfit >= 0 ? Colors.cyanAccent : Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // 每日账目卡片
  Widget _buildDailyRecordCard(BuildContext context, DailyLedger record, LedgerProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Text(record.date, style: TextStyle(color: Colors.indigo.shade900, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey),
                      onPressed: () => _openEditRecordDialog(context, record),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      onPressed: () => provider.deleteRecord(record.id),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text.rich(TextSpan(text: '收入: ', style: const TextStyle(fontSize: 12, color: Colors.grey), children: [
                  TextSpan(text: '+¥${record.totalIncome.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                ])),
                Text.rich(TextSpan(text: '支出: ', style: const TextStyle(fontSize: 12, color: Colors.grey), children: [
                  TextSpan(text: '-¥${record.totalExpense.toStringAsFixed(2)}', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 13)),
                ])),
                Text.rich(TextSpan(text: '结余: ', style: const TextStyle(fontSize: 12, color: Colors.grey), children: [
                  TextSpan(text: '¥${record.netProfit.toStringAsFixed(2)}', style: TextStyle(color: record.netProfit >= 0 ? Colors.blue : Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                ])),
              ],
            ),
            const SizedBox(height: 8),

            // 成员支出标签
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: record.expenses.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${item.personName}: ¥${item.amount.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo.shade900),
                  ),
                );
              }).toList(),
            ),

            // 特殊情况备注（仅显示用户自己填写的内容）
            if (record.specialNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    Icon(Icons.notes, size: 14, color: Colors.amber.shade800),
                    const SizedBox(width: 6),
                    Expanded(child: Text('备注: ${record.specialNote}', style: TextStyle(fontSize: 12, color: Colors.amber.shade900))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddCustomYearDialog(BuildContext context, LedgerProvider provider) {
    final ctrl = TextEditingController(text: '${DateTime.now().year}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加或选择年份'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '输入年份 (如 2023、2024)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final y = int.tryParse(ctrl.text.trim());
              if (y != null && y > 2000 && y < 2100) {
                provider.addCustomYear(y);
                Navigator.pop(ctx);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _openAddRecordDialog(BuildContext context, int defaultYear) {
    showDialog(
      context: context,
      builder: (_) => EditLedgerDialog(defaultYear: defaultYear),
    );
  }

  void _openEditRecordDialog(BuildContext context, DailyLedger record) {
    showDialog(
      context: context,
      builder: (_) => EditLedgerDialog(initialRecord: record),
    );
  }
}
