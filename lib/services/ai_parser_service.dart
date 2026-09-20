import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../models/ledger_models.dart';
import '../models/app_settings.dart';
import 'database_service.dart';

class AiParserService {
  static final AiParserService instance = AiParserService._internal();
  AiParserService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 45),
  ));

  /// 解析文本或OCR内容为 DailyLedger 对象（支持指定年份）
  Future<DailyLedger> parseLedgerContent(String rawText, {String? imagePath, int? defaultYear}) async {
    final settings = await DatabaseService.instance.getSettings();
    final aliasRules = await DatabaseService.instance.getAliasRules();
    final year = defaultYear ?? DateTime.now().year;

    // 如果配置了在线 AI 且有 API Key，优先尝试在线 AI 解析；否则或失败时自动降级至高精度本地智能规则引擎
    if (settings.aiProvider != 'offline_rules' &&
        settings.apiKey.trim().isNotEmpty &&
        settings.apiEndpoint.trim().isNotEmpty) {
      try {
        final aiResult = await _parseWithLlm(rawText, settings, aliasRules, imagePath: imagePath, defaultYear: year);
        if (aiResult != null) {
          return aiResult;
        }
      } catch (_) {
        // AI 异常时平滑降级到本地规则引擎
      }
    }

    // 本地智能规则解析器（100% 离线、零外部依赖）
    return _parseWithLocalRules(rawText, aliasRules, imagePath: imagePath, defaultYear: year);
  }

  /// 本地规则引擎高精度解析
  DailyLedger _parseWithLocalRules(String text, List<AliasRule> aliases, {String? imagePath, required int defaultYear}) {
    // 建立别名映射字典 (例如 "我" -> "坤茹", "妈" -> "坤茹")
    Map<String, String> aliasMap = {};
    for (var a in aliases) {
      aliasMap[a.alias.trim()] = a.realName.trim();
    }
    // 默认内置映射
    if (!aliasMap.containsKey('我')) aliasMap['我'] = '坤茹';
    if (!aliasMap.containsKey('妈')) aliasMap['妈'] = '坤茹';

    // 1. 提取日期（使用当前栏目的指定年份）
    String extractedDate = _extractDate(text, defaultYear);

    // 2. 提取总收入
    double totalIncome = 0.0;
    final incomeRegex = RegExp(r'(?:今日)?(?:收入|入账|进账|营业额|收钱)\s*[:：]?\s*([0-9]+(?:\.[0-9]+)?)', caseSensitive: false);
    final incomeMatch = incomeRegex.firstMatch(text);
    if (incomeMatch != null) {
      totalIncome = double.tryParse(incomeMatch.group(1) ?? '0') ?? 0.0;
    }

    // 3. 提取各成员支出明细
    List<ExpenseItem> expenseItems = [];
    final lines = text.split(RegExp(r'[\r\n]+'));
    final summaryExpenseRegex = RegExp(r'(?:共支出|总支出|合计支出|共计支出|总计)\s*[:：]?\s*([0-9]+(?:\.[0-9]+)?)');

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // 过滤总支出汇总行
      if (summaryExpenseRegex.hasMatch(trimmed)) {
        continue;
      }

      // 匹配成员支出行
      final expensePattern = RegExp(
        r'(?:(?:\d{1,2}月\d{1,2}日)?\s*)?([^\d\s,，.。:：]+?)(?:支出|花费|花了|用去|采购|出账)?\s*[:：]?\s*([0-9]+(?:\.[0-9]+)?)\s*(?:元|块|RMB)?(?:\s*(.*))?',
        caseSensitive: false,
      );

      final match = expensePattern.firstMatch(trimmed);
      if (match != null) {
        String rawName = match.group(1)?.trim() ?? '';
        String amountStr = match.group(2)?.trim() ?? '';

        // 清洗人名前缀
        rawName = rawName.replaceAll(RegExp(r'^\d{1,2}月\d{1,2}日'), '').trim();
        rawName = rawName.replaceAll(RegExp(r'^(?:妈|爸|微信|用户)[:：\s]*'), '').trim();

        if (rawName == '共' || rawName == '总' || rawName == '合计' || rawName == '收入' || rawName == '入账' || rawName.isEmpty) {
          continue;
        }

        double? amount = double.tryParse(amountStr);
        if (amount != null && amount > 0) {
          String finalName = aliasMap[rawName] ?? rawName;

          // 类别固定为日常支出，用户可在界面中自行选择修改
          expenseItems.add(ExpenseItem(
            personName: finalName,
            amount: amount,
            category: '日常支出',
            note: '',
          ));
        }
      }
    }

    // 备注不自动识别猜测，留空由用户自己输入
    return DailyLedger(
      date: extractedDate,
      totalIncome: totalIncome,
      expenses: expenseItems,
      specialNote: '',
      rawText: text,
      imagePath: imagePath,
    );
  }

  /// 提取日期（使用所属栏目的目标年份）
  String _extractDate(String text, int defaultYear) {
    // 匹配完整年月日：2023年9月19日 或 2023-09-19
    final fullDateRegex = RegExp(r'(\d{4})[年\-\/](\d{1,2})[月\-\/](\d{1,2})日?');
    final fullMatch = fullDateRegex.firstMatch(text);
    if (fullMatch != null) {
      int y = int.parse(fullMatch.group(1)!);
      int m = int.parse(fullMatch.group(2)!);
      int d = int.parse(fullMatch.group(3)!);
      return DateFormat('yyyy-MM-dd').format(DateTime(y, m, d));
    }

    // 匹配月日：9月19日 或 9-19 或 09/19 -> 绑定到所属栏目的年份
    final monthDayRegex = RegExp(r'(\d{1,2})[月\-\/](\d{1,2})日?');
    final mdMatch = monthDayRegex.firstMatch(text);
    if (mdMatch != null) {
      int m = int.parse(mdMatch.group(1)!);
      int d = int.parse(mdMatch.group(2)!);
      return DateFormat('yyyy-MM-dd').format(DateTime(defaultYear, m, d));
    }

    // 默认返回当前年份月份日期
    final now = DateTime.now();
    return DateFormat('yyyy-MM-dd').format(DateTime(defaultYear, now.month, now.day));
  }

  /// 在线 LLM 智能多模态/文本解析
  Future<DailyLedger?> _parseWithLlm(
    String rawText,
    AppSettings settings,
    List<AliasRule> aliases, {
    String? imagePath,
    required int defaultYear,
  }) async {
    String aliasPrompt = aliases.map((a) => "'${a.alias}' -> '${a.realName}'").join(', ');
    if (aliasPrompt.isEmpty) {
      aliasPrompt = "'我' 映射为 '坤茹', '妈' 映射为 '坤茹'";
    }

    String systemPrompt = settings.customPrompt.isNotEmpty
        ? settings.customPrompt
        : AppSettings.defaultSystemPrompt;

    if (systemPrompt.contains('{alias_rules}')) {
      systemPrompt = systemPrompt.replaceAll('{alias_rules}', aliasPrompt);
    } else {
      systemPrompt = '$systemPrompt\n【别名映射规则】: $aliasPrompt';
    }

    if (systemPrompt.contains('{target_year}')) {
      systemPrompt = systemPrompt.replaceAll('{target_year}', defaultYear.toString());
    }

    final response = await _dio.post(
      settings.apiEndpoint,
      options: Options(headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${settings.apiKey.trim()}',
      }),
      data: {
        'model': settings.modelName.isNotEmpty ? settings.modelName : 'gemini-3.7-flash',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': rawText},
        ],
        'temperature': 0.1,
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      String content = response.data['choices'][0]['message']['content'] ?? '';
      content = content.replaceAll('```json', '').replaceAll('```', '').trim();
      final jsonMap = jsonDecode(content);

      List<ExpenseItem> items = [];
      if (jsonMap['expenses'] != null) {
        for (var item in jsonMap['expenses']) {
          items.add(ExpenseItem(
            personName: item['personName'] ?? '未命名',
            amount: (item['amount'] as num?)?.toDouble() ?? 0.0,
            category: item['category'] ?? '日常支出',
            note: '',
          ));
        }
      }

      String date = jsonMap['date'] ?? DateFormat('yyyy-MM-dd').format(DateTime(defaultYear, 1, 1));
      // 保证年份对齐
      if (date.length >= 4 && !date.startsWith('$defaultYear') && !rawText.contains(RegExp(r'\d{4}'))) {
        date = '$defaultYear${date.substring(4)}';
      }

      return DailyLedger(
        date: date,
        totalIncome: (jsonMap['totalIncome'] as num?)?.toDouble() ?? 0.0,
        expenses: items,
        specialNote: '', // 备注不自动识别，由用户自己填写
        rawText: rawText,
        imagePath: imagePath,
      );
    }
    return null;
  }
}
