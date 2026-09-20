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
        title: Text('${provider.selectedYear}年 ${provider.selectedMonthNum}月 账目明细', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // 1. 年份选择栏目 (可自由添加与切换哪一年)
                SliverToBoxAdapter(
                  child: _buildYearSelectionBar(context, provider),
                ),

                // 2. 月份选择栏目 (当前年份下的 12 个月份快速切换)
                SliverToBoxAdapter(
                  child: _buildMonthSelectionBar(context, provider),
                ),

                // 3. 【整合核心】当前选定某年某月的「月度概览卡片」
                if (stats != null)
                  SliverToBoxAdapter(
                    child: _buildIntegratedMonthlyCard(provider, stats),
                  ),

                // 4. 【整合核心】当前年份栏目的「微信记录 AI 快速提取 & OCR 开关」
                SliverToBoxAdapter(
                  child: _buildSmartExtractionSection(context, provider),
                ),

                // 5. AI 结构化提取结果临时预览卡片（确认后一键入账）
                if (_extractedResults.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildExtractedResultsPreview(context, provider),
                  ),

                // 6. 当前年月下的每日明细列表
                if (records.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 50, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('${provider.selectedMonthKey} 暂无记账明细', style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
                            const SizedBox(height: 4),
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
        onPressed: () => _openAddRecordDialog(context, provider.selectedYear, provider.selectedMonthNum),
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }

  // 1. 年份选择栏
  Widget _buildYearSelectionBar(BuildContext context, LedgerProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.indigo.shade50.withOpacity(0.7),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Colors.indigo, size: 18),
          const SizedBox(width: 6),
          const Text('年份:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

  // 2. 月份横向切换栏
  Widget _buildMonthSelectionBar(BuildContext context, LedgerProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          const Icon(Icons.view_timeline_outlined, color: Colors.blueGrey, size: 18),
          const SizedBox(width: 6),
          const Text('月份:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(12, (index) {
                  final monthNum = index + 1;
                  final isSelected = monthNum == provider.selectedMonthNum;
                  final monthKey = '${provider.selectedYear}-${monthNum.toString().padLeft(2, '0')}';
                  final hasData = provider.monthsWithData.contains(monthKey);

                  return Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: FilterChip(
                      label: Text(
                        '$monthNum月',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : (hasData ? Colors.indigo.shade900 : Colors.black54),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF1E3A8A),
                      backgroundColor: hasData ? Colors.indigo.shade50 : Colors.white,
                      checkmarkColor: Colors.white,
                      onSelected: (_) {
                        provider.setSelectedMonthNum(monthNum);
                      },
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. 整合进当前年月栏目的「月度概览卡片」
  Widget _buildIntegratedMonthlyCard(LedgerProvider provider, MonthlyStats stats) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📌 ${provider.selectedYear}年${provider.selectedMonthNum}月 财务概览',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                child: Text('共 ${stats.recordCount} 天记录', style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
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
              _buildMiniStat('当月净结余', '¥${stats.netProfit.toStringAsFixed(2)}', stats.netProfit >= 0 ? Colors.cyanAccent : Colors.redAccent),
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

  // 4. 当前年份栏目内的「微信聊天记录快速粘贴 & AI 整理主功能区」+ 独立 OCR 开关
  Widget _buildSmartExtractionSection(BuildContext context, LedgerProvider provider) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.amber, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '微信聊天记录快速粘贴 & AI 一键整理',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo.shade900),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    '默认归属 ${provider.selectedYear}年',
                    style: TextStyle(color: Colors.indigo.shade800, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _chatTextCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '直接粘贴微信群账目记录...\n例如：9月19日红章支出 333.5元，我支出 6.5元，收入 473.5元',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.grey.shade50,
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),

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

            // 独立 OCR 识图开关
            const Divider(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.document_scanner, size: 16, color: Colors.blueGrey.shade700),
                    const SizedBox(width: 6),
                    const Text('图片 / 小票 OCR 识图模式', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
                Switch.adaptive(
                  value: _isOcrSectionExpanded,
                  activeColor: Colors.indigo,
                  onChanged: (val) => setState(() => _isOcrSectionExpanded = val),
                ),
              ],
            ),

            if (_isOcrSectionExpanded) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: _isProcessing ? null : _pickBatchImages,
                        icon: const Icon(Icons.photo_library, size: 16),
                        label: const Text('批量相册选图'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: _isProcessing ? null : _pickCameraImage,
                        icon: const Icon(Icons.camera_alt, size: 16),
                        label: const Text('拍照识图'),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_isProcessing) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: _batchProgress > 0 ? _batchProgress : null),
              const SizedBox(height: 4),
              Center(child: Text(_statusMessage, style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.bold))),
            ],
          ],
        ),
      ),
    );
  }

  // 5. 提取完成临时预览卡片
  Widget _buildExtractedResultsPreview(BuildContext context, LedgerProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
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
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 6),
                  Text('AI 提取成功 (${_extractedResults.length} 笔)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
          const SizedBox(height: 6),

          ..._extractedResults.map((r) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(r.date, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 13)),
                      Text('收入: +¥${r.totalIncome} | 支出: -¥${r.totalExpense}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

  // 6. 每日账目卡片
  Widget _buildDailyRecordCard(BuildContext context, DailyLedger record, LedgerProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1.5,
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

            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: record.expenses.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    '${item.personName}: ¥${item.amount.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo.shade900),
                  ),
                );
              }).toList(),
            ),

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

  void _openAddRecordDialog(BuildContext context, int defaultYear, int defaultMonth) {
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
