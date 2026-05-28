import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/transaction.dart';
import 'screens/analytics_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/analytics_service.dart';
import 'services/database_service.dart';
import 'services/sync_manager.dart';

void main() => runApp(const MomoFinanceApp());

class MomoFinanceApp extends StatelessWidget {
  const MomoFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Faranga',
      theme: ThemeData(
        colorSchemeSeed: Colors.amber,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.amber,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const AppEntry(),
    );
  }
}

/// Decides whether to show onboarding or the main screen.
class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool? _onboardingComplete;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingComplete == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_onboardingComplete!) {
      return OnboardingScreen(
        onComplete: () => setState(() => _onboardingComplete = true),
      );
    }

    return const HomeScreen();
  }
}

// ── Main home screen ─────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MomoTransaction> _transactions = [];
  Map<String, int> _summary = {'today': 0, 'week': 0, 'month': 0};
  bool _loading = false;
  String? _syncMessage;

  final _currencyFormat = NumberFormat('#,###', 'en');

  @override
  void initState() {
    super.initState();

    // Listen for background sync results
    SyncManager.onSyncComplete = (result) {
      if (mounted && result.newTransactions > 0) {
        _loadData();
        setState(() => _syncMessage = result.message);
      }
    };

    // Start periodic sync (every 15 minutes)
    SyncManager.start(interval: const Duration(minutes: 15));

    _loadData();
  }

  @override
  void dispose() {
    SyncManager.onSyncComplete = null;
    SyncManager.stop();
    super.dispose();
  }

  Future<void> _loadData() async {
    final transactions = await DatabaseService.getAll();
    final analyticsSummary = await AnalyticsService.getSpendingSummary();

    if (mounted) {
      setState(() {
        _transactions = transactions;
        _summary = {
          'today': analyticsSummary.today,
          'week': analyticsSummary.thisWeek,
          'month': analyticsSummary.thisMonth,
        };
      });
    }
  }

  Future<void> _manualSync() async {
    setState(() {
      _loading = true;
      _syncMessage = null;
    });
    final result = await SyncManager.sync();
    await _loadData();
    if (mounted) {
      setState(() {
        _loading = false;
        _syncMessage = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faranga'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _manualSync,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Sync SMS',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Summary cards ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _SummaryCard(
                  label: 'Today',
                  amount: _summary['today']!,
                  format: _currencyFormat,
                ),
                const SizedBox(width: 8),
                _SummaryCard(
                  label: 'This week',
                  amount: _summary['week']!,
                  format: _currencyFormat,
                ),
                const SizedBox(width: 8),
                _SummaryCard(
                  label: 'This month',
                  amount: _summary['month']!,
                  format: _currencyFormat,
                ),
              ],
            ),
          ),

          // ── Sync status ──
          if (_syncMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_syncMessage!, style: theme.textTheme.bodySmall),
            ),

          const Divider(),

          // ── Transaction list ──
          Expanded(
            child: _transactions.isEmpty
                ? Center(
                    child: Text(
                      'No transactions yet.\nTap sync or wait for auto-sync.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) => _TransactionTile(
                      tx: _transactions[index],
                      format: _currencyFormat,
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
        ),
        child: const Icon(Icons.analytics),
      ),
    );
  }
}

// ── Reusable widgets ─────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final int amount;
  final NumberFormat format;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  '${format.format(amount)} RWF',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final MomoTransaction tx;
  final NumberFormat format;

  const _TransactionTile({required this.tx, required this.format});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('MMM d, HH:mm').format(tx.timestamp);
    final icon = tx.type == TransactionType.payment
        ? Icons.store
        : tx.type == TransactionType.received
        ? Icons.arrow_downward
        : Icons.arrow_upward;
    final iconColor = tx.type == TransactionType.received
        ? Colors.green
        : theme.colorScheme.error;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withValues(alpha: 0.1),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(tx.recipient, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '$dateStr${tx.category != null ? ' · ${tx.category}' : ''}',
      ),
      trailing: Text(
        '${tx.type == TransactionType.received ? '+' : '-'}${format.format(tx.amount)} RWF',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: tx.type == TransactionType.received ? Colors.green : null,
        ),
      ),
    );
  }
}
