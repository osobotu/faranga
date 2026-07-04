import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// Appends each chat session to a plain-text file the user can export.
///
/// File location: `<app-documents>/faranga_chat_history.txt`
///
/// Privacy: this file stays on-device. It is never read by the agent
/// itself — it is purely for the user's own record-keeping.
class ChatPersistenceService {
  static const _fileName = 'faranga_chat_history.txt';

  static final _timeFmt = DateFormat('HH:mm:ss');
  static final _sessionFmt = DateFormat('EEE, MMM d, yyyy \'at\' HH:mm');

  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<void> startSession() async {
    final file = await _getFile();
    final header = '\n=== Chat Session — ${_sessionFmt.format(DateTime.now())} ===\n\n';
    await file.writeAsString(header, mode: FileMode.append, flush: true);
  }

  static Future<void> appendMessage({
    required String role,
    required String content,
    String? toolUsed,
  }) async {
    final file = await _getFile();
    final time = _timeFmt.format(DateTime.now());
    final label = role == 'user' ? 'You' : 'Faranga';
    final toolTag = toolUsed != null ? '\n[Tool used: $toolUsed]' : '';
    final line = '[$time] $label: $content$toolTag\n\n';
    await file.writeAsString(line, mode: FileMode.append, flush: true);
  }

  static Future<void> endSession() async {
    final file = await _getFile();
    await file.writeAsString(
      '=== End of Session ===\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  static Future<String> getFilePath() async {
    final file = await _getFile();
    return file.path;
  }
}
