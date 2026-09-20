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

  static const String defaultSystemPrompt = '''你是一个智能财务记账助手。请从用户输入的记账文本或微信聊天记录中提取结构化财务数据，并严格输出纯 JSON 格式。
【核心硬性规则】：
1. 别名与人名映射：{alias_rules}。如 "我" 或 "妈" 必须映射为 "坤茹"，并自动识别 "红章"、"烨文"、"坤艳" 等所有成员人名。
2. 严禁只输出总收入和总支出！必须为【每一个成员】分别输出独立的支出对象到 "expenses" 数组中（如红章支出 333.5元，我支出 6.5元，则 expenses 必须分别包含红章和坤茹两条记录）。
3. 提取单日总收入（如 "收入 473.5元"），严禁将总支出汇总混入单人支出。
4. 提取日期（格式 YYYY-MM-DD，若只有月日则按指定年份 {target_year} 拼接）。
5. 类别固定为 "日常支出"，备注保持为空字符串 ""（由用户自行在界面中填写特殊情况备注）。

【输出 JSON Schema 示例】：
{
  "date": "2023-09-19",
  "totalIncome": 473.5,
  "specialNote": "",
  "expenses": [
    {"personName": "红章", "amount": 333.5, "category": "日常支出", "note": ""},
    {"personName": "坤茹", "amount": 6.5, "category": "日常支出", "note": ""},
    {"personName": "烨文", "amount": 22.0, "category": "日常支出", "note": ""},
    {"personName": "坤艳", "amount": 6.0, "category": "日常支出", "note": ""}
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
    autoAiAfterOcr: json['autoAiAfterOcr'] == 1 || json['autoAiAfterOcr'] == true,
    enableAutoAlias: json['enableAutoAlias'] == 1 || json['enableAutoAlias'] == true,
    autoRecognizeNames: json['autoRecognizeNames'] == 1 || json['autoRecognizeNames'] == true,
    customBackupPath: json['customBackupPath'] ?? '',
  );

  AppSettings copyWith({
    String? aiProvider,
    String? apiEndpoint,
    String? apiKey,
    String? modelName,
    String? customPrompt,
    bool? autoAiAfterOcr,
    bool? enableAutoAlias,
    bool? autoRecognizeNames,
    String? customBackupPath,
  }) {
    return AppSettings(
      aiProvider: aiProvider ?? this.aiProvider,
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
      customPrompt: customPrompt ?? this.customPrompt,
      autoAiAfterOcr: autoAiAfterOcr ?? this.autoAiAfterOcr,
      enableAutoAlias: enableAutoAlias ?? this.enableAutoAlias,
      autoRecognizeNames: autoRecognizeNames ?? this.autoRecognizeNames,
      customBackupPath: customBackupPath ?? this.customBackupPath,
    );
  }
}
