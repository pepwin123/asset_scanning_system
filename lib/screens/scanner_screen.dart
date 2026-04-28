import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/database_helper.dart';
import 'history_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController();
  bool isScanning = true;
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
  }

  void _onDetect(BarcodeCapture capture) async {
    if (!isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        setState(() {
          isScanning = false;
        });
        
        final assetData = await DatabaseHelper().getAssetDetails(code);
        
        String resultType = 'unknown';
        if (assetData != null) {
          resultType = assetData['is_company'] == 1 ? 'company' : 'not_company';
        }

        await DatabaseHelper().logScan(code, resultType, 'Security_Desk_1');
        _showResult(assetData, code);
      }
    }
  }

  void _showResult(Map<String, dynamic>? asset, String scannedCode) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final bool isVerified = asset != null && asset['is_company'] == 1;

        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVerified ? Icons.check_circle : Icons.error,
                color: isVerified ? Colors.green : Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                isVerified ? 'Company Property' : 'Unknown Asset',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isVerified ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text('Scanned Code: $scannedCode'),
              if (isVerified) ...[
                const Divider(height: 32),
                _infoRow('Item Type', asset['asset_type'] ?? 'N/A'),
                _infoRow('Employee', asset['emp_name'] ?? 'Unassigned'),
                _infoRow('Dept', asset['department'] ?? 'N/A'),
                _infoRow('Status', asset['status'] ?? 'N/A'),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      isScanning = true;
                    });
                  },
                  child: const Text('Scan Again'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),
          _buildViewfinderOverlay(context),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 40, bottom: 10),
              decoration: const BoxDecoration(
                color: Colors.blue,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(right: 48.0), // Fixed: used EdgeInsets.only
                        child: Text(
                          'QR & Barcode Scanner',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 130,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.flash_on, color: Colors.blue, size: 30),
                    onPressed: () => controller.toggleTorch(),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.flip_camera_ios, color: Colors.blue, size: 30),
                    onPressed: () => controller.switchCamera(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _onDetect(BarcodeCapture(
            barcodes: [
              Barcode(
                rawValue: 'LAP123',
                format: BarcodeFormat.qrCode,
              )
            ],
          ));
        },
        backgroundColor: Colors.blue,
        tooltip: 'Simulate Scan',
        child: const Icon(Icons.bug_report, color: Colors.white),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        onTap: (index) {
          if (index == 1) { // History Tab
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HistoryScreen()),
            ).then((_) {
               setState(() => _selectedIndex = 0);
            });
          } else {
            setState(() {
              _selectedIndex = index;
            });
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Scanner'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }

  Widget _buildViewfinderOverlay(BuildContext context) {
    double scanArea = 250.0;
    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        height: scanArea,
        width: scanArea,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return CustomPaint(
              painter: ScannerOverlayPainter(scanLinePosition: _animation.value),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final double scanLinePosition;

  ScannerOverlayPainter({required this.scanLinePosition});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    double cornerSize = 40.0;
    double radius = 30.0;

    path.moveTo(0, cornerSize);
    path.lineTo(0, radius);
    path.arcToPoint(Offset(radius, 0), radius: Radius.circular(radius));
    path.lineTo(cornerSize, 0);

    path.moveTo(size.width - cornerSize, 0);
    path.lineTo(size.width - radius, 0);
    path.arcToPoint(Offset(size.width, radius), radius: Radius.circular(radius));
    path.lineTo(size.width, cornerSize);

    path.moveTo(size.width, size.height - cornerSize);
    path.lineTo(size.width, size.height - radius);
    path.arcToPoint(Offset(size.width - radius, size.height), radius: Radius.circular(radius));
    path.lineTo(size.width - cornerSize, size.height);

    path.moveTo(cornerSize, size.height);
    path.lineTo(radius, size.height);
    path.arcToPoint(Offset(0, size.height - radius), radius: Radius.circular(radius));
    path.lineTo(0, size.height - cornerSize);

    canvas.drawPath(path, paint);

    final linePaint = Paint()
      ..color = Colors.blue.withOpacity(0.8)
      ..strokeWidth = 3;

    double y = size.height * scanLinePosition;
    canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), linePaint);
    
    final shadowPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..strokeWidth = 12;
    canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), shadowPaint);
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) => 
      oldDelegate.scanLinePosition != scanLinePosition;
}
