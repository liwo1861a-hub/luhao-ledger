class AppSettings {
  String aiProvider; // 'gemini' | 'deepseek' | 'openai' | 'offline_rules' | 'custom'
  String apiEndpoint;
  String apiKey;
  String modelName;
  String customPrompt; // 自定义 AI 提示词
  bool autoAiAfterOcr; // OCR 完成后自动执行 AI 整理
  bool enableAutoAlias;
  bool autoRecognizeNames;
  String customBackupPath; // 自定义备份与下载保存路径

  static const String defaultSystemPrompt = '''你是一个智能财务记账助手。请从用户输入的记账文本或聊天记录中提取结构化财务数据，并严格输出纯 JSON 格式。
【核心规则】：
1. 别名与人名映射：{alias_rules}。其他如 "红章"、"烨文"、"坤艳" 等需自动识别为人名并记录其独立支出。
2. 提取单日总收入（如 "收入 473.5元"）。
3. 提取每个人具体的支出项（人名、金额、分类、备注），严禁将总支出汇总计入单人。
4. 提取日期（格式 YYYY-MM-DD，若只有月日则默认当前年份）。
5. 提取每日特殊情况备注（如转账记录、手写小票说明、特殊事件等）。

【输出 JSON Schema 示例】：
{
  "date": "2023-09-19",
  "totalIncome": 473.5,
  "specialNote": "向爸转账已被接收",
  "expenses": [
    {"personName": "红章", "amount": 333.5, "category": "食材采购", "note": "9月19日红章支出"},
    {"personName": "坤茹", "amount": 6.5, "category": "零星开支", "note": "我支出 6.5元"},
    {"personName": "烨文", "amount": 22.0, "category": "日常支出", "note": "烨文支出22元"},
    {"personName": "坤艳", "amount": 6.0, "category": "日常支出", "note": "坤艳支出6元"}
  ]
}
只输出纯 JSON，不要包含任何 markdown 标签或多余解释。''';

  AppSettings({
    this.aiProvider = 'gemini',
    this.apiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    this.apiKey = '',
    this.modelName = 'gemini-3.7-flash',
    String? customPrompt,
    this.autoAiAfterOcr = true,
    this.enableAutoAlias = true,
    this.autoRecognizeNames = true,
    this.customBackupPath = '',
  }) : customPrompt = customPrompt ?? defaultSystemPrompt;

  Map<String, dynamic> toJson() => {
    'aiProvider': aiProvider,
    'apiEndpoint': apiEndpoint,
    'apiKey': apiKey,
    'modelName': modelName,
    'customPrompt': customPrompt,
    'autoAiAfterOcr': autoAiAfterOcr,
    'enableAutoAlias': enableAutoAlias,
    'autoRecognizeNames': autoRecognizeNames,
    'customBackupPath': customBackupPath,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    aiProvider: json['aiProvider'] ?? 'gemini',
    apiEndpoint: json['apiEndpoint'] ?? 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    apiKey: json['apiKey'] ?? '',
    modelName: json['modelName'] ?? 'gemini-3.7-flash',
    customPrompt: json['customPrompt'] ?? defaultSystemPrompt,
    autoAiAfterOcr: json['autoAiAfterOcr'] ?? true,
    enableAutoAlias: json['enableAutoAlias'] ?? true,
    autoRecognizeNames: json['autoRecognizeNames'] ?? true,
    customBackupPath: json['customBackupPath'] ?? '',
  );
}
