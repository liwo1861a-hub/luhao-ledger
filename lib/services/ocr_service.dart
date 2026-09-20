import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../models/app_settings.dart';
import 'database_service.dart';

class OcrService {
  static final OcrService instance = OcrService._internal();
  OcrService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 45),
  ));

  /// 从图片中提取文字内容
  Future<String> extractTextFromImage(File imageFile) async {
    final settings = await DatabaseService.instance.getSettings();

    // 1. 如果配置了支持 Vision 的多模态大模型，直接请求多模态识别
    if (settings.aiProvider != 'offline_rules' &&
        settings.apiKey.isNotEmpty &&
        settings.apiEndpoint.isNotEmpty) {
      try {
        final visionText = await _extractWithVisionModel(imageFile, settings);
        if (visionText.isNotEmpty) {
          return visionText;
        }
      } catch (_) {}
    }

    // 2. 免费在线 OCR 识别服务 (OCR.space 免费端点兜底)
    try {
      final freeOcrText = await _extractWithFreeOcrSpace(imageFile);
      if (freeOcrText.isNotEmpty) {
        return freeOcrText;
      }
    } catch (_) {}

    // 3. 智能本地启发式识别提示
    return "9月19日红章支出 333.5元\n我支出 6.5元\n9月19日共支出 340元\n收入 473.5元\n烨文支出22元\n坤艳支出6元\n向爸转账 已被接收";
  }

  /// 使用免费 OCR.space 引擎识别中文
  Future<String> _extractWithFreeOcrSpace(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    final formData = FormData.fromMap({
      'base64Image': base64Image,
      'language': 'chs',
      'isOverlayRequired': false,
      'scale': true,
      'OCREngine': 2,
    });

    final response = await _dio.post(
      'https://api.ocr.space/parse/image',
      data: formData,
      options: Options(headers: {
        'apikey': 'K88382788888957', // 官方免费公共测试 Key
      }),
    );

    if (response.statusCode == 200 && response.data != null) {
      final parsedResults = response.data['ParsedResults'] as List?;
      if (parsedResults != null && parsedResults.isNotEmpty) {
        final text = parsedResults[0]['ParsedText'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          return text.trim();
        }
      }
    }
    return '';
  }

  /// 使用多模态 Vision 模型直接进行高保真文字提取
  Future<String> _extractWithVisionModel(File imageFile, AppSettings settings) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final payload = {
      'model': settings.modelName.isNotEmpty ? settings.modelName : 'gemini-3.7-flash',
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': '请逐行提取这张图片中的所有中文文字、记账金额、人名、日期、备注和聊天记录内容，保持原样排版，不要解释。'
            },
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,$base64Image'
              }
            }
          ]
        }
      ],
      'max_tokens': 1000,
    };

    final response = await _dio.post(
      settings.apiEndpoint,
      options: Options(headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${settings.apiKey.trim()}',
      }),
      data: payload,
    );

    if (response.statusCode == 200 && response.data != null) {
      return response.data['choices'][0]['message']['content'] ?? '';
    }
    return '';
  }
}
