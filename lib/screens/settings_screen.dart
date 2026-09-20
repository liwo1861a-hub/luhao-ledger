import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/ledger_models.dart';
import '../models/app_settings.dart';
import '../services/ledger_provider.dart';
import '../services/backup_service.dart';
import '../services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _endpointCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _promptCtrl;
  late TextEditingController _cfUrlCtrl;
  late TextEditingController _cfTokenCtrl;

  bool _isCheckingUpdate = false;
  String _currentVersion = '1.0.7';
  UpdateInfo? _latestUpdateInfo;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<LedgerProvider>().settings;
    _apiKeyCtrl = TextEditingController(text: settings.apiKey);
    _endpointCtrl = TextEditingController(text: settings.apiEndpoint);
    _modelCtrl = TextEditingController(text: settings.modelName);
    _promptCtrl = TextEditingController(text: settings.customPrompt);
    _cfUrlCtrl = TextEditingController(text: settings.cloudflareWorkerUrl);
    _cfTokenCtrl = TextEditingController(text: settings.cloudflareAuthToken);
    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    final meta = await UpdateService.instance.getLocalVersion();
    setState(() {
      _currentVersion = meta['version'] ?? '1.0.7';
    });
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _endpointCtrl.dispose();
    _modelCtrl.dispose();
    _promptCtrl.dispose();
    _cfUrlCtrl.dispose();
    _cfTokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final settings = provider.settings;
    final aliases = provider.aliasRules;

    return Scaffold(
      appBar: AppBar(
        title: const Text('规则与系统设置', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 称谓别名映射管理
          _buildAliasSection(context, provider, aliases),
          const SizedBox(height: 16),

          // ☁️ Cloudflare 财务系统云端双向同步卡片
          _buildCloudflareSyncSection(context, provider, settings),
          const SizedBox(height: 16),

          // AI 模型与接口配置
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

  // ☁️ Cloudflare 财务系统云端同步卡片
  Widget _buildCloudflareSyncSection(BuildContext context, LedgerProvider provider, AppSettings settings) {
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
                    Icon(Icons.cloud_sync, color: Colors.indigo),
                    SizedBox(width: 8),
                    Text('Cloudflare 财务系统同步', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: settings.cloudflareWorkerUrl.isNotEmpty ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    settings.cloudflareWorkerUrl.isNotEmpty ? '已配置' : '未连接',
                    style: TextStyle(
                      color: settings.cloudflareWorkerUrl.isNotEmpty ? Colors.green.shade700 : Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '支持与您的 Cloudflare Worker (财务管理 v6.3.1) 进行双向无缝实时数据同步。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Divider(height: 16),

            // Worker 域名输入
            TextField(
              controller: _cfUrlCtrl,
              decoration: InputDecoration(
                labelText: 'Cloudflare Worker 部署地址',
                hintText: '如 https://your-finance.workers.dev',
                prefixIcon: const Icon(Icons.link, color: Colors.indigo),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey.shade50,
                isDense: true,
              ),
              onChanged: (v) {
                settings.cloudflareWorkerUrl = v.trim();
                provider.saveSettings(settings);
              },
            ),
            const SizedBox(height: 10),

            // Auth Token 输入
            TextField(
              controller: _cfTokenCtrl,
              decoration: InputDecoration(
                labelText: '同步授权 Token (Authorization)',
                hintText: '默认 auth_lz_mode',
                prefixIcon: const Icon(Icons.key, color: Colors.indigo),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey.shade50,
                isDense: true,
              ),
              onChanged: (v) {
                settings.cloudflareAuthToken = v.trim();
                provider.saveSettings(settings);
              },
            ),
            const SizedBox(height: 8),

            // 自动静默同步开关
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('记账后自动推送到 Cloudflare', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text('本地每次新增或修改账目后，自动静默同步到云端', style: TextStyle(fontSize: 11, color: Colors.grey)),
              value: settings.autoSyncCloudflare,
              activeColor: Colors.indigo,
              onChanged: (val) {
                setState(() => settings.autoSyncCloudflare = val);
                provider.saveSettings(settings);
              },
            ),
            const SizedBox(height: 8),

            // 两个核心双向同步操作按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: provider.isSyncingCloudflare
                        ? null
                        : () async {
                            final res = await provider.pullFromCloudflare();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.message),
                                  backgroundColor: res.success ? Colors.green : Colors.redAccent,
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.cloud_download, size: 16),
                    label: const Text('从云端拉取导入', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: provider.isSyncingCloudflare
                        ? null
                        : () async {
                            final res = await provider.pushToCloudflare();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.message),
                                  backgroundColor: res.success ? Colors.green : Colors.redAccent,
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.cloud_upload, size: 16),
                    label: const Text('推送到云端覆盖', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
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
                    settings.aiProvider == 'gemini' ? 'Gemini 3.7 Flash' : settings.aiProvider.toUpperCase(),
                    style: const TextStyle(color: Colors.indigo, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),

            // AI 服务商切换
            DropdownButtonFormField<String>(
              value: settings.aiProvider,
              decoration: const InputDecoration(
                labelText: '默认 AI 服务商',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'gemini', child: Text('Google Gemini (默认推荐 gemini-3.7-flash)')),
                DropdownMenuItem(value: 'deepseek', child: Text('DeepSeek 官方 (deepseek-chat)')),
                DropdownMenuItem(value: 'openai', child: Text('OpenAI / 兼容通道 (GPT-4o)')),
                DropdownMenuItem(value: 'custom', child: Text('自定义兼容 API 协议')),
                DropdownMenuItem(value: 'offline_rules', child: Text('纯离线智能规则引擎 (无需联网与Key)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    settings.aiProvider = val;
                    if (val == 'gemini') {
                      _endpointCtrl.text = 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions';
                      _modelCtrl.text = 'gemini-3.7-flash';
                      settings.apiEndpoint = _endpointCtrl.text;
                      settings.modelName = _modelCtrl.text;
                    } else if (val == 'deepseek') {
                      _endpointCtrl.text = 'https://api.deepseek.com/chat/completions';
                      _modelCtrl.text = 'deepseek-chat';
                      settings.apiEndpoint = _endpointCtrl.text;
                      settings.modelName = _modelCtrl.text;
                    }
                  });
                  provider.saveSettings(settings);
                }
              },
            ),
            const SizedBox(height: 12),

            if (settings.aiProvider != 'offline_rules') ...[
              TextField(
                controller: _endpointCtrl,
                decoration: const InputDecoration(
                  labelText: 'API 接口 Endpoint',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) {
                  settings.apiEndpoint = v;
                  provider.saveSettings(settings);
                },
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _modelCtrl,
                decoration: const InputDecoration(
                  labelText: '模型名称 (Model Name)',
                  hintText: '如 gemini-3.7-flash, deepseek-chat',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) {
                  settings.modelName = v;
                  provider.saveSettings(settings);
                },
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _apiKeyCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API Key 密钥',
                  hintText: '输入您的 API Key',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) {
                  settings.apiKey = v;
                  provider.saveSettings(settings);
                },
              ),
            ],
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
              '可自定义 AI 识别提取时的 System Prompt。支持保留 {alias_rules} 和 {target_year} 标签。',
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
            const SizedBox(height: 4),
            const Text(
              '一键将本地所有单日明细、收支数据、别名配置导出为标准 JSON 或 CSV 表格备份。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Divider(height: 16),

            // 自定义备份路径
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_open, color: Colors.indigo),
              title: const Text('自定义备份保存目录', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(
                settings.customBackupPath.isNotEmpty ? settings.customBackupPath : '默认应用文档目录 (点击右侧设置)',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () async {
                  String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                  if (selectedDirectory != null) {
                    setState(() {
                      settings.customBackupPath = selectedDirectory;
                    });
                    provider.saveSettings(settings);
                  }
                },
                child: const Text('选择路径'),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _exportJsonBackup(context, settings.customBackupPath),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('导出全量备份 (JSON)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _exportCsvBackup(context, settings.customBackupPath),
                    icon: const Icon(Icons.table_view, size: 18),
                    label: const Text('导出表格 (CSV)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _importBackup(context, provider),
                icon: const Icon(Icons.upload_file),
                label: const Text('从外部 JSON 备份文件恢复数据'),
              ),
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
                    Text('软件版本与在线更新', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('v$_currentVersion', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
              ],
            ),
            const Divider(height: 16),

            if (_isDownloading) ...[
              LinearProgressIndicator(value: _downloadProgress > 0 ? _downloadProgress : null),
              const SizedBox(height: 8),
              Center(
                child: Text('正在下载新版安装包: ${(_downloadProgress * 100).toStringAsFixed(1)}%'),
              ),
            ] else if (_latestUpdateInfo != null && _latestUpdateInfo!.hasUpdate) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('发现新版本: v${_latestUpdateInfo!.latestVersion}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                    const SizedBox(height: 4),
                    Text(_latestUpdateInfo!.changelog, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _startDownloadAndInstall(_latestUpdateInfo!.apkDownloadUrl),
                      child: const Text('立即下载并就地升级'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isCheckingUpdate ? null : _checkUpdate,
                  icon: _isCheckingUpdate ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
                  label: Text(_isCheckingUpdate ? '正在检查...' : '检查软件更新'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _checkUpdate() async {
    setState(() => _isCheckingUpdate = true);
    try {
      final info = await UpdateService.instance.checkForUpdate();
      setState(() {
        _latestUpdateInfo = info;
        _isCheckingUpdate = false;
      });
      if (!info.hasUpdate && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已经是最新版本！')),
        );
      }
    } catch (e) {
      setState(() => _isCheckingUpdate = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查更新失败: $e')),
        );
      }
    }
  }

  Future<void> _startDownloadAndInstall(String url) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    await UpdateService.instance.downloadAndInstallApk(
      url,
      onProgress: (p) => setState(() => _downloadProgress = p),
      onError: (err) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.redAccent),
        );
      },
    );
  }

  Future<void> _exportJsonBackup(BuildContext context, String customPath) async {
    try {
      final path = await BackupService.instance.exportFullBackupJson(customPath: customPath);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('全量 JSON 备份已保存至:\n$path'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _exportCsvBackup(BuildContext context, String customPath) async {
    try {
      final path = await BackupService.instance.exportCsvSpreadsheet(customPath: customPath);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV 统计表格已保存至:\n$path'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _importBackup(BuildContext context, LedgerProvider provider) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result != null && result.files.single.path != null) {
        final count = await BackupService.instance.importBackupJson(File(result.files.single.path!));
        await provider.reloadStatsAndRecords();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('成功恢复 $count 条记账明细！'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败: $e')),
        );
      }
    }
  }

  void _openAddAliasDialog(BuildContext context, LedgerProvider provider) {
    final aliasCtrl = TextEditingController();
    final realCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加称谓别名映射'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: aliasCtrl,
              decoration: const InputDecoration(labelText: '聊天中出现的称谓 (如 "我", "妈", "爸")', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: realCtrl,
              decoration: const InputDecoration(labelText: '真实入账人名 (如 "坤茹", "红章")', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (aliasCtrl.text.isNotEmpty && realCtrl.text.isNotEmpty) {
                provider.saveAlias(aliasCtrl.text, realCtrl.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text('确定保存'),
          ),
        ],
      ),
    );
  }
}
