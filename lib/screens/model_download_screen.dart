import 'dart:async';
import 'package:flutter/material.dart';
import '../agent/agent_orchestrator.dart';
import '../agent/model_download_service.dart';

class ModelDownloadScreen extends StatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  State<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends State<ModelDownloadScreen> {
  _Phase _phase = _Phase.idle;
  double _progress = 0.0;
  String? _error;
  StreamSubscription<double>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _phase = _Phase.downloading;
      _progress = 0.0;
      _error = null;
    });

    try {
      _sub = ModelDownloadService.downloadModel().listen(
        (progress) {
          if (mounted) setState(() => _progress = progress);
        },
        onDone: () async {
          if (!mounted) return;
          setState(() => _phase = _Phase.initializing);
          await AgentOrchestrator.instance.reinitialize();
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop(true);
          });
        },
        onError: (Object e) {
          if (mounted) {
            setState(() {
              _phase = _Phase.idle;
              _error = e.toString();
            });
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      setState(() {
        _phase = _Phase.idle;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Download AI Model')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Icon(
              Icons.memory,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'One-time model download',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'The Faranga assistant runs entirely on your device using a local '
              'AI model. Your spending data never leaves your phone.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),

            // ── Info cards ──
            _InfoRow(
              icon: Icons.storage,
              label: 'Model size',
              value: ModelDownloadService.kModelSizeLabel,
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.schedule,
              label: 'Estimated time',
              value: ModelDownloadService.kEstimatedTimeLabel,
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.check_circle_outline,
              label: 'Frequency',
              value: 'One time only — stored on this device',
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.lock_outline,
              label: 'Privacy',
              value: 'No data sent to any server during or after download',
            ),

            const Spacer(),

            // ── Progress / error ──
            if (_phase == _Phase.downloading) ...[
              Text(
                '${(_progress * 100).toStringAsFixed(0)}% downloaded',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _progress,
                minHeight: 10,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 16),
            ],

            if (_phase == _Phase.initializing) ...[
              Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading model into memory…',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            if (_error != null) ...[
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Action button ──
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _phase == _Phase.idle ? _startDownload : null,
                icon: const Icon(Icons.download),
                label: Text(
                  _phase == _Phase.idle ? 'Download Model' : 'Downloading…',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Phase { idle, downloading, initializing }

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
