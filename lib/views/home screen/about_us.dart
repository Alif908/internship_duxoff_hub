import 'package:flutter/material.dart';
import 'package:internship_duxoff_hub/views/home%20screen/settings%20page/settings_page.dart';
import 'package:internship_duxoff_hub/views/qkwashome.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF000000)),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => SettingsPage()),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'About us',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4DB6AC),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome to Qk wash where we are revolutionizing the laundry experience using our washing ecosystem. Our goal is to integrate the technology into laundry experience for making it seamless and efficient. We are committed to transform the way you manage your laundry needs by providing our washing ecosystem that includes India\'s first UPI - enabled smart washing machines *, advanced dryers, water processing unit and our revolutionary Qk wash mobile application.\n\n'
                'Our washing ecosystem allows you to easily search for the availability of machines right from your mobile devices, where we provides you the real time running status of our machines. You can simply schedule your wash by few taps. All our machines are UPI enabled which makes your payments seamless.\n\n'
                'Our washing ecosystem allows you to do what you love by making laundry management a hassle free experience. We invite you to join us on this exciting journey towards a smarter laundry experience. Stay connected for more.\n\n'
                'Thank you for choosing us.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xDE000000),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Terms of service and Privacy policy',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4DB6AC),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 24),

              _buildParagraph(
                'QKWash Laundry App Terms and Conditions of Use\n\n'
                'Your Right to Cancel\n\n'
                'At QKWash Ltd, we want you to be fully satisfied every time you top up your account using the QKWash Laundry App. You have the right to cancel your purchase of app credit. However, we regret that we cannot accept cancellations of top-up purchases if any or all of the credit has been used.\n\n'
                'To cancel a credit made through the QKWash Laundry App, please contact QKWash Services Ltd within seven working days of receiving the top-up confirmation via email. To facilitate a quick refund process, please provide the reason for your refund request, along with your top-up purchase receipt. Send these details to:\n\n'
                'QKWash Services Ltd\n'
                'North Paravur, Ernakulam, Kerala\n\n'
                'For app credit refunds, please email: refunds@qkwash.com.\n\n'
                'Please note that any credit added to your account more than 12 months ago will not be eligible for a refund. A 100-rupee administrative charge will be applied to all refunds.\n\n'
                'For your protection, we recommend using a recorded-delivery service when returning any physical items related to your refund request. Please note that you are responsible for any return costs, and QKWash Services Ltd will not be liable for lost items during transit.\n\n'
                'Policy for Unused Credit\n\n'
                'If you wish to receive a refund for partially used credit, please contact us via email at refunds@qkwash.com and provide the following:\n\n'
                '• A screenshot of your QKWash app account\n'
                '• The reason for requesting a refund\n'
                '• A copy of your original receipt or transaction details, including your PayPal receipt with the Transaction or Receipt ID number\n\n'
                'Refunds will not be issued for any free or promotional credit.\n\n'
                'Lost Accounts or App Access\n\n'
                'Your QKWash app account and its associated credit are your sole responsibility. QKWash Ltd will not accept liability for any lost credit if you lose access to your app account. Please ensure that you keep your login details safe, as your app account should be treated like cash. No credit will be restored on lost or deleted app accounts.\n\n'
                'QKWash Ltd reserves the right to charge a nominal fee for account recovery or the restoration of lost app access.\n\n'
                'Refund Policy for Faults\n\n'
                'If you experience any loss of credit due to an error with the QKWash Laundry App or a machine, please email info@qkwash.com with the following details:\n\n'
                '• Your name\n'
                '• App username or account number\n'
                '• Site reference and site name\n'
                '• Machines used\n'
                '• Description of the fault experienced\n'
                '• Amount of credit lost\n\n'
                'Please note that all faults must be reported within 48 hours of the incident.\n\n'
                'Changes to Terms and Conditions\n\n'
                'QKWash Ltd reserves the right to amend these Terms and Conditions of Use without prior notice at any time.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xDE000000),
        height: 1.6,
      ),
    );
  }
}
