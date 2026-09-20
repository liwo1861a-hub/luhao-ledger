import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/ledger_models.dart';
import '../services/ledger_provider.dart';
import '../widgets/edit_ledger_dialog.dart';

class SmartOcrScreen extends StatefulWidget {
  const SmartOcrScreen({super.key});

  @override
  State<SmartOcrScreen> createState() => _SmartOcrScreenState();
}

class _SmartOcrScreenState extends State<SmartOcrScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _textCtrl = TextEditingController();
  bool _isProcessing = false;
  String _statusMessage = '';
  double _batchProgress = 0.0;
  List<DailyLedger> _batchResults = [];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  // 拍照识图（拍照后立即自动执行 OCR -> AI 整理）
  Future<void> _pickSingleImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        final file = File(picked.path);
        setState(() {
          _isProcessing = true;
          _statusMessage = '正在 OCR 提取图片文字并自动 AI 整理...';
          _batchProgress = 0.5;
        });

        final provider = context.read<LedgerProvider>();
        final result = await provider.processImage(file);

        setState(() {
          _batchResults = [result];
          _textCtrl.text = result.rawText;
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

  // 批量相册选图（支持多选图片，批量自动链式 OCR -> AI 解析）
  Future<void> _pickBatchImages() async {
    try {
      final List<XFile> pickedList = await _picker.pickMultiImage();
      if (pickedList.isNotEmpty) {
        setState(() {
          _isProcessing = true;
          _batchResults = [];
          _batchProgress = 0.0;
        });

        final List<File> files = pickedList.map((x) => File(x.path)).toList();
        final provider = context.read<LedgerProvider>();

        final results = await provider.processBatchImages(
          files,
          onProgress: (current, total, status) {
            setState(() {
              _statusMessage = status;
              _batchProgress = current / total;
            });
          },
        );

        setState(() {
          _batchResults = results;
          _isProcessing = false;
          _statusMessage = '';
        });

        if (mounted && results.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('批量 OCR 与 AI 智能解析完成！共提取 ${results.length} 笔账目记录'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = '批量选取处理失败: $e';
      });
    }
  }

  // 纯文本一键 AI 智能提取
  Future<void> _processText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入或粘贴聊天记录/账目文本')));
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'AI 正在自动解析人名、别名、收支及特殊情况备注...';
    });

    try {
      final provider = context.read<LedgerProvider>();
      final result = await provider.processText(text);
      setState(() {
        _batchResults = [result];
        _isProcessing = false;
        _statusMessage = '';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = '解析失败: $e';
      });
    }
  }

  void _loadSampleData(int sampleIndex) {
    if (sampleIndex == 1) {
      _textCtrl.text = '''9月19日红章支出 333.5元
我支出 6.5元
9月19日共支出 340元
收入 473.5元
向爸转账 已被接收''';
    } else if (sampleIndex == 2) {
      _textCtrl.text = '''烨文支出22元
坤艳支出6元
红章支出150元
我支出35元
收入 680元
下雨天客人较多，进货调料与蔬菜''';
    }
    _processText();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('智能识图 & AI 批量记账', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部说明卡片
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.indigo.shade700, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OCR 识别后全自动 AI 整理',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade900, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '支持相册多选批量上传、拍照，OCR 提取后自动调用 AI 整理各成员人名、支出金额、总收入与每日特殊备注。',
                          style: TextStyle(color: Colors.indigo.shade800, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 操作按钮行：批量上传 / 拍照
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isProcessing ? null : _pickBatchImages,
                    icon: const Icon(Icons.photo_library, size: 20),
                    label: const Text('批量相册上传', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isProcessing ? null : () => _pickSingleImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, size: 20),
                    label: const Text('拍照识图'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 快捷样本填入
            Row(
              children: [
                const Text('快速填入真实样本：', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ActionChip(
                  label: const Text('9月19日账单样本', style: TextStyle(fontSize: 11)),
                  onPressed: () => _loadSampleData(1),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('多人多笔样本', style: TextStyle(fontSize: 11)),
                  onPressed: () => _loadSampleData(2),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 文本输入区域
            TextField(
              controller: _textCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '可直接在此粘贴微信聊天记录、账目短信或小票文字...\n例如：\n9月19日红章支出 333.5元\n我支出 6.5元\n收入 473.5元\n烨文支出22元\n坤艳支出6元',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 12),

            // 开始文本 AI 解析按钮
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isProcessing ? null : _processText,
                icon: const Icon(Icons.psychology),
                label: const Text('一键 AI 智能提取与整理', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),

            // 批量处理加载状态
            if (_isProcessing) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      LinearProgressIndicator(value: _batchProgress > 0 ? _batchProgress : null),
                      const SizedBox(height: 12),
                      Text(
                        _statusMessage,
                        style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 提取结构化结果展示（单笔或批量）
            if (_batchResults.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'AI 提取完成 (共 ${_batchResults.length} 笔)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _saveAllBatchResults,
                    icon: const Icon(Icons.save_alt, size: 18),
                    label: Text('一键保存全部 (${_batchResults.length})'),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              ...List.generate(_batchResults.length, (index) {
                final result = _batchResults[index];
                return _buildSingleResultCard(context, result, index);
              }),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleResultCard(BuildContext context, DailyLedger result, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.shade300, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：序号、日期与操作
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.indigo,
                      child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        result.date,
                        style: TextStyle(color: Colors.indigo.shade800, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => EditLedgerDialog(initialRecord: result),
                        ).then((_) => setState(() {}));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      onPressed: () {
                        setState(() {
                          _batchResults.removeAt(index);
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 12),

            // 总收支与结余
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text.rich(
                  TextSpan(
                    text: '单日收入: ',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    children: [
                      TextSpan(
                        text: '+¥${result.totalIncome.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    text: '单日总支出: ',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    children: [
                      TextSpan(
                        text: '-¥${result.totalExpense.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    text: '结余: ',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    children: [
                      TextSpan(
                        text: '¥${result.netProfit.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: result.netProfit >= 0 ? Colors.blue : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 成员支出明细
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: result.expenses.map((exp) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: exp.personName == '坤茹' ? Colors.indigo.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: exp.personName == '坤茹' ? Colors.indigo.shade200 : Colors.red.shade200,
                    ),
                  ),
                  child: Text(
                    '${exp.personName}: ¥${exp.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: exp.personName == '坤茹' ? Colors.indigo.shade900 : Colors.red.shade900,
                    ),
                  ),
                );
              }).toList(),
            ),

            // 每日特殊情况备注
            if (result.specialNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notes, size: 14, color: Colors.amber.shade800),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '特殊备注: ${result.specialNote}',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveAllBatchResults() async {
    if (_batchResults.isEmpty) return;
    final provider = context.read<LedgerProvider>();
    await provider.saveBatchRecords(_batchResults);

    setState(() {
      _batchResults = [];
      _textCtrl.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已批量保存所有记账记录并同步至统计看板！'), backgroundColor: Colors.green),
      );
    }
  }
}
