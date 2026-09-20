import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ledger_models.dart';
import '../models/app_settings.dart';
import 'database_service.dart';
import 'ai_parser_service.dart';
import 'ocr_service.dart';
import 'cloudflare_sync_service.dart';

class LedgerProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final AiParserService _ai = AiParserService.instance;
  final OcrService _ocr = OcrService.instance;
  final CloudflareSyncService _cfSync = CloudflareSyncService.instance;

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

  bool _isSyncingCloudflare = false;
  bool get isSyncingCloudflare => _isSyncingCloudflare;

  LedgerProvider() {
    init();
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    _settings = await _db.getSettings();
    _aliasRules = await _db.getAliasRules();
    await _refreshAvailableYearsAndMonths();

    // 读取上次退出时保存的年份与月份，保持界面状态一致
    final prefs = await SharedPreferences.getInstance();
    final savedYear = prefs.getInt('last_selected_year');
    final savedMonth = prefs.getInt('last_selected_month_num');

    if (savedYear != null) {
      if (!_availableYears.contains(savedYear)) {
        _availableYears.add(savedYear);
        _availableYears.sort((a, b) => b.compareTo(a));
      }
      _selectedYear = savedYear;
    }

    if (savedMonth != null && savedMonth >= 1 && savedMonth <= 12) {
      _selectedMonthNum = savedMonth;
    }

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

  Future<void> _persistSelectedDateState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_selected_year', _selectedYear);
    await prefs.setInt('last_selected_month_num', _selectedMonthNum);
  }

  Future<void> setSelectedYear(int year) async {
    _selectedYear = year;
    await _persistSelectedDateState();
    await _refreshAvailableYearsAndMonths();
    await reloadStatsAndRecords();
  }

  Future<void> setSelectedMonthNum(int monthNum) async {
    _selectedMonthNum = monthNum;
    await _persistSelectedDateState();
    await reloadStatsAndRecords();
  }

  Future<void> setSelectedMonth(String month) async {
    if (month.length >= 7) {
      final parts = month.split('-');
      _selectedYear = int.tryParse(parts[0]) ?? _selectedYear;
      _selectedMonthNum = int.tryParse(parts[1]) ?? _selectedMonthNum;
      await _persistSelectedDateState();
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
        await _persistSelectedDateState();
      }
    }
    await _refreshAvailableYearsAndMonths();
    await reloadStatsAndRecords();

    if (_settings.autoSyncCloudflare && _settings.cloudflareWorkerUrl.isNotEmpty) {
      _triggerSilentCloudflarePush();
    }
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
        await _persistSelectedDateState();
      }
    }
    await _refreshAvailableYearsAndMonths();
    await reloadStatsAndRecords();

    if (_settings.autoSyncCloudflare && _settings.cloudflareWorkerUrl.isNotEmpty) {
      _triggerSilentCloudflarePush();
    }
  }

  Future<void> deleteRecord(String id) async {
    await _db.deleteDailyRecord(id);
    await _refreshAvailableYearsAndMonths();
    await reloadStatsAndRecords();

    if (_settings.autoSyncCloudflare && _settings.cloudflareWorkerUrl.isNotEmpty) {
      _triggerSilentCloudflarePush();
    }
  }

  void _triggerSilentCloudflarePush() {
    _cfSync.pushToCloudflare(_settings).then((res) {
      // 静默后台同步完成
    }).catchError((_) {});
  }

  /// 从 Cloudflare Worker 拉取同步数据
  Future<CloudflareSyncResult> pullFromCloudflare() async {
    _isSyncingCloudflare = true;
    notifyListeners();

    final res = await _cfSync.pullFromCloudflare(_settings);
    if (res.success) {
      await _refreshAvailableYearsAndMonths();
      await reloadStatsAndRecords();
    }

    _isSyncingCloudflare = false;
    notifyListeners();
    return res;
  }

  /// 推送本地数据到 Cloudflare Worker
  Future<CloudflareSyncResult> pushToCloudflare() async {
    _isSyncingCloudflare = true;
    notifyListeners();

    final res = await _cfSync.pushToCloudflare(_settings);

    _isSyncingCloudflare = false;
    notifyListeners();
    return res;
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
