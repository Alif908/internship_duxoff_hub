import 'package:flutter/material.dart';
import 'package:internship_duxoff_hub/services/home_api_service.dart';
import 'package:internship_duxoff_hub/views/home%20screen/qrscanning/payment_detail_page.dart';
import 'package:intl/intl.dart';

class MachineListPage extends StatefulWidget {
  final String hubId;
  final String hubName;
  final List<dynamic> devices;

  const MachineListPage({
    super.key,
    required this.hubId,
    required this.hubName,
    required this.devices,
  });

  @override
  State<MachineListPage> createState() => _MachineListPageState();
}

class _MachineListPageState extends State<MachineListPage> {
  String selectedWashMode = '';
  int washTimeMinutes = 0;
  bool detergentPreferenceEnabled = true;

  // Real-time device status tracking
  List<dynamic> _devices = [];
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _devices = List.from(widget.devices);
    _refreshDeviceStatuses();
  }

  Future<void> _refreshDeviceStatuses() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      debugPrint('🔄 Refreshing device statuses for hub ${widget.hubId}...');

      final runningJobs = await HomeApi.getRunningJobs(forceRefresh: true);
      final now = DateTime.now();

      debugPrint('📋 Found ${runningJobs.length} running jobs');

      for (var device in _devices) {
        final deviceId = device['deviceid']?.toString() ?? '';

        final oldStatus = device['devicestatus']?.toString() ?? '0';

        final runningJob = runningJobs.firstWhere(
          (job) => job['deviceid']?.toString() == deviceId,
          orElse: () => null,
        );

        if (runningJob != null) {
          final newStatus = runningJob['devicestatus']?.toString() ?? '0';
          final newEndTime = runningJob['device_booked_user_end_time'];

          // ✅ CHECK 1: If status is 100, mark as available
          if (newStatus == "100") {
            debugPrint(
              '✅ Device $deviceId completed (status=100), marking as available',
            );
            device['devicestatus'] = 'Ready';
            device['device_booked_user_end_time'] = null;
            continue;
          }

          // ✅ CHECK 2: If end time has passed, mark as available
          if (newEndTime != null && newEndTime.toString().isNotEmpty) {
            try {
              final endTime = DateTime.parse(newEndTime.toString()).toLocal();
              if (now.isAfter(endTime)) {
                debugPrint(
                  '✅ Device $deviceId end time passed (${DateFormat('HH:mm').format(endTime)}), marking as available',
                );
                device['devicestatus'] = 'Ready';
                device['device_booked_user_end_time'] = null;
                continue;
              }
            } catch (e) {
              debugPrint('⚠️ Error parsing end time for device $deviceId: $e');
            }
          }

          // ✅ Still running - update status and end time
          device['devicestatus'] = newStatus;
          device['device_booked_user_end_time'] = newEndTime;
          debugPrint(
            '⏳ Device $deviceId still running (status=$newStatus)',
          );
        } else {
          // No running job found for this device
          if (oldStatus != '0' && oldStatus != 'ready') {
            device['devicestatus'] = 'Ready';
            device['device_booked_user_end_time'] = null;
            debugPrint(
              '✅ Device $deviceId job completed/not found, marked as available',
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }

      debugPrint('✅ Device status refresh completed');
    } catch (e) {
      debugPrint('❌ Error refreshing device statuses: $e');
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  String _formatEndTime(String? endTimeStr) {
    if (endTimeStr == null || endTimeStr.isEmpty) return '10:15 pm';

    try {
      final DateTime endTime = DateTime.parse(endTimeStr).toLocal();
      return DateFormat('h:mm a').format(endTime).toLowerCase();
    } catch (e) {
      debugPrint('⚠️ Error formatting end time: $e');
      return '10:15 pm';
    }
  }

  String _calculateEndTime(int minutes) {
    final now = DateTime.now();
    final endTime = now.add(Duration(minutes: minutes));
    return DateFormat('h:mm a').format(endTime).toLowerCase();
  }

  /// Calculate offer price based on wash mode and device data
  double _calculateTotalPrice(Map<String, dynamic> device) {
    if (selectedWashMode.isEmpty) return 0.0;

    final deviceType = (device['devicetype'] ?? '').toString().toLowerCase();

    double offerPrice = 0.0;

    if (selectedWashMode == 'Quick Wash') {
      offerPrice = _getPriceFromDevice(device, 'offer_quick_amount') ??
          _getPriceFromDevice(device, 'offerQuickAmount') ??
          _getPriceFromDevice(device, 'quick_wash_price') ??
          1.0;
    } else if (selectedWashMode == 'Normal Wash') {
      if (deviceType.contains('wash')) {
        offerPrice = _getPriceFromDevice(device, 'offer_steam_amount') ??
            _getPriceFromDevice(device, 'offerSteamAmount') ??
            _getPriceFromDevice(device, 'normal_wash_price') ??
            100.0;
      } else {
        offerPrice = _getPriceFromDevice(device, 'offer_normal_amount') ??
            _getPriceFromDevice(device, 'offerNormalAmount') ??
            100.0;
      }
    }

    debugPrint('💰 Price for $selectedWashMode: ₹$offerPrice');
    return offerPrice;
  }

  double? _getPriceFromDevice(Map<String, dynamic> device, String key) {
    final value = device[key];
    if (value == null) return null;

    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 16,
              color: Colors.black,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                widget.hubName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: widget.devices.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No machines available',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshDeviceStatuses,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  return _buildMachineCard(device);
                },
              ),
            ),
    );
  }

  Widget _buildMachineCard(Map<String, dynamic> device) {
    final String deviceType = device['devicetype'] ?? 'Unknown';
    final int deviceId = device['deviceid'] ?? 0;
    final String deviceName =
        '${deviceType.toLowerCase()} ${deviceId.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: deviceType.toLowerCase() == 'dryer'
                  ? const Color(0xFFE3F2FD)
                  : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: deviceType.toLowerCase() == 'dryer'
                    ? const Color(0xFF2196F3).withOpacity(0.2)
                    : const Color(0xFF4CAF50).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Center(
              child: Image.asset(
                'assets/images/machine.png',
                width: 36,
                height: 36,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    deviceType.toLowerCase() == 'dryer'
                        ? Icons.local_fire_department_outlined
                        : Icons.local_laundry_service_outlined,
                    color: deviceType.toLowerCase() == 'dryer'
                        ? const Color(0xFF2196F3)
                        : const Color(0xFF4CAF50),
                    size: 28,
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Machine Name',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  deviceName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          _buildStatusButton(device),
        ],
      ),
    );
  }

  Widget _buildStatusButton(Map<String, dynamic> device) {
    final String deviceStatus =
        (device['devicestatus'] ?? '0').toString().toLowerCase();
    final String deviceCondition =
        (device['devicecondition'] ?? 'Good').toString().toLowerCase();
    final String? endTimeStr = device['device_booked_user_end_time'];

    // ✅ CHECK 1: Under Maintenance if condition is NOT "good"
    if (deviceCondition != 'good') {
      return GestureDetector(
        onTap: () => _showMaintenanceDialog(device),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF9E9E9E),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Under\nMaintenance',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      );
    }

    // ✅ CHECK 2: Available if status is "ready" AND condition is "good"
    if (deviceStatus == 'ready' && deviceCondition == 'good') {
      return ElevatedButton(
        onPressed: () {
          _showWashOptionsModal(device);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2196F3),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          elevation: 0,
        ),
        child: const Text(
          'Available',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );
    }

    // ✅ CHECK 3: If status is numeric (0-100) AND condition is "good"
    final numericStatus = int.tryParse(deviceStatus);
    if (numericStatus != null &&
        numericStatus >= 0 &&
        numericStatus <= 100 &&
        deviceCondition == 'good') {
      // ✅ CHECK 3A: If status is 100 (completed), show as Available
      if (numericStatus == 100) {
        debugPrint(
          '✅ Device ${device['deviceid']} status is 100, showing as Available',
        );
        return ElevatedButton(
          onPressed: () {
            _showWashOptionsModal(device);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            elevation: 0,
          ),
          child: const Text(
            'Available',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        );
      }

      // ✅ CHECK 3B: Status is 0-99, check if end time has passed
      if (endTimeStr != null && endTimeStr.isNotEmpty) {
        try {
          final endTime = DateTime.parse(endTimeStr).toLocal();
          final now = DateTime.now();

          // If end time has passed, show as Available
          if (now.isAfter(endTime)) {
            debugPrint(
              '✅ Device ${device['deviceid']} end time passed, showing as Available',
            );
            return ElevatedButton(
              onPressed: () {
                _showWashOptionsModal(device);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Available',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            );
          }

          // Still running - show "Available at" time
          final String formattedTime = _formatEndTime(endTimeStr);

          return GestureDetector(
            onTap: () => _showAvailabilityDialog(device),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF78909C),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Available at',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedTime,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        } catch (e) {
          debugPrint('⚠️ Error parsing end time: $e');
          // If error parsing time, show as available
          return ElevatedButton(
            onPressed: () {
              _showWashOptionsModal(device);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Available',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          );
        }
      } else {
        // No end time but status is numeric and condition is good
        // Show "Available at" with placeholder time
        return GestureDetector(
          onTap: () => _showAvailabilityDialog(device),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF78909C),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Available at',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '10:15 pm',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // Fallback: Show as available
    return ElevatedButton(
      onPressed: () {
        _showWashOptionsModal(device);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 0,
      ),
      child: const Text(
        'Available',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showWashOptionsModal(Map<String, dynamic> device) {
    final String deviceType = device['devicetype'] ?? 'Washer';
    final int deviceId = device['deviceid'] ?? 0;
    final String deviceName =
        '${deviceType.toLowerCase().substring(0, 1).toUpperCase()}${deviceType.toLowerCase().substring(1)} ${deviceId.toString().padLeft(2, '0')}';
    final String machineId = '#${deviceId.toString()}';

    setState(() {
      selectedWashMode = '';
      washTimeMinutes = 0;
      detergentPreferenceEnabled = true;
    });

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 40,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.grey[600]),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deviceName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Machine ID',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        machineId,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Next Job',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Ready',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF2196F3),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Wash Mode',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildModalOptionButton(
                                  'Quick Wash',
                                  selectedWashMode == 'Quick Wash',
                                  setModalState,
                                  () {
                                    setModalState(() {
                                      selectedWashMode = 'Quick Wash';
                                      washTimeMinutes = 30;
                                    });
                                  },
                                ),
                                const SizedBox(width: 10),
                                _buildModalOptionButton(
                                  'Normal Wash',
                                  selectedWashMode == 'Normal Wash',
                                  setModalState,
                                  () {
                                    setModalState(() {
                                      selectedWashMode = 'Normal Wash';
                                      washTimeMinutes = 40;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (selectedWashMode.isNotEmpty) ...[
                              const Text(
                                'Time & End Time',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xFF2196F3),
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$washTimeMinutes min',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF2196F3),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'End Time: ${_calculateEndTime(washTimeMinutes)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 32),
                            Center(
                              child: ElevatedButton(
                                onPressed: selectedWashMode.isEmpty
                                    ? null
                                    : () {
                                        Navigator.pop(context);

                                        final totalPrice = _calculateTotalPrice(
                                          device,
                                        );

                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PaymentDetailsPage(
                                              hubName: widget.hubName,
                                              hubId: widget.hubId,
                                              deviceId: device['deviceid'] ?? 0,
                                              machineId: machineId,
                                              washMode: selectedWashMode,
                                              washTime: '$washTimeMinutes Min',
                                              totalPrice: totalPrice,
                                            ),
                                          ),
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: selectedWashMode.isEmpty
                                      ? Colors.grey[300]
                                      : const Color(0xFF2196F3),
                                  foregroundColor: selectedWashMode.isEmpty
                                      ? Colors.grey[500]
                                      : Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 48,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                  disabledBackgroundColor: Colors.grey[300],
                                  disabledForegroundColor: Colors.grey[500],
                                ),
                                child: const Text(
                                  'CONTINUE',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalOptionButton(
    String text,
    bool isSelected,
    StateSetter setModalState,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2196F3) : Colors.white,
            border: Border.all(color: const Color(0xFF2196F3), width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF2196F3),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAvailabilityDialog(Map<String, dynamic> device) {
    final String deviceType = device['devicetype'] ?? 'Unknown';
    final int deviceId = device['deviceid'] ?? 0;
    final String? endTime = device['device_booked_user_end_time'];
    final String formattedTime = _formatEndTime(endTime);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.access_time, color: Colors.orange[700], size: 24),
              const SizedBox(width: 8),
              const Text(
                'Machine Busy',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Machine: ${deviceType.toLowerCase()} ${deviceId.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Text(
                'Type: $deviceType',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This machine will be available at $formattedTime',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Color(0xFF2196F3),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMaintenanceDialog(Map<String, dynamic> device) {
    final String deviceType = device['devicetype'] ?? 'Unknown';
    final int deviceId = device['deviceid'] ?? 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.build, color: Colors.red[700], size: 24),
              const SizedBox(width: 8),
              const Text(
                'Under Maintenance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Machine: ${deviceType.toLowerCase()} ${deviceId.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Text(
                'Type: $deviceType',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This machine is currently under maintenance. Please choose another machine.',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Color(0xFF2196F3),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
