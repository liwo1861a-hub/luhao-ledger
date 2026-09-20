import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../models/ledger_models.dart';
import '../models/app_settings.dart';
import '../services/ledger_provider.dart';
import '../services/database_service.dart';
import '../services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentVersion = '1.0.2';
  bool _isCheckingUpdate = false;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;

  late TextEditingController _endpointCtrl;
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _backupPathCtrl;
  late TextEditingController _promptCtrl;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    final s = context.read<LedgerProvider>().settings;
    _endpointCtrl = TextEditingController(text: s.apiEndpoint);
    _apiKeyCtrl = TextEditingController(text: s.apiKey);
    _modelCtrl = TextEditingController(text: s.modelName);
    _backupPathCtrl = TextEditingController(text: s.customBackupPath);
    _promptCtrl = TextEditingController(text: s.customPrompt);
  }

  @override
  void dispose() {
    _endpointCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    _backupPathCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final meta = await UpdateService.instance.getLocalVersion();
    setState(() {
      _currentVersion = meta['version'] ?? '1.0.2';
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final settings = provider.settings;
    final aliases = provider.aliasRules;

    return Scaffold(
      appBar: AppBar(
        title: const Text('系统设置与规则', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 成员别名管理卡片
          _buildAliasSection(context, provider, aliases),
          const SizedBox(height: 16),

          // AI 模型配置卡片（默认 Gemini / gemini-3.7-flash）
          _buildAiConfigSection(context, provider, settings),
          const SizedBox(height: 16),

          // 自定义 AI 提示词模板卡片
          _buildPromptTemplateSection(context, provider, settings),
          const SizedBox(height: 16),

          // 全量数据备份与自定义下载路径
          _buildDataBackupSection(context, provider, settings),
          const SizedBox(height: 16),

          // 软件版本与在线更新
          _buildUpdateSection(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAliasSection(BuildContext context, LedgerProvider provider, List<AliasRule> aliases) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.people_alt, color: Colors.indigo),
                    SizedBox(width: 8),
                    Text('称谓别名映射规则', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _openAddAliasDialog(context, provider),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加别名'),
                ),
              ],
            ),
            const Text(
              '智能识别时，聊天中出现的称谓将自动映射为真实人名（如"我"、"妈"自动映射为"坤茹"）。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Divider(height: 16),

            if (aliases.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('暂无别名映射规则，默认识别原样人名'),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: aliases.map((a) {
                  return Chip(
                    backgroundColor: Colors.indigo.shade50,
                    avatar: const CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.person, size: 14, color: Colors.white),
                    ),
                    label: Text('${a.alias} ➔ ${a.realName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    onDeleted: () => provider.deleteAlias(a.id),
                    deleteIconColor: Colors.redAccent,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiConfigSection(BuildContext context, LedgerProvider provider, AppSettings settings) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.smart_toy, color: Colors.indigo),
                    SizedBox(width: 8),
                    Text('AI 与大模型接口设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    settings.aiProvider.toUpperCase(),
                    style: TextStyle(color: Colors.indigo.shade800, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('默认使用 Google Gemini (gemini-3.7-flash)，所有地址、密钥、模型均可自由修改并持久化保存。', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 20),

            DropdownButtonFormField<String>(
              value: settings.aiProvider,
              decoration: const InputDecoration(
                labelText: 'AI 引擎模式 (可修改)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'gemini', child: Text('Google Gemini API (默认推荐)')),
                DropdownMenuItem(value: 'deepseek', child: Text('DeepSeek API (深度求索)')),
                DropdownMenuItem(value: 'openai', child: Text('OpenAI / 兼容通道 (如通义/硅基流动/Ollama)')),
                DropdownMenuItem(value: 'offline_rules', child: Text('本地智能规则引擎 (完全免费离线)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  settings.aiProvider = val;
                  if (val == 'gemini') {
                    settings.apiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions';
                    settings.modelName = 'gemini-3.7-flash';
                  } else if (val == 'deepseek') {
                    settings.apiEndpoint = 'https://api.deepseek.com/v1/chat/completions';
                    settings.modelName = 'deepseek-chat';
                  } else if (val == 'openai') {
                    settings.apiEndpoint = 'https://api.openai.com/v1/chat/completions';
                    settings.modelName = 'gpt-4o-mini';
                  }
                  _endpointCtrl.text = settings.apiEndpoint;
                  _modelCtrl.text = settings.modelName;
                  provider.saveSettings(settings);
                }
              },
            ),

            const SizedBox(height: 12),
            TextField(
              controller: _endpointCtrl,
              decoration: const InputDecoration(
                labelText: 'API Endpoint 服务接口地址 (可自定义)',
                hintText: '如 https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                settings.apiEndpoint = v.trim();
                provider.saveSettings(settings);
              },
            ),

            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API Key 密钥 (可填入您的 Key)',
                hintText: '填入 AI 平台的 API 密钥',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                settings.apiKey = v.trim();
                provider.saveSettings(settings);
              },
            ),

            const SizedBox(height: 12),
            TextField(
              controller: _modelCtrl,
              decoration: const InputDecoration(
                labelText: '模型名称 Model (默认 gemini-3.7-flash，可自定义)',
                hintText: '如 gemini-3.7-flash / deepseek-chat / gpt-4o',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                settings.modelName = v.trim();
                provider.saveSettings(settings);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptTemplateSection(BuildContext context, LedgerProvider provider, AppSettings settings) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit_note, color: Colors.indigo),
                    SizedBox(width: 8),
                    Text('自定义 AI 提示词 (Prompt)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _promptCtrl.text = AppSettings.defaultSystemPrompt;
                      settings.customPrompt = AppSettings.defaultSystemPrompt;
                    });
                    provider.saveSettings(settings);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已恢复为官方默认提示词模板')),
                    );
                  },
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text('恢复默认'),
                ),
              ],
            ),
            const Text(
              '可自定义 AI 识别提取时的 System Prompt。支持保留 {alias_rules} 标签以自动注入成员别名字典。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Divider(height: 16),

            TextField(
              controller: _promptCtrl,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: '输入自定义 AI 系统提示词模板...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (v) {
                settings.customPrompt = v;
                provider.saveSettings(settings);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataBackupSection(BuildContext context, LedgerProvider provider, AppSettings settings) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.backup, color: Colors.indigo),
                SizedBox(width: 8),
                Text('全量信息备份与自定义下载', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '一键打包备份所有信息（每日账目、成员支出明细、特殊情况备注、人名别名映射、系统配置），下载存储地址完全支持自定义设置。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Divider(height: 20),

            // 自定义下载与保存目录配置
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _backupPathCtrl,
                    decoration: const InputDecoration(
                      labelText: '自定义备份下载存储目录',
                      hintText: '默认存储在应用文档目录，可点击右侧选择',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      settings.customBackupPath = v.trim();
                      provider.saveSettings(settings);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.folder_open),
                  tooltip: '选择自定义文件夹',
                  onPressed: () async {
                    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                    if (selectedDirectory != null) {
                      _backupPathCtrl.text = selectedDirectory;
                      settings.customBackupPath = selectedDirectory;
                      await provider.saveSettings(settings);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已设定自定义备份下载目录: $selectedDirectory')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 导出备份与导入还原按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _exportAllData(context, settings),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('备份下载全部信息'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _importData(context, provider),
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('导入备份数据'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateSection(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.system_update, color: Colors.indigo),
                    SizedBox(width: 8),
                    Text('软件更新', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                  child: Text('v$_currentVersion', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('基于永久固定签名构建，支持应用内一键下载更新并就地覆盖安装。', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 20),

            if (_isDownloading) ...[
              LinearProgressIndicator(value: _downloadProgress > 0 ? _downloadProgress : null),
              const SizedBox(height: 8),
              Center(child: Text('正在下载新版本: ${(_downloadProgress * 100).toStringAsFixed(1)}%')),
            ] else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isCheckingUpdate ? null : _checkForUpdate,
                  icon: _isCheckingUpdate
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.refresh),
                  label: Text(_isCheckingUpdate ? '正在检查最新版本...' : '检查软件更新'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openAddAliasDialog(BuildContext context, LedgerProvider provider) {
    final aliasCtrl = TextEditingController();
    final realNameCtrl = TextEditingController(text: '坤茹');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加称谓别名映射'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: aliasCtrl,
              decoration: const InputDecoration(labelText: '称谓别名（如：我、老妈、爸等）', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: realNameCtrl,
              decoration: const InputDecoration(labelText: '真实对应人名（如：坤茹、红章等）', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              if (aliasCtrl.text.trim().isNotEmpty && realNameCtrl.text.trim().isNotEmpty) {
                await provider.saveAlias(aliasCtrl.text.trim(), realNameCtrl.text.trim());
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAllData(BuildContext context, AppSettings settings) async {
    try {
      final jsonStr = await DatabaseService.instance.exportToJson();

      String targetDir;
      if (settings.customBackupPath.isNotEmpty && Directory(settings.customBackupPath).existsSync()) {
        targetDir = settings.customBackupPath;
      } else {
        final dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
        targetDir = dir.path;
      }

      final fileName = 'smart_ledger_full_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('$targetDir/$fileName');
      await file.writeAsString(jsonStr);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('全量信息备份成功'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('已将所有账目、成员明细、特殊备注、别名与配置导出！'),
                const SizedBox(height: 10),
                Text('保存路径:\n${file.path}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  OpenFilex.open(file.path);
                },
                child: const Text('打开文件'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份导出失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importData(BuildContext context, LedgerProvider provider) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        await DatabaseService.instance.importFromJson(content);
        await provider.init();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('全量数据导入并同步成功！'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _checkForUpdate() async {
    setState(() => _isCheckingUpdate = true);
    final update = await UpdateService.instance.checkForUpdate();
    setState(() => _isCheckingUpdate = false);

    if (!mounted) return;

    if (update.hasUpdate) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('发现新版本 v${update.latestVersion}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('发布日期: ${update.releaseDate}'),
              const SizedBox(height: 8),
              const Text('更新日志:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(update.changelog),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('稍后再说')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                _startDownload(update.apkDownloadUrl);
              },
              child: const Text('立即更新'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前已是最新版本！'), backgroundColor: Colors.green),
      );
    }
  }

  void _startDownload(String url) {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    UpdateService.instance.downloadAndInstallApk(
      url,
      onProgress: (p) => setState(() => _downloadProgress = p),
      onError: (err) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
      },
    ).then((_) {
      setState(() => _isDownloading = false);
    });
  }
}
