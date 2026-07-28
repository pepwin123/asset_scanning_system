import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ispace_asset_scanner/services/database_helper.dart';
import 'package:ispace_asset_scanner/models/asset.dart';

class AddAssetScreen extends StatefulWidget {
  final String? scannedId;
  const AddAssetScreen({super.key, this.scannedId});

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _assetIdController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _employeeNameController = TextEditingController();
  final _modelController = TextEditingController();
  final _serialNumberController = TextEditingController();

  bool _isSmartRouted = false;

  // List of common hardware brands to help identify the "Model" field
  final List<String> _knownBrands = [
    'DELL', 'HP', 'LENOVO', 'MACBOOK', 'APPLE', 'ASUS', 'ACER', 'SAMSUNG', 
    'THINKPAD', 'LATITUDE', 'PRECISION', 'MICROSOFT', 'SURFACE', 'LOGITECH'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.scannedId != null) {
      _parseHardwareOnly(widget.scannedId!);
    }
  }

  // Strictly extracts only Asset ID, Model, and Serial Number from the barcode
  void _parseHardwareOnly(String data) {
    String assetId = '';
    String model = '';
    String serial = '';
    
    final String raw = data.trim();
    bool identified = false;

    // 1. Try JSON First
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map) {
        assetId = (decoded['asset_id'] ?? decoded['id'] ?? '').toString().trim();
        model = (decoded['model'] ?? '').toString().trim();
        serial = (decoded['serial_number'] ?? decoded['serial'] ?? '').toString().trim();
        if (assetId.isNotEmpty || model.isNotEmpty || serial.isNotEmpty) identified = true;
      }
    } catch (_) {}

    // 2. Intelligent Multi-Part Detection
    if (!identified) {
      final parts = raw.split(RegExp(r'[;\n|\t,]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      
      for (var part in parts) {
        if (part.contains(':')) {
          final kv = part.split(':');
          final k = kv[0].toLowerCase().trim();
          final v = kv.sublist(1).join(':').trim();
          if (k.contains('asset') || k == 'id') assetId = v;
          else if (k.contains('model') || k == 'mod') model = v;
          else if (k.contains('serial') || k.contains('sn') || k == 's/n') serial = v;
          identified = true;
        } else {
          // Heuristic identification
          final upper = part.toUpperCase();
          if ((upper.startsWith('SN') || upper.startsWith('S/N')) && upper.length > 4) {
            serial = part.replaceFirst(RegExp(r'^(SN|S/N):?'), '').trim();
            identified = true;
          } else if (_knownBrands.any((brand) => upper.contains(brand))) {
            model = part;
            identified = true;
          }
        }
      }

      // 3. Positional fallback (Common in hardware lists: ID, Model, Serial)
      if (!identified || (assetId.isEmpty && parts.isNotEmpty)) {
        if (assetId.isEmpty && parts.isNotEmpty) assetId = parts[0];
        if (model.isEmpty && parts.length > 1) model = parts[1];
        if (serial.isEmpty && parts.length > 2) serial = parts[2];
        identified = parts.length > 1;
      }
    }

    // Final fallback
    if (assetId.isEmpty) assetId = raw;

    _assetIdController.text = assetId;
    _modelController.text = model;
    _serialNumberController.text = serial;
    
    // Employee fields are strictly left blank as they are not expected in the barcode
    _employeeNameController.clear();
    _employeeIdController.clear();
    
    setState(() {
      _isSmartRouted = identified;
    });
  }

  @override
  void dispose() {
    _assetIdController.dispose();
    _employeeIdController.dispose();
    _employeeNameController.dispose();
    _modelController.dispose();
    _serialNumberController.dispose();
    super.dispose();
  }

  Future<void> _saveAsset() async {
    if (_formKey.currentState!.validate()) {
      final asset = Asset(
        assetId: _assetIdController.text.trim(),
        employeeId: _employeeIdController.text.trim(),
        employeeName: _employeeNameController.text.trim(),
        model: _modelController.text.trim(),
        serialNumber: _serialNumberController.text.trim(),
      );

      await DatabaseHelper().insertAsset(asset.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asset Registered Successfully')),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Asset Registration'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (widget.scannedId != null) _buildScanInfoBanner(),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionHeader('HARDWARE DETAILS (FROM SCAN)'),
                    _buildTextField(_assetIdController, 'Asset ID', Icons.tag, true),
                    const SizedBox(height: 16),
                    _buildTextField(_modelController, 'Device Model', Icons.laptop, true),
                    const SizedBox(height: 16),
                    _buildTextField(_serialNumberController, 'Serial Number', Icons.numbers, true),
                    
                    const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider()),
                    
                    _buildSectionHeader('ASSIGNMENT (OPTIONAL)'),
                    _buildTextField(_employeeNameController, 'Employee Name', Icons.person_outline, false),
                    const SizedBox(height: 16),
                    _buildTextField(_employeeIdController, 'Employee ID', Icons.badge_outlined, false),
                    
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _saveAsset,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[900],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: const Text('CONFIRM & SAVE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanInfoBanner() {
    return Container(
      width: double.infinity,
      color: Colors.blue[900],
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.white),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Barcode details recognized and distributed to hardware fields. Remaining fields can be filled manually.',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4),
      child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blue[900], letterSpacing: 1.2)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool required) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue[900], size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: required ? (value) => value!.isEmpty ? 'This field is required' : null : null,
    );
  }
}
