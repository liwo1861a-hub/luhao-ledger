import 'dart:convert';
import 'package:uuid/uuid.dart';

/// 单笔成员支出明细
class ExpenseItem {
  final String id;
  String personName;
  double amount;
  String category;
  String note;

  ExpenseItem({
    String? id,
    required this.personName,
    required this.amount,
    this.category = '日常支出',
    this.note = '',
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap(String dailyId) {
    return {
      'id': id,
      'daily_id': dailyId,
      'person_name': personName,
      'amount': amount,
      'category': category,
      'note': note,
    };
  }

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    return ExpenseItem(
      id: map['id'] ?? '',
      personName: map['person_name'] ?? '未命名',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? '日常支出',
      note: map['note'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'personName': personName,
    'amount': amount,
    'category': category,
    'note': note,
  };

  factory ExpenseItem.fromJson(Map<String, dynamic> json) => ExpenseItem(
    id: json['id'] ?? const Uuid().v4(),
    personName: json['personName'] ?? '未命名',
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    category: json['category'] ?? '日常支出',
    note: json['note'] ?? '',
  );

  ExpenseItem copyWith({
    String? id,
    String? personName,
    double? amount,
    String? category,
    String? note,
  }) {
    return ExpenseItem(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
    );
  }
}

/// 每日账目总表（包含单日总收入、各成员支出列表、特殊情况备注）
class DailyLedger {
  final String id;
  String date; // yyyy-MM-dd
  double totalIncome; // 当日总收入
  List<ExpenseItem> expenses; // 各成员支出明细
  String specialNote; // 每日特殊情况备注
  String rawText; // 原始聊天/OCR提取文字
  String? imagePath;
  int createdAt;
  int updatedAt;

  DailyLedger({
    String? id,
    required this.date,
    this.totalIncome = 0.0,
    List<ExpenseItem>? expenses,
    this.specialNote = '',
    this.rawText = '',
    this.imagePath,
    int? createdAt,
    int? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        expenses = expenses ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  /// 计算当日总支出
  double get totalExpense {
    if (expenses.isEmpty) return 0.0;
    return expenses.fold<double>(0.0, (sum, item) => sum + item.amount);
  }

  /// 计算当日净结余（收入 - 支出）
  double get netProfit => totalIncome - totalExpense;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'total_income': totalIncome,
      'total_expense': totalExpense,
      'special_note': specialNote,
      'raw_text': rawText,
      'image_path': imagePath,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory DailyLedger.fromMap(Map<String, dynamic> map, List<ExpenseItem> items) {
    return DailyLedger(
      id: map['id'] ?? '',
      date: map['date'] ?? '',
      totalIncome: (map['total_income'] as num?)?.toDouble() ?? 0.0,
      expenses: items,
      specialNote: map['special_note'] ?? '',
      rawText: map['raw_text'] ?? '',
      imagePath: map['image_path'],
      createdAt: map['created_at'] as int?,
      updatedAt: map['updated_at'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'totalIncome': totalIncome,
    'totalExpense': totalExpense,
    'netProfit': netProfit,
    'expenses': expenses.map((e) => e.toJson()).toList(),
    'specialNote': specialNote,
    'rawText': rawText,
    'imagePath': imagePath,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory DailyLedger.fromJson(Map<String, dynamic> json) => DailyLedger(
    id: json['id'] ?? const Uuid().v4(),
    date: json['date'] ?? '',
    totalIncome: (json['totalIncome'] as num?)?.toDouble() ?? 0.0,
    expenses: (json['expenses'] as List<dynamic>?)
            ?.map((e) => ExpenseItem.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [],
    specialNote: json['specialNote'] ?? '',
    rawText: json['rawText'] ?? '',
    imagePath: json['imagePath'],
    createdAt: json['createdAt'] as int?,
    updatedAt: json['updatedAt'] as int?,
  );

  DailyLedger copyWith({
    String? id,
    String? date,
    double? totalIncome,
    List<ExpenseItem>? expenses,
    String? specialNote,
    String? rawText,
    String? imagePath,
    int? createdAt,
    int? updatedAt,
  }) {
    return DailyLedger(
      id: id ?? this.id,
      date: date ?? this.date,
      totalIncome: totalIncome ?? this.totalIncome,
      expenses: expenses ?? this.expenses.map((e) => e.copyWith()).toList(),
      specialNote: specialNote ?? this.specialNote,
      rawText: rawText ?? this.rawText,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// 成员别名映射规则
class AliasRule {
  final String id;
  String alias; // 称谓别名，如 "我", "妈"
  String realName; // 真实人名，如 "坤茹"

  AliasRule({
    String? id,
    required this.alias,
    required this.realName,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() => {
    'id': id,
    'alias': alias,
    'real_name': realName,
  };

  factory AliasRule.fromMap(Map<String, dynamic> map) => AliasRule(
    id: map['id'] ?? '',
    alias: map['alias'] ?? '',
    realName: map['real_name'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'alias': alias,
    'realName': realName,
  };

  factory AliasRule.fromJson(Map<String, dynamic> json) => AliasRule(
    id: json['id'] ?? const Uuid().v4(),
    alias: json['alias'] ?? '',
    realName: json['realName'] ?? '',
  );
}

/// 月度汇总统计模型
class MonthlyStats {
  final String monthKey; // yyyy-MM
  final double totalIncome;
  final double totalExpense;
  final double netProfit;
  final int recordCount;
  final Map<String, double> personExpenses; // 每个人的支出总额
  final List<DailyLedger> dailyRecords;

  MonthlyStats({
    required this.monthKey,
    required this.totalIncome,
    required this.totalExpense,
    required this.netProfit,
    required this.recordCount,
    required this.personExpenses,
    required this.dailyRecords,
  });
}

/// 全部记录总汇总统计模型
class AllTimeStats {
  final double totalIncome;
  final double totalExpense;
  final double netProfit;
  final int totalDays;
  final int totalMonths;
  final Map<String, double> personExpenses; // 累计每个人支出

  AllTimeStats({
    required this.totalIncome,
    required this.totalExpense,
    required this.netProfit,
    required this.totalDays,
    required this.totalMonths,
    required this.personExpenses,
  });
}
