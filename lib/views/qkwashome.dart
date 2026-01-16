import 'package:flutter/material.dart';
import 'package:internship_duxoff_hub/views/home%20screen/homepage.dart';
import 'package:internship_duxoff_hub/views/home%20screen/qrscanning/qrscaning_page.dart';
import 'package:internship_duxoff_hub/views/home%20screen/running_page.dart';
import 'package:internship_duxoff_hub/views/home%20screen/settings%20page/settings_page.dart';
import 'package:internship_duxoff_hub/views/home%20screen/settings%20page/wash_history.dart';

class QKWashHome extends StatefulWidget {
  final int initialTabIndex; // ✅ NEW: Accept initial tab index

  const QKWashHome({super.key, this.initialTabIndex = 0});

  @override
  State<QKWashHome> createState() => _QKWashHomeState();
}

class _QKWashHomeState extends State<QKWashHome> {
  late int _selectedScreen; // ✅ Changed to late for initialization

  // Define screens list
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _selectedScreen =
        widget.initialTabIndex; // ✅ Initialize from widget parameter
    _screens = [
      const HomePage(),
      const WashHistoryPage(),
      const RunningJobsPage(),
      const SettingsPage(),
    ];
  }

  /// Handle bottom navigation tap
  void _onNavItemTapped(int index) {
    if (_selectedScreen != index) {
      setState(() {
        _selectedScreen = index;
      });
    }
  }

  /// Navigate to QR Scanner
  void _navigateToQRScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerPage()),
    ).then((_) {
      // Refresh current screen if needed after QR scan
      if (_selectedScreen == 0 || _selectedScreen == 2) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedScreen, children: _screens),

      // Floating Action Button for QR Scanner
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        elevation: 4,
        shape: const CircleBorder(),
        onPressed: _navigateToQRScanner,
        child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 32),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Bottom Navigation Bar
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'Home',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.access_time,
                selectedIcon: Icons.access_time,
                label: 'History',
                index: 1,
              ),
              const SizedBox(width: 40), // Space for FAB
              _buildNavItem(
                icon: Icons.directions_run,
                selectedIcon: Icons.directions_run,
                label: 'Running',
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                label: 'Settings',
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build individual navigation item
  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedScreen == index;

    return Expanded(
      child: InkWell(
        onTap: () => _onNavItemTapped(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              size: 28,
              color: isSelected ? Colors.blue : Colors.grey[600],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.blue : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
