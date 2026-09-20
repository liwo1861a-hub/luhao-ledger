class AppSettings {
  String aiProvider; // 'deepseek' | 'gemini' | 'openai' | 'custom' | 'offline_rules'
  String apiEndpoint;
  String apiKey;
  String modelName;
  String customPrompt;
  bool enableAutoAlias;
  bool autoRecognizeNames;

  AppSettings({
    this.aiProvider = 'offline_rules',
    this.apiEndpoint = 'https://api.deepseek.com/v1/chat/completions',
    this.apiKey = '',
    this.modelName = 'deepseek-chat',
    this.customPrompt = '',
    this.enableAutoAlias = true,
    this.autoRecognizeNames = true,
  });

  Map<String, dynamic> toJson() => {
    'aiProvider': aiProvider,
    'apiEndpoint': apiEndpoint,
    'apiKey': apiKey,
    'modelName': modelName,
    'customPrompt': customPrompt,
    'enableAutoAlias': enableAutoAlias,
    'autoRecognizeNames': autoRecognizeNames,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    aiProvider: json['aiProvider'] ?? 'offline_rules',
    apiEndpoint: json['apiEndpoint'] ?? 'https://api.deepseek.com/v1/chat/completions',
    apiKey: json['apiKey'] ?? '',
    modelName: json['modelName'] ?? 'deepseek-chat',
    customPrompt: json['customPrompt'] ?? '',
    enableAutoAlias: json['enableAutoAlias'] ?? true,
    autoRecognizeNames: json['autoRecognizeNames'] ?? true,
  );
}
