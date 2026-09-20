import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
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
  String _currentVersion = '1.0.0';
  bool _isCheckingUpdate = false;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final meta = await UpdateService.instance.getLocalVersion();
    setState(() {
      _currentVersion = meta['version'] ?? '1.0.0';
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

          // AI 模型配置卡片
          _buildAiConfigSection(context, provider, settings),
          const SizedBox(height: 16),

          // 数据备份与迁移
          _buildDataBackupSection(context, provider),
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
              '智能识别时，聊天中出现的称谓将自动映射为真实人名（如"我"自动映射为"坤茹"）。',
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
            const Row(
              children: [
                Icon(Icons.smart_toy, color: Colors.indigo),
                SizedBox(width: 8),
                Text('AI 与大模型接口设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('支持离线免费规则引擎，或接入 DeepSeek / Gemini / OpenAI 智能多模态服务。', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 20),

            DropdownButtonFormField<String>(
              value: settings.aiProvider,
              decoration: const InputDecoration(
                labelText: 'AI 引擎模式',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'offline_rules', child: Text('本地智能规则引擎 (完全免费离线)')),
                DropdownMenuItem(value: 'deepseek', child: Text('DeepSeek API (深度求索)')),
                DropdownMenuItem(value: 'gemini', child: Text('Google Gemini API')),
                DropdownMenuItem(value: 'openai', child: Text('OpenAI / 兼容接口 (如通义/硅基流动)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  settings.aiProvider = val;
                  if (val == 'deepseek') {
                    settings.apiEndpoint = 'https://api.deepseek.com/v1/chat/completions';
                    settings.modelName = 'deepseek-chat';
                  } else if (val == 'gemini') {
                    settings.apiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions';
                    settings.modelName = 'gemini-1.5-flash';
                  } else if (val == 'openai') {
                    settings.apiEndpoint = 'https://api.openai.com/v1/chat/completions';
                    settings.modelName = 'gpt-4o-mini';
                  }
                  provider.saveSettings(settings);
                }
              },
            ),

            if (settings.aiProvider != 'offline_rules') ...[
              const SizedBox(height: 12),
              TextFormField(
                initialValue: settings.apiEndpoint,
                decoration: const InputDecoration(labelText: 'API Endpoint (服务地址)', border: OutlineInputBorder(), isDense: true),
                onChanged: (v) {
                  settings.apiEndpoint = v.trim();
                  provider.saveSettings(settings);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: settings.apiKey,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'API Key (密钥)', border: OutlineInputBorder(), isDense: true),
                onChanged: (v) {
                  settings.apiKey = v.trim();
                  provider.saveSettings(settings);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: settings.modelName,
                decoration: const InputDecoration(labelText: '模型名称 (Model Name)', border: OutlineInputBorder(), isDense: true),
                onChanged: (v) {
                  settings.modelName = v.trim();
                  provider.saveSettings(settings);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataBackupSection(BuildContext context, LedgerProvider provider) {
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
                Text('数据备份与迁移', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('支持将全部记账记录、分类及别名导出备份为 JSON 文件，或导入历史账本。', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _exportData(context),
                    icon: const Icon(Icons.file_download),
                    label: const Text('导出完整数据'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _importData(context, provider),
                    icon: const Icon(Icons.file_upload),
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

  Future<void> _exportData(BuildContext context) async {
    try {
      final jsonStr = await DatabaseService.instance.exportToJson();
      final dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
      final file = File('${dir.path}/luhao_ledger_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonStr);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('数据已成功导出至: ${file.path}'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e'), backgroundColor: Colors.red),
      );
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
            const SnackBar(content: Text('数据导入并同步成功！'), backgroundColor: Colors.green),
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
