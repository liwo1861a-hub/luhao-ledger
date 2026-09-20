import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final String latestVersion;
  final int latestBuildNumber;
  final String releaseName;
  final String releaseDate;
  final String changelog;
  final String apkDownloadUrl;
  final bool hasUpdate;

  UpdateInfo({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.releaseName,
    required this.releaseDate,
    required this.changelog,
    required this.apkDownloadUrl,
    required this.hasUpdate,
  });
}

class UpdateService {
  static final UpdateService instance = UpdateService._internal();
  UpdateService._internal();

  final Dio _dio = Dio();
  final String _repoOwner = 'liwo1861a-hub';
  final String _repoName = 'luhao-ledger';

  /// 读取本地 assets/version.json
  Future<Map<String, dynamic>> getLocalVersion() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/version.json');
      return jsonDecode(jsonStr);
    } catch (_) {
      return {'version': '1.0.0', 'build_number': 1};
    }
  }

  /// 检查 GitHub Releases 是否有新版本
  Future<UpdateInfo> checkForUpdate() async {
    final localMeta = await getLocalVersion();
    final currentVersion = localMeta['version'] as String? ?? '1.0.0';
    final currentBuild = localMeta['build_number'] as int? ?? 1;

    try {
      final response = await _dio.get(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
        options: Options(headers: {'Accept': 'application/vnd.github.v3+json'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        String tagName = data['tag_name'] ?? 'v1.0.0';
        String remoteVersion = tagName.replaceFirst('v', '').trim();
        String releaseName = data['name'] ?? '最新发布版本';
        String changelog = data['body'] ?? '常规性能优化与功能更新';
        String publishedAt = data['published_at'] ?? '';
        String downloadUrl = '';

        // 查找 apk 资产
        final assets = data['assets'] as List?;
        if (assets != null) {
          for (var asset in assets) {
            final name = asset['name'] as String? ?? '';
            if (name.endsWith('.apk')) {
              downloadUrl = asset['browser_download_url'] ?? '';
              break;
            }
          }
        }

        if (downloadUrl.isEmpty) {
          downloadUrl = 'https://github.com/$_repoOwner/$_repoName/releases/latest';
        }

        bool hasUpdate = _isNewerVersion(remoteVersion, currentVersion);

        return UpdateInfo(
          latestVersion: remoteVersion,
          latestBuildNumber: currentBuild + 1,
          releaseName: releaseName,
          releaseDate: publishedAt.length >= 10 ? publishedAt.substring(0, 10) : publishedAt,
          changelog: changelog,
          apkDownloadUrl: downloadUrl,
          hasUpdate: hasUpdate,
        );
      }
    } catch (_) {}

    return UpdateInfo(
      latestVersion: currentVersion,
      latestBuildNumber: currentBuild,
      releaseName: '当前已是最新版',
      releaseDate: '',
      changelog: '暂无更新',
      apkDownloadUrl: '',
      hasUpdate: false,
    );
  }

  bool _isNewerVersion(String remote, String current) {
    List<int> rParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (rParts.length < 3) rParts.add(0);
    while (cParts.length < 3) cParts.add(0);

    for (int i = 0; i < 3; i++) {
      if (rParts[i] > cParts[i]) return true;
      if (rParts[i] < cParts[i]) return false;
    }
    return false;
  }

  /// 下载并安装 APK
  Future<void> downloadAndInstallApk(
    String url, {
    required Function(double progress) onProgress,
    required Function(String error) onError,
  }) async {
    try {
      if (!url.endsWith('.apk')) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      final dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
      final savePath = '${dir.path}/luhao-ledger-update.apk';

      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      final file = File(savePath);
      if (await file.exists()) {
        final result = await OpenFilex.open(savePath);
        if (result.type != ResultType.done) {
          onError('打开安装包失败: ${result.message}');
        }
      } else {
        onError('安装包文件未找到');
      }
    } catch (e) {
      onError('下载或安装失败: $e');
    }
  }
}
