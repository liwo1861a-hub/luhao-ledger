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

  /// 解析文本或OCR内容为 DailyLedger 对象
  Future<DailyLedger> parseLedgerContent(String rawText, {String? imagePath}) async {
    final settings = await DatabaseService.instance.getSettings();
    final aliasRules = await DatabaseService.instance.getAliasRules();

    // 如果配置了在线 AI 且有 API Key，优先尝试在线 AI 解析；否则或失败时自动降级至高精度本地智能规则引擎
    if (settings.aiProvider != 'offline_rules' &&
        settings.apiKey.trim().isNotEmpty &&
        settings.apiEndpoint.trim().isNotEmpty) {
      try {
        final aiResult = await _parseWithLlm(rawText, settings, aliasRules, imagePath: imagePath);
        if (aiResult != null) {
          return aiResult;
        }
      } catch (_) {
        // AI 异常时平滑降级到本地规则引擎
      }
    }

    // 本地智能规则解析器（100% 离线、零外部依赖）
    return _parseWithLocalRules(rawText, aliasRules, imagePath: imagePath);
  }

  /// 本地规则引擎高精度解析
  DailyLedger _parseWithLocalRules(String text, List<AliasRule> aliases, {String? imagePath}) {
    // 建立别名映射字典 (例如 "我" -> "坤茹", "妈" -> "坤茹")
    Map<String, String> aliasMap = {};
    for (var a in aliases) {
      aliasMap[a.alias.trim()] = a.realName.trim();
    }
    // 默认内置映射
    if (!aliasMap.containsKey('我')) aliasMap['我'] = '坤茹';
    if (!aliasMap.containsKey('妈')) aliasMap['妈'] = '坤茹';

    // 1. 提取日期
    String extractedDate = _extractDate(text);

    // 2. 提取总收入
    double totalIncome = 0.0;
    // 匹配 "收入 473.5元", "收入: 473.5", "进账473.5", "今日收入473.5元"
    final incomeRegex = RegExp(r'(?:今日)?(?:收入|入账|进账|营业额|收钱)\s*[:：]?\s*([0-9]+(?:\.[0-9]+)?)', caseSensitive: false);
    final incomeMatch = incomeRegex.firstMatch(text);
    if (incomeMatch != null) {
      totalIncome = double.tryParse(incomeMatch.group(1) ?? '0') ?? 0.0;
    }

    // 3. 提取各成员支出明细
    List<ExpenseItem> expenseItems = [];
    final lines = text.split(RegExp(r'[\r\n]+'));

    // 专门用于过滤总支出汇总行的正则（如 "9月19日共支出 340元", "合计支出 340"）
    final summaryExpenseRegex = RegExp(r'(?:共支出|总支出|合计支出|共计支出|总计)\s*[:：]?\s*([0-9]+(?:\.[0-9]+)?)');

    List<String> specialNotes = [];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // 如果是总支出汇总行，记录但不重复添加为单人支出
      if (summaryExpenseRegex.hasMatch(trimmed)) {
        continue;
      }

      // 提取特殊备注信息，如 "向爸转账 已被接收", "微信转账", "手写小票" 等
      if (trimmed.contains('转账') ||
          trimmed.contains('接收') ||
          trimmed.contains('小票') ||
          trimmed.contains('备注') ||
          trimmed.contains('特殊') ||
          trimmed.contains('客人') ||
          trimmed.contains('下雨') ||
          trimmed.contains('备菜') ||
          trimmed.contains('调料')) {
        // 如果这行不单纯是数字支出行，计入备注
        if (!trimmed.contains('支出') && !trimmed.contains('收入')) {
          specialNotes.add(trimmed);
        }
      }

      // 匹配成员支出行，例如：
      // "红章支出 333.5元"
      // "9月19日红章支出 333.5元"
      // "我支出 6.5元"
      // "烨文支出22元"
      // "坤艳支出6元"
      // "张三 50元 买菜"
      final expensePattern = RegExp(
        r'(?:(?:\d{1,2}月\d{1,2}日)?\s*)?([^\d\s,，.。:：]+?)(?:支出|花费|花了|用去|采购|出账)?\s*[:：]?\s*([0-9]+(?:\.[0-9]+)?)\s*(?:元|块|RMB)?(?:\s*(.*))?',
        caseSensitive: false,
      );

      final match = expensePattern.firstMatch(trimmed);
      if (match != null) {
        String rawName = match.group(1)?.trim() ?? '';
        String amountStr = match.group(2)?.trim() ?? '';
        String extraNote = match.group(3)?.trim() ?? '';

        // 清洗人名中的无用前缀（如日期、"妈"发的消息前缀等）
        rawName = rawName.replaceAll(RegExp(r'^\d{1,2}月\d{1,2}日'), '').trim();
        rawName = rawName.replaceAll(RegExp(r'^(?:妈|爸|微信|用户)[:：\s]*'), '').trim();

        // 过滤掉非人名关键词
        if (rawName == '共' ||
            rawName == '总' ||
            rawName == '合计' ||
            rawName == '收入' ||
            rawName == '入账' ||
            rawName.isEmpty) {
          continue;
        }

        double? amount = double.tryParse(amountStr);
        if (amount != null && amount > 0) {
          // 应用别名映射：如果提取到的称谓在别名字典中（如 "我" -> "坤茹"），替换为真实人名
          String finalName = aliasMap[rawName] ?? rawName;

          expenseItems.add(ExpenseItem(
            personName: finalName,
            amount: amount,
            category: _inferCategory(extraNote, trimmed),
            note: extraNote.isNotEmpty ? extraNote : trimmed,
          ));
        }
      }
    }

    // 如果文本中包含微信提示或特殊情况，整合进每日备注
    String specialNoteResult = specialNotes.join('；');
    if (specialNoteResult.isEmpty && text.contains('向爸转账')) {
      specialNoteResult = '向爸转账已被接收';
    }

    return DailyLedger(
      date: extractedDate,
      totalIncome: totalIncome,
      expenses: expenseItems,
      specialNote: specialNoteResult,
      rawText: text,
      imagePath: imagePath,
    );
  }

  /// 提取日期（支持 "9月19日", "2023-09-19", "2023/09/19", "09-19" 等）
  String _extractDate(String text) {
    final now = DateTime.now();

    // 匹配完整年月日：2023年9月19日 或 2023-09-19
    final fullDateRegex = RegExp(r'(\d{4})[年\-\/](\d{1,2})[月\-\/](\d{1,2})日?');
    final fullMatch = fullDateRegex.firstMatch(text);
    if (fullMatch != null) {
      int y = int.parse(fullMatch.group(1)!);
      int m = int.parse(fullMatch.group(2)!);
      int d = int.parse(fullMatch.group(3)!);
      return DateFormat('yyyy-MM-dd').format(DateTime(y, m, d));
    }

    // 匹配月日：9月19日 或 9-19 或 09/19
    final monthDayRegex = RegExp(r'(\d{1,2})[月\-\/](\d{1,2})日?');
    final mdMatch = monthDayRegex.firstMatch(text);
    if (mdMatch != null) {
      int m = int.parse(mdMatch.group(1)!);
      int d = int.parse(mdMatch.group(2)!);
      return DateFormat('yyyy-MM-dd').format(DateTime(now.year, m, d));
    }

    // 默认返回当前日期
    return DateFormat('yyyy-MM-dd').format(now);
  }

  /// 自动推断支出类别
  String _inferCategory(String extraNote, String fullLine) {
    final combined = '$extraNote $fullLine';
    if (combined.contains('菜') || combined.contains('肉') || combined.contains('蛋') || combined.contains('油') || combined.contains('米')) {
      return '食材采购';
    }
    if (combined.contains('调料') || combined.contains('配料') || combined.contains('酱')) {
      return '调料备料';
    }
    if (combined.contains('电') || combined.contains('水') || combined.contains('气') || combined.contains('房租')) {
      return '水电租金';
    }
    if (combined.contains('餐具') || combined.contains('包装') || combined.contains('袋') || combined.contains('纸')) {
      return '物料耗材';
    }
    if (combined.contains('工资') || combined.contains('人工')) {
      return '员工薪资';
    }
    return '日常支出';
  }

  /// 在线 LLM 智能多模态/文本解析（支持自定义 AI 提示词）
  Future<DailyLedger?> _parseWithLlm(
    String rawText,
    AppSettings settings,
    List<AliasRule> aliases, {
    String? imagePath,
  }) async {
    String aliasPrompt = aliases.map((a) => "'${a.alias}' -> '${a.realName}'").join(', ');
    if (aliasPrompt.isEmpty) {
      aliasPrompt = "'我' 映射为 '坤茹', '妈' 映射为 '坤茹'";
    }

    // 使用用户自定义提示词，并将 {alias_rules} 占位符替换为当前别名规则
    String systemPrompt = settings.customPrompt.isNotEmpty
        ? settings.customPrompt
        : AppSettings.defaultSystemPrompt;

    if (systemPrompt.contains('{alias_rules}')) {
      systemPrompt = systemPrompt.replaceAll('{alias_rules}', aliasPrompt);
    } else {
      systemPrompt = '$systemPrompt\n【别名映射规则】: $aliasPrompt';
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
            note: item['note'] ?? '',
          ));
        }
      }

      return DailyLedger(
        date: jsonMap['date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
        totalIncome: (jsonMap['totalIncome'] as num?)?.toDouble() ?? 0.0,
        expenses: items,
        specialNote: jsonMap['specialNote'] ?? '',
        rawText: rawText,
        imagePath: imagePath,
      );
    }
    return null;
  }
}
