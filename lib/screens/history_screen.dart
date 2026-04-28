import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await DatabaseHelper().getScanLogs();
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History & Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => _confirmClearLogs(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadLogs,
                  child: ListView.separated(
                    itemCount: _logs.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final bool isCompany = log['result'] == 'company';
                      final DateTime scanTime = DateTime.parse(log['scan_time']);
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCompany ? Colors.green.shade100 : Colors.red.shade100,
                          child: Icon(
                            isCompany ? Icons.check : Icons.close,
                            color: isCompany ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(
                          log['asset_id'] ?? 'Unknown Code',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${log['asset_type'] ?? 'Unknown'} • ${log['emp_name'] ?? 'No Name'}'),
                            Text(
                              DateFormat('MMM d, yyyy - hh:mm a').format(scanTime),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCompany ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isCompany ? 'Verified' : 'Unknown',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No scan history found', style: TextStyle(color: Colors.grey, fontSize: 18)),
        ],
      ),
    );
  }

  void _confirmClearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History?'),
        content: const Text('This will delete all scan logs permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              await DatabaseHelper().clearLogs();
              Navigator.pop(context);
              _loadLogs();
            },
            child: const Text('CLEAR ALL', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
