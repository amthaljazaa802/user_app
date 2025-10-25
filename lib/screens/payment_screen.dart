import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // كل هذا المنطق يبقى كما هو بدون أي تغيير
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    setState(() => _isProcessing = true);
    final qrData = barcodes.first.rawValue ?? 'بيانات غير معروفة';

    _scannerController.stop();
    _showConfirmationDialog(qrData);
  }

  void _showConfirmationDialog(String qrData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        const busId = 'BUS-07';
        const lineName = 'خط الجامعة';
        const amount = '500 ل.س';

        return AlertDialog(
          title: const Text('تأكيد الدفع'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('معلومات الحافلة: $busId'),
              Text('الخط: $lineName'),
              const SizedBox(height: 16),
              Text(
                'المبلغ: $amount',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '(بيانات QR: $qrData)',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () {
                Navigator.pop(context);
                _resetScanner();
              },
            ),
            ElevatedButton(
              child: const Text('تأكيد الدفع'),
              onPressed: () {
                Navigator.pop(context);
                _showSuccessAndExit();
              },
            ),
          ],
        );
      },
    );
  }

  void _showSuccessAndExit() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم الدفع بنجاح! (محاكاة)'),
        backgroundColor: Colors.green,
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

  void _resetScanner() {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    _scannerController.start();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  // --- بداية التعديل الرئيسي على دالة build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- 1. السماح للكاميرا بالامتداد خلف الـ AppBar ---
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('ادفع تذكرتك'),
        // --- 2. جعل الـ AppBar شفافًا وبدون ظل ---
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // عرض الكاميرا يملأ الشاشة بالكامل
          MobileScanner(controller: _scannerController, onDetect: _onDetect),

          // العناصر التوجيهية فوق الكاميرا (تبقى كما هي)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'وجّه الكاميرا نحو رمز QR داخل الحافلة',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
