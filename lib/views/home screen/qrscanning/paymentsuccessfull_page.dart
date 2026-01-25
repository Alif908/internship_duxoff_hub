import 'package:flutter/material.dart';
import 'package:internship_duxoff_hub/views/home%20screen/qrscanning/washstartpage.dart';

class PaymentSuccessPage extends StatelessWidget {
  final double amount;
  final String machineId;
  final String hubName;
  final String washTime;

  const PaymentSuccessPage({
    super.key,
    required this.amount,
    required this.machineId,
    required this.hubName,
    required this.washTime,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),

            Image.asset(
              'assets/images/paymentsuccessfull.png',
              height: 280,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 24),

            Image.asset(
              'assets/images/tick-circle.png',
              width: 60,
              height: 60,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 16),

            const Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Total Payment',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),

            const SizedBox(height: 4),

            Text(
              '₹ ${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

            const Spacer(flex: 2),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WashStartPage(
                          machineId: machineId,
                          hubName: hubName,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'CONTINUE TO WASH',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
