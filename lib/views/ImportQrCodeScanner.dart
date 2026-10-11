import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mensapp_v2/utils/cardutils.dart';

class ImportBarcodeScanner extends StatefulWidget {
  const ImportBarcodeScanner({super.key});

  @override
  State<ImportBarcodeScanner> createState() => _ImportBarcodeScannerState();
}

class _ImportBarcodeScannerState extends State<ImportBarcodeScanner> {
  Barcode? _barcode;
  final MobileScannerController _controller = MobileScannerController();

  Widget _buildBarcode(Barcode? value) {
    return const Text(
      "Scan your Mensapp QR code",
      style: TextStyle(color: Colors.white),
    );
  }

  Future<void> parseNewData(
    String qrContent,
    MobileScannerController controller,
  ) async {
    try {
      final userData = UserData.fromJson(jsonDecode(qrContent));
      await ProfileManager.addProfile(userData);

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, "/home", (route) => false);
      }
    } catch (e) {
      throw Exception("Invalid profile data");
    }
  }

  void _handleBarcode(BarcodeCapture barcodes) {
    var barcode = barcodes.barcodes.firstOrNull;

    if (barcode == null) {
      return;
    }

    var content = barcodes.barcodes.firstOrNull?.displayValue;

    if (content == null) {
      return;
    }

    parseNewData(content, _controller).onError((E, stackTrace) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $E"),
          duration: const Duration(seconds: 5),
        ),
      );
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simple scanner')),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(onDetect: _handleBarcode, controller: _controller),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              alignment: Alignment.bottomCenter,
              height: 100,
              color: const Color.fromRGBO(0, 0, 0, 0.4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: Center(child: _buildBarcode(_barcode))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
