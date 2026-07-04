import 'dart:io';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

/// Handles checking and downloading the Gemma 2B-IT model.
///
/// The model is downloaded once and stored internally by flutter_gemma at
/// `<app-documents>/model.bin`. Subsequent launches skip the download.
///
class ModelDownloadService {
  ModelDownloadService._();
  static const String kModelUrl =
      'https://github.com/osobotu/faranga/releases/download/v1.0.0-model/gemma-2b-it-cpu-int4.bin';

  static const int kModelSizeBytes = 1_350_560_050; // 1_160_000_000;
  static const String kModelSizeLabel = '~1.3 GB';
  static const String kEstimatedTimeLabel =
      '20-30 minutes on a 10 Mbps connection';

  static Future<bool> isModelDownloaded() async {
    return await FlutterGemmaPlugin.instance.isLoaded;
  }

  /// Returns true only when the on-disk file is at least 99% of the expected
  /// size. A smaller file means the previous download was interrupted.
  static Future<bool> isModelComplete() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/model.bin');
    if (!await file.exists()) return false;
    return await file.length() >= kModelSizeBytes * 0.99;
  }

  static Future<void> deleteModel() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/model.bin');
    if (await file.exists()) await file.delete();
  }

  static Stream<double> downloadModel() {
    if (kModelUrl.contains('YOUR_CDN_HOST')) {
      throw StateError(
        'Model URL is not configured. '
        'Set ModelDownloadService.kModelUrl to a valid Gemma 2B-IT download URL.',
      );
    }

    return FlutterGemmaPlugin.instance
        .loadNetworkModelWithProgress(url: kModelUrl)
        .map((percentage) => (percentage / 100.0).clamp(0.0, 1.0));
  }
}
