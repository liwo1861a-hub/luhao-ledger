import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/ledger_models.dart';
import '../models/app_settings.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'luhao_ledger_v1.db');

    final db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        // 每日账本主表
        await db.execute('''
          CREATE TABLE daily_records (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            total_income REAL NOT NULL,
            total_expense REAL NOT NULL,
            special_note TEXT,
            raw_text TEXT,
            image_path TEXT,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');

        // 成员支出明细表
        await db.execute('''
          CREATE TABLE expense_items (
            id TEXT PRIMARY KEY,
            daily_id TEXT NOT NULL,
            person_name TEXT NOT NULL,
            amount REAL NOT NULL,
            category TEXT,
            note TEXT,
            FOREIGN KEY (daily_id) REFERENCES daily_records (id) ON DELETE CASCADE
          )
        ''');

        // 别名规则表（如 '我' -> '坤茹', '妈' -> '坤茹'）
        await db.execute('''
          CREATE TABLE alias_rules (
            id TEXT PRIMARY KEY,
            alias TEXT NOT NULL UNIQUE,
            real_name TEXT NOT NULL
          )
        ''');

        // 应用配置表
        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');

        // 仅初始化默认别名映射规则，绝对不插入任何预设账单记录
        await _seedDefaultAliases(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // 升级时自动清理历史旧版本残留的示例数据
        await db.delete('expense_items', where: "daily_id = 'demo_2023_09_19'");
        await db.delete('daily_records', where: "id = 'demo_2023_09_19'");
      },
    );

    // 每次启动双重确认清理旧测试示例数据
    try {
      await db.delete('expense_items', where: "daily_id = 'demo_2023_09_19'");
      await db.delete('daily_records', where: "id = 'demo_2023_09_19'");
    } catch (_) {}

    return db;
  }

  Future<void> _seedDefaultAliases(Database db) async {
    final defaultAliases = [
      {'id': 'alias_1', 'alias': '我', 'real_name': '坤茹'},
      {'id': 'alias_2', 'alias': '妈', 'real_name': '坤茹'},
    ];
    for (var a in defaultAliases) {
      await db.insert('alias_rules', a, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ================= 账目 CRUD =================

  /// 获取所有每日记录（按日期降序）
  Future<List<DailyLedger>> getAllDailyRecords() async {
    final db = await database;
    final recordsData = await db.query('daily_records', orderBy: 'date DESC, created_at DESC');
    
    List<DailyLedger> result = [];
    for (var r in recordsData) {
      final itemsData = await db.query(
        'expense_items',
        where: 'daily_id = ?',
        whereArgs: [r['id']],
      );
      final items = itemsData.map((m) => ExpenseItem.fromMap(m)).toList();
      result.add(DailyLedger.fromMap(r, items));
    }
    return result;
  }

  /// 获取指定月份的每日记录（monthPrefix: '2023-09'）
  Future<List<DailyLedger>> getRecordsByMonth(String monthPrefix) async {
    final db = await database;
    final recordsData = await db.query(
      'daily_records',
      where: "date LIKE ?",
      whereArgs: ['$monthPrefix%'],
      orderBy: 'date DESC, created_at DESC',
    );

    List<DailyLedger> result = [];
    for (var r in recordsData) {
      final itemsData = await db.query(
        'expense_items',
        where: 'daily_id = ?',
        whereArgs: [r['id']],
      );
      final items = itemsData.map((m) => ExpenseItem.fromMap(m)).toList();
      result.add(DailyLedger.fromMap(r, items));
    }
    return result;
  }

  /// 插入或更新每日记录（包含其名下的成员支出明细）
  Future<void> saveDailyRecord(DailyLedger record) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'daily_records',
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 删除原有明细重新写入
      await txn.delete(
        'expense_items',
        where: 'daily_id = ?',
        whereArgs: [record.id],
      );

      for (var item in record.expenses) {
        await txn.insert(
          'expense_items',
          item.toMap(record.id),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// 删除某日的记录
  Future<void> deleteDailyRecord(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('expense_items', where: 'daily_id = ?', whereArgs: [id]);
      await txn.delete('daily_records', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ================= 统计分析计算 =================

  /// 计算指定月份的汇总统计
  Future<MonthlyStats> getMonthlyStats(String monthKey) async {
    final records = await getRecordsByMonth(monthKey);
    double totalIncome = 0;
    double totalExpense = 0;
    Map<String, double> personExpenses = {};

    for (var r in records) {
      totalIncome += r.totalIncome;
      totalExpense += r.totalExpense;
      for (var exp in r.expenses) {
        personExpenses[exp.personName] = (personExpenses[exp.personName] ?? 0.0) + exp.amount;
      }
    }

    return MonthlyStats(
      monthKey: monthKey,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netProfit: totalIncome - totalExpense,
      recordCount: records.length,
      personExpenses: personExpenses,
      dailyRecords: records,
    );
  }

  /// 计算全部历史记录的汇总统计
  Future<AllTimeStats> getAllTimeStats() async {
    final records = await getAllDailyRecords();
    double totalIncome = 0;
    double totalExpense = 0;
    Map<String, double> personExpenses = {};
    Set<String> months = {};

    for (var r in records) {
      totalIncome += r.totalIncome;
      totalExpense += r.totalExpense;
      if (r.date.length >= 7) {
        months.add(r.date.substring(0, 7));
      }
      for (var exp in r.expenses) {
        personExpenses[exp.personName] = (personExpenses[exp.personName] ?? 0.0) + exp.amount;
      }
    }

    return AllTimeStats(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netProfit: totalIncome - totalExpense,
      totalDays: records.length,
      totalMonths: months.length > 0 ? months.length : 1,
      personExpenses: personExpenses,
    );
  }

  /// 获取所有出现过的月份列表（降序）
  Future<List<String>> getAvailableMonths() async {
    final db = await database;
    final res = await db.rawQuery(
      "SELECT DISTINCT substr(date, 1, 7) as month FROM daily_records ORDER BY month DESC"
    );
    final list = res.map((e) => e['month'] as String? ?? '').where((m) => m.isNotEmpty).toList();
    if (list.isEmpty) {
      final currentMonth = DateTime.now().toIso8601String().substring(0, 7);
      return [currentMonth];
    }
    return list;
  }

  // ================= 别名规则 CRUD =================

  Future<List<AliasRule>> getAliasRules() async {
    final db = await database;
    final list = await db.query('alias_rules', orderBy: 'alias ASC');
    return list.map((e) => AliasRule.fromMap(e)).toList();
  }

  Future<void> saveAliasRule(AliasRule rule) async {
    final db = await database;
    await db.insert('alias_rules', rule.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteAliasRule(String id) async {
    final db = await database;
    await db.delete('alias_rules', where: 'id = ?', whereArgs: [id]);
  }

  // ================= 设置存储 =================

  Future<AppSettings> getSettings() async {
    final db = await database;
    final res = await db.query('app_settings', where: 'key = ?', whereArgs: ['main_config']);
    if (res.isNotEmpty) {
      try {
        final jsonMap = jsonDecode(res.first['value'] as String);
        return AppSettings.fromJson(jsonMap);
      } catch (_) {}
    }
    return AppSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': 'main_config', 'value': jsonEncode(settings.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ================= 备份与导出导入 =================

  Future<String> exportToJson() async {
    final records = await getAllDailyRecords();
    final aliases = await getAliasRules();
    final settings = await getSettings();

    final data = {
      'version': '1.0.3',
      'exportedAt': DateTime.now().toIso8601String(),
      'records': records.map((r) => r.toJson()).toList(),
      'aliases': aliases.map((a) => a.toJson()).toList(),
      'settings': settings.toJson(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> importFromJson(String jsonString) async {
    final data = jsonDecode(jsonString);
    if (data['records'] != null) {
      final recordsList = (data['records'] as List)
          .map((e) => DailyLedger.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      for (var r in recordsList) {
        await saveDailyRecord(r);
      }
    }
    if (data['aliases'] != null) {
      final aliasList = (data['aliases'] as List)
          .map((e) => AliasRule.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      for (var a in aliasList) {
        await saveAliasRule(a);
      }
    }
  }
}
