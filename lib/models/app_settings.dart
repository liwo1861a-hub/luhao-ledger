class AppSettings {
  String aiProvider; // 'gemini' | 'deepseek' | 'openai' | 'offline_rules' | 'custom'
  String apiEndpoint;
  String apiKey;
  String modelName;
  String customPrompt;
  bool enableAutoAlias;
  bool autoRecognizeNames;
  String customBackupPath; // 自定义备份与下载保存路径

  AppSettings({
    this.aiProvider = 'gemini',
    this.apiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    this.apiKey = '',
    this.modelName = 'gemini-3.7-flash',
    this.customPrompt = '',
    this.enableAutoAlias = true,
    this.autoRecognizeNames = true,
    this.customBackupPath = '',
  });

  Map<String, dynamic> toJson() => {
    'aiProvider': aiProvider,
    'apiEndpoint': apiEndpoint,
    'apiKey': apiKey,
    'modelName': modelName,
    'customPrompt': customPrompt,
    'enableAutoAlias': enableAutoAlias,
    'autoRecognizeNames': autoRecognizeNames,
    'customBackupPath': customBackupPath,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    aiProvider: json['aiProvider'] ?? 'gemini',
    apiEndpoint: json['apiEndpoint'] ?? 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    apiKey: json['apiKey'] ?? '',
    modelName: json['modelName'] ?? 'gemini-3.7-flash',
    customPrompt: json['customPrompt'] ?? '',
    enableAutoAlias: json['enableAutoAlias'] ?? true,
    autoRecognizeNames: json['autoRecognizeNames'] ?? true,
    customBackupPath: json['customBackupPath'] ?? '',
  );
}
