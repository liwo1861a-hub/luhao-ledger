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
  File? _selectedImage;
  final TextEditingController _textCtrl = TextEditingController();
  bool _isProcessing = false;
  String _statusMessage = '';
  DailyLedger? _parsedResult;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
          _parsedResult = null;
        });
        await _processImage();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;
    setState(() {
      _isProcessing = true;
      _statusMessage = '正在进行免费 OCR 图像文字提取...';
    });

    try {
      final provider = context.read<LedgerProvider>();
      setState(() {
        _statusMessage = '正在调用 AI 理解人名、别名映射与收支整理...';
      });

      final result = await provider.processImage(_selectedImage!);
      setState(() {
        _parsedResult = result;
        _textCtrl.text = result.rawText;
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

  Future<void> _processText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入或粘贴聊天记录/账目文本')));
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'AI 正在自动解析人名、收支及每日备注...';
    });

    try {
      final provider = context.read<LedgerProvider>();
      final result = await provider.processText(text);
      setState(() {
        _parsedResult = result;
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
        title: const Text('智能识图 & AI 记账', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          'AI 智能人名与别名理解',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade900, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '自动将"我"识别为"坤茹"，支持红章、烨文、坤艳等多人支出自动拆分，自动提取总收入与特殊情况备注。',
                          style: TextStyle(color: Colors.indigo.shade800, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 操作按钮行：拍照 / 相册 / 快捷示例
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, size: 20),
                    label: const Text('拍照识图'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library, size: 20),
                    label: const Text('相册选图'),
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

            // 文本/聊天记录输入区域
            TextField(
              controller: _textCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: '可直接在此粘贴微信聊天记录、账目短信或小票文字...\n例如：\n9月19日红章支出 333.5元\n我支出 6.5元\n收入 473.5元\n烨文支出22元\n坤艳支出6元',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 12),

            // 开始解析按钮
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isProcessing ? null : _processText,
                icon: const Icon(Icons.psychology),
                label: const Text('一键 AI 智能提取与整理', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),

            // 加载指示器
            if (_isProcessing) ...[
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(_statusMessage, style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 提取结构化结果预览卡片
            if (_parsedResult != null) _buildResultPreviewCard(context, _parsedResult!),
          ],
        ),
      ),
    );
  }

  Widget _buildResultPreviewCard(BuildContext context, DailyLedger result) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade300, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    const Text('AI 提取与结构化完成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    result.date,
                    style: TextStyle(color: Colors.indigo.shade800, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // 总收入与总支出
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('单日总收入', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '¥${result.totalIncome.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(width: 1, height: 36, color: Colors.grey.shade300),
                Column(
                  children: [
                    const Text('单日总支出', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '¥${result.totalExpense.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.deepOrange, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(width: 1, height: 36, color: Colors.grey.shade300),
                Column(
                  children: [
                    const Text('结余 (利润)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '¥${result.netProfit.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: result.netProfit >= 0 ? Colors.blue : Colors.red,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 成员支出列表
            const Text('成员支出识别结果：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ...result.expenses.map((exp) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: exp.personName == '坤茹' ? Colors.indigo.shade100 : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            exp.personName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: exp.personName == '坤茹' ? Colors.indigo.shade800 : Colors.red.shade800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(exp.category, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    Text(
                      '¥${exp.amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              );
            }),

            // 每日特殊情况备注
            if (result.specialNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notes, size: 18, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '特殊情况备注: ${result.specialNote}',
                        style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            // 保存入库与二次编辑按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => EditLedgerDialog(initialRecord: result),
                      ).then((_) {
                        setState(() {
                          _parsedResult = null;
                        });
                      });
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('调整/编辑'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final provider = context.read<LedgerProvider>();
                      await provider.saveRecord(result);
                      setState(() {
                        _parsedResult = null;
                        _selectedImage = null;
                        _textCtrl.clear();
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已成功保存并同步至月度统计与总看板！'), backgroundColor: Colors.green),
                        );
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('确认保存入账'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
