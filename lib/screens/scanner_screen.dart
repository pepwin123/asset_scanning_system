import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ispace_asset_scanner/services/database_helper.dart';
import 'package:ispace_asset_scanner/screens/add_asset_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  late MobileScannerController controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      formats: [BarcodeFormat.all],
      autoStart: true,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!controller.value.isInitialized) return;
    switch (state) {
      case AppLifecycleState.resumed:
        controller.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        controller.stop();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  // Strictly parses for ID, Model, and Serial Number
  Map<String, String> _parseHardwareOnly(String data) {
    Map<String, String> result = {'id': '', 'model': '', 'serial': ''};
    final String raw = data.trim();
    bool identified = false;

    // 1. Try JSON
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        result['id'] = (decoded['asset_id'] ?? decoded['id'] ?? '').toString().trim();
        result['model'] = (decoded['model'] ?? '').toString().trim();
        result['serial'] = (decoded['serial_number'] ?? decoded['serial'] ?? '').toString().trim();
        if (result['id']!.isNotEmpty) identified = true;
      }
    } catch (_) {}

    // 2. Intelligent Delimiter Split (Pipe, Semicolon, Newline, Tab, Comma)
    if (!identified) {
      final parts = raw.split(RegExp(r'[;\n|\t,]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      
      for (var part in parts) {
        if (part.contains(':')) {
          final kv = part.split(':');
          final k = kv[0].toLowerCase().trim();
          final v = kv.sublist(1).join(':').trim();
          if (k.contains('asset') || k == 'id') result['id'] = v;
          else if (k.contains('model') || k == 'mod') result['model'] = v;
          else if (k.contains('serial') || k == 'sn' || k == 's/n') result['serial'] = v;
        }
      }

      // Positional fallback: ID, Model, Serial
      if (result['id']!.isEmpty && parts.isNotEmpty) {
        result['id'] = parts[0];
        if (result['model']!.isEmpty && parts.length > 1) result['model'] = parts[1];
        if (result['serial']!.isEmpty && parts.length > 2) result['serial'] = parts[2];
      }
    }

    if (result['id']!.isEmpty) result['id'] = raw;
    return result;
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? rawCode = barcodes.first.rawValue ?? barcodes.first.displayValue;
      if (rawCode != null && rawCode.isNotEmpty) {
        HapticFeedback.lightImpact();
        setState(() => _isProcessing = true);
        await controller.stop();
        if (!mounted) return;
        _processScan(rawCode);
      }
    }
  }

  Future<void> _processScan(String rawData) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    final hardware = _parseHardwareOnly(rawData);
    final String searchId = hardware['id']!.isNotEmpty ? hardware['id']! : hardware['serial']!;

    try {
      final assetData = await DatabaseHelper().getAssetDetails(searchId);
      if (!mounted) return;
      Navigator.pop(context); 
      _showResultSheet(assetData, rawData, hardware);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _resumeScanning();
    }
  }

  void _resumeScanning() {
    if (mounted) {
      setState(() => _isProcessing = false);
      controller.start();
    }
  }

  void _showResultSheet(Map<String, dynamic>? asset, String rawData, Map<String, String> hardware) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool isFound = asset != null;
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.withAlpha(50), borderRadius: BorderRadius.circular(2))),
              Icon(isFound ? Icons.verified_user : Icons.new_label_outlined, color: isFound ? Colors.green : Colors.blue, size: 80),
              const SizedBox(height: 16),
              Text(isFound ? 'OFFICE PROPERTY' : 'NEW HARDWARE DETECTED', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isFound ? Colors.green : Colors.blue)),
              const Divider(height: 40),
              
              if (isFound) ...[
                _infoRow('Asset ID', asset['asset_id']),
                _infoRow('Model', asset['model']),
                _infoRow('Serial No', asset['serial_number']),
                _infoRow('Assigned to', asset['employee_name']),
              ] else ...[
                _infoRow('ID', hardware['id']),
                if (hardware['model']!.isNotEmpty) _infoRow('Model', hardware['model']),
                if (hardware['serial']!.isNotEmpty) _infoRow('Serial', hardware['serial']),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('This item is not in the registry. Tap below to map these fields to a new registration.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13))),
              ],

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  if (isFound) {
                    _resumeScanning();
                  } else {
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => AddAssetScreen(scannedId: rawData)));
                    _resumeScanning();
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: isFound ? Colors.blue[900] : Colors.green[700], foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(isFound ? 'SCAN NEXT' : 'MAP & REGISTER'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
      Flexible(child: Text(value?.toString() ?? 'N/A', textAlign: TextAlign.right)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('iSpace Asset Scanner'), backgroundColor: Colors.blue[900], foregroundColor: Colors.white),
      body: Stack(children: [
        MobileScanner(controller: controller, onDetect: _onDetect, fit: BoxFit.cover),
        Center(child: Container(width: 250, height: 250, decoration: BoxDecoration(border: Border.all(color: Colors.blue.withAlpha(150), width: 2), borderRadius: BorderRadius.circular(20)))),
      ]),
    );
  }
}
