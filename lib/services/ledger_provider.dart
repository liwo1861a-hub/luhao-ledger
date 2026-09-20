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

  List<String> _availableMonths = [];
  List<String> get availableMonths => _availableMonths;

  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  String get selectedMonth => _selectedMonth;

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
    _availableMonths = await _db.getAvailableMonths();
    if (_availableMonths.isNotEmpty && !_availableMonths.contains(_selectedMonth)) {
      _selectedMonth = _availableMonths.first;
    }

    await reloadStatsAndRecords();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setSelectedMonth(String month) async {
    _selectedMonth = month;
    await reloadStatsAndRecords();
  }

  Future<void> reloadStatsAndRecords() async {
    _dailyRecords = await _db.getRecordsByMonth(_selectedMonth);
    _monthlyStats = await _db.getMonthlyStats(_selectedMonth);
    _allTimeStats = await _db.getAllTimeStats();
    _availableMonths = await _db.getAvailableMonths();
    _aliasRules = await _db.getAliasRules();
    notifyListeners();
  }

  Future<void> saveRecord(DailyLedger record) async {
    await _db.saveDailyRecord(record);
    // 如果新增的记录所在月份与当前月份不同，也可切至该月份
    if (record.date.length >= 7) {
      _selectedMonth = record.date.substring(0, 7);
    }
    await reloadStatsAndRecords();
  }

  Future<void> deleteRecord(String id) async {
    await _db.deleteDailyRecord(id);
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

  /// 智能解析图片（先执行 OCR，再执行 AI/智能规则提取）
  Future<DailyLedger> processImage(File imageFile) async {
    final ocrText = await _ocr.extractTextFromImage(imageFile);
    return await _ai.parseLedgerContent(ocrText, imagePath: imageFile.path);
  }

  /// 智能解析纯文本或聊天记录
  Future<DailyLedger> processText(String text) async {
    return await _ai.parseLedgerContent(text);
  }
}
