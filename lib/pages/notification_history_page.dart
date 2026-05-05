import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class NotificationHistoryPage extends StatefulWidget {
  const NotificationHistoryPage({super.key});

  @override
  State<NotificationHistoryPage> createState() => _NotificationHistoryPageState();
}

class _NotificationHistoryPageState extends State<NotificationHistoryPage> {
  late Future<List<NotificationHistoryItem>> _historyFuture;

  @override
  void initState() {
    super.initState();
    NotificationService().markAllAsRead();
    _historyFuture = NotificationService().getHistory();
  }

  Future<void> _reload() async {
    setState(() {
      _historyFuture = NotificationService().getHistory();
    });
  }

  Future<void> _clearAll() async {
    await NotificationService().clearHistory();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Riwayat Notifikasi'),
        actions: [
          TextButton.icon(
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
            label: const Text(
              'Clear All',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<NotificationHistoryItem>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final history = snapshot.data ?? const <NotificationHistoryItem>[];

          if (history.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _buildHistoryCard(history[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: AppTheme.textGray,
            ),
            SizedBox(height: 12),
            Text(
              'Belum ada riwayat notifikasi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textGray,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(NotificationHistoryItem item) {
    final isDanger = item.type == NotificationHistoryType.danger;
    final color = isDanger ? AppTheme.statusDanger : AppTheme.statusWarning;
    final label = isDanger ? 'Bahaya' : 'Peringatan';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isDanger
                    ? Icons.warning_amber_rounded
                    : Icons.notifications_active_rounded,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTimestamp(item.timestamp),
                        style: const TextStyle(
                          color: AppTheme.textGray,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.message,
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final day = timestamp.day.toString().padLeft(2, '0');
    final month = timestamp.month.toString().padLeft(2, '0');
    final year = timestamp.year.toString();
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }
}
