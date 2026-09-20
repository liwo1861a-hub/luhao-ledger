import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ledger_models.dart';
import '../models/app_settings.dart';
import 'database_service.dart';
import 'ai_parser_service.dart';
import 'ocr_service.dart';

class LedgerProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final AiParserService _ai = AiParserService.instance;
  final OcrService _ocr = OcrService.instance;

  List<DailyLedger> _dailyRecords = [];
  List<DailyLedger> get dailyRecords => _dailyRecords;

  int _selectedYear = DateTime.now().year;
  int get selectedYear => _selectedYear;

  int _selectedMonthNum = DateTime.now().month;
  int get selectedMonthNum => _selectedMonthNum;

  List<int> _availableYears = [];
  List<int> get availableYears => _availableYears;

  Set<String> _monthsWithData = {};
  Set<String> get monthsWithData => _monthsWithData;

  String get selectedMonthKey => '$_selectedYear-${_selectedMonthNum.toString().padLeft(2, '0')}';
  String get selectedMonth => selectedMonthKey;

  List<String> get availableMonths => List.generate(12, (i) => '$_selectedYear-${(i + 1).toString().padLeft(2, '0')}');

  MonthlyStats? _monthlyStats;
  MonthlyStats? get monthlyStats => _monthlyStats;

  AllTimeStats? _allTimeStats;
  AllTimeStats? get allTimeStats => _allTimeStats;

  List<AliasRule> _aliasRules = [];
  List<AliasRule> get aliasRules => _aliasRules;

  AppSettings _settings = AppSettings();
  AppSettings get settings => _settings;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  LedgerProvider() {
    init();
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    _settings = await _db.getSettings();
    _aliasRules = await _db.getAliasRules();
    await _refreshAvailableYearsAndMonths();

    await reloadStatsAndRecords();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _refreshAvailableYearsAndMonths() async {
    final allDbMonths = await _db.getAvailableMonths();
    _monthsWithData = allDbMonths.toSet();

    Set<int> years = {DateTime.now().year, 2025, 2024, 2023};
    for (var m in allDbMonths) {
      if (m.length >= 4) {
        final y = int.tryParse(m.substring(0, 4));
        if (y != null) years.add(y);
      }
    }
    _availableYears = years.toList()..sort((a, b) => b.compareTo(a));

    if (!_availableYears.contains(_selectedYear)) {
      _selectedYear = _availableYears.first;
    }
  }

  Future<void> setSelectedYear(int year) async {
    _selectedYear = year;
    await _refreshAvailableYearsAndMonths();
    await reloadStatsAndRecords();
  }

  Future<void> setSelectedMonthNum(int monthNum) async {
    _selectedMonthNum = monthNum;
    await reloadStatsAndRecords();
  }

  Future<void> setSelectedMonth(String month) async {
    if (month.length >= 7) {
      final parts = month.split('-');
      _selectedYear = int.tryParse(parts[0]) ?? _selectedYear;
      _selectedMonthNum = int.tryParse(parts[1]) ?? _selectedMonthNum;
    }
    await reloadStatsAndRecords();
  }

  Future<void> addCustomYear(int year) async {
    if (!_availableYears.contains(year)) {
      _availableYears.add(year);
      _availableYears.sort((a, b) => b.compareTo(a));
    }
    await setSelectedYear(year);
  }

  Future<void> reloadStatsAndRecords() async {
    final key = selectedMonthKey;
    _dailyRecords = await _db.getRecordsByMonth(key);
    _monthlyStats = await _db.getMonthlyStats(key);
    _allTimeStats = await _db.getAllTimeStats();
    _aliasRules = await _db.getAliasRules();
    final allDbMonths = await _db.getAvailableMonths();
    _monthsWithData = allDbMonths.toSet();
    notifyListeners();
  }

  Future<void> saveRecord(DailyLedger record) async {
    await _db.saveDailyRecord(record);
    if (record.date.length >= 7) {
      final parts = record.date.split('-');
      if (parts.length >= 2) {
        _selectedYear = int.tryParse(parts[0]) ?? _selectedYear;
        _selectedMonthNum = int.tryParse(parts[1]) ?? _selectedMonthNum;
      }
    }
    await _refreshAvailableYearsAndMonths();
    await reloadStatsAndRecords();
  }

  Future<void> saveBatchRecords(List<DailyLedger> records) async {
    for (var r in records) {
      await _db.saveDailyRecord(r);
    }
    if (records.isNotEmpty && records.first.date.length >= 7) {
      final parts = records.first.date.split('-');
      if (parts.length >= 2) {
        _selectedYear = int.tryParse(parts[0]) ?? _selectedYear;
        _selectedMonthNum = int.tryParse(parts[1]) ?? _selectedMonthNum;
      }
    }
    await _refreshAvailableYearsAndMonths();
    await reloadStatsAndRecords();
  }

  Future<void> deleteRecord(String id) async {
    await _db.deleteDailyRecord(id);
    await _refreshAvailableYearsAndMonths();
    await reloadStatsAndRecords();
  }

  Future<void> saveAlias(String alias, String realName) async {
    final existing = _aliasRules.where((a) => a.alias == alias);
    String id = existing.isNotEmpty ? existing.first.id : '';
    final rule = AliasRule(id: id.isNotEmpty ? id : null, alias: alias.trim(), realName: realName.trim());
    await _db.saveAliasRule(rule);
    _aliasRules = await _db.getAliasRules();
    notifyListeners();
  }

  Future<void> deleteAlias(String id) async {
    await _db.deleteAliasRule(id);
    _aliasRules = await _db.getAliasRules();
    notifyListeners();
  }

  Future<void> saveSettings(AppSettings newSettings) async {
    _settings = newSettings;
    await _db.saveSettings(newSettings);
    notifyListeners();
  }

  /// 单张图片自动处理：免费 OCR 提取后立即全自动 AI 理解整理（绑定当前年月）
  Future<DailyLedger> processImage(File imageFile, {int? year}) async {
    final targetYear = year ?? _selectedYear;
    final ocrText = await _ocr.extractTextFromImage(imageFile);
    return await _ai.parseLedgerContent(ocrText, imagePath: imageFile.path, defaultYear: targetYear);
  }

  /// 批量图片自动处理
  Future<List<DailyLedger>> processBatchImages(
    List<File> imageFiles, {
    int? year,
    void Function(int current, int total, String status)? onProgress,
  }) async {
    final targetYear = year ?? _selectedYear;
    List<DailyLedger> results = [];
    int total = imageFiles.length;

    for (int i = 0; i < total; i++) {
      final file = imageFiles[i];
      if (onProgress != null) {
        onProgress(i + 1, total, '正在识别第 ${i + 1}/$total 张图片并自动 AI 整理...');
      }
      try {
        final ledger = await processImage(file, year: targetYear);
        results.add(ledger);
      } catch (_) {}
    }
    return results;
  }

  /// 智能解析纯文本或聊天记录（绑定当前年月）
  Future<DailyLedger> processText(String text, {int? year}) async {
    final targetYear = year ?? _selectedYear;
    return await _ai.parseLedgerContent(text, defaultYear: targetYear);
  }
}
