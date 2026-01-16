import 'package:flutter/material.dart';
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
  String selectedWashMode = 'Quick';
  String selectedDetergent = 'O3 Treat';
  String selectedWashTime = '15 Min';
  bool detergentPreferenceEnabled = true;

  String _formatEndTime(String? endTimeStr) {
    if (endTimeStr == null || endTimeStr.isEmpty) return '10:15 pm';

    try {
      final DateTime endTime = DateTime.parse(endTimeStr).toLocal();
      return DateFormat('h:mm a').format(endTime).toLowerCase();
    } catch (e) {
      return '10:15 pm';
    }
  }

  double _calculateTotalPrice() {
    double basePrice = 50.0;
    double detergentPrice = detergentPreferenceEnabled ? 15.0 : 0.0;

    // Add price based on wash mode
    if (selectedWashMode == 'Steam') {
      basePrice += 25.0;
    } else if (selectedWashMode == 'Custom') {
      basePrice += 35.0;
    }

    // Add price based on wash time
    if (selectedWashTime == '30 Min') {
      basePrice += 20.0;
    } else if (selectedWashTime == '45 Min') {
      basePrice += 40.0;
    }

    return basePrice + detergentPrice;
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
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: widget.devices.length,
              itemBuilder: (context, index) {
                final device = widget.devices[index];
                return _buildMachineCard(device);
              },
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
    final String deviceStatus = (device['devicestatus'] ?? '0').toString();
    final String deviceCondition = (device['devicecondition'] ?? 'Good')
        .toString()
        .toLowerCase();
    final String? endTime = device['device_booked_user_end_time'];

    final bool isGoodCondition = deviceCondition == 'good';
    final bool isAvailable =
        (deviceStatus == '0' || deviceStatus.toLowerCase() == 'ready') &&
        isGoodCondition;
    final bool isInUse =
        deviceStatus != '0' &&
        deviceStatus.toLowerCase() != 'ready' &&
        isGoodCondition;

    if (!isGoodCondition) {
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

    if (isAvailable) {
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

    if (isInUse) {
      final String formattedTime = _formatEndTime(endTime);

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
    }

    return Container();
  }

  void _showWashOptionsModal(Map<String, dynamic> device) {
    final String deviceType = device['devicetype'] ?? 'Washer';
    final int deviceId = device['deviceid'] ?? 0;
    final String deviceName =
        '${deviceType.toLowerCase().substring(0, 1).toUpperCase()}${deviceType.toLowerCase().substring(1)} ${deviceId.toString().padLeft(2, '0')}';
    final String machineId = '#${deviceId.toString()}';

    // Reset selections to default when opening modal
    setState(() {
      selectedWashMode = 'Quick';
      selectedDetergent = 'O3 Treat';
      selectedWashTime = '15 Min';
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
                                        'Free',
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
                                  'Quick',
                                  selectedWashMode == 'Quick',
                                  setModalState,
                                  () {
                                    setModalState(() {
                                      setState(() {
                                        selectedWashMode = 'Quick';
                                      });
                                    });
                                  },
                                ),
                                const SizedBox(width: 10),
                                _buildModalOptionButton(
                                  'Steam',
                                  selectedWashMode == 'Steam',
                                  setModalState,
                                  () {
                                    setModalState(() {
                                      setState(() {
                                        selectedWashMode = 'Steam';
                                      });
                                    });
                                  },
                                ),
                                const SizedBox(width: 10),
                                _buildModalOptionButton(
                                  'Custom',
                                  selectedWashMode == 'Custom',
                                  setModalState,
                                  () {
                                    setModalState(() {
                                      setState(() {
                                        selectedWashMode = 'Custom';
                                      });
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Detergent preference',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Switch(
                                  value: detergentPreferenceEnabled,
                                  onChanged: (value) {
                                    setModalState(() {
                                      setState(() {
                                        detergentPreferenceEnabled = value;
                                      });
                                    });
                                  },
                                  activeColor: const Color(0xFF2196F3),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Only show detergent options if enabled
                            if (detergentPreferenceEnabled)
                              Row(
                                children: [
                                  _buildModalOptionButton(
                                    'O3 Treat',
                                    selectedDetergent == 'O3 Treat',
                                    setModalState,
                                    () {
                                      setModalState(() {
                                        setState(() {
                                          selectedDetergent = 'O3 Treat';
                                        });
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  _buildModalOptionButton(
                                    'Deterge+',
                                    selectedDetergent == 'Deterge+',
                                    setModalState,
                                    () {
                                      setModalState(() {
                                        setState(() {
                                          selectedDetergent = 'Deterge+';
                                        });
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  _buildModalOptionButton(
                                    'Stiff Ultra',
                                    selectedDetergent == 'Stiff Ultra',
                                    setModalState,
                                    () {
                                      setModalState(() {
                                        setState(() {
                                          selectedDetergent = 'Stiff Ultra';
                                        });
                                      });
                                    },
                                  ),
                                ],
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 18,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Detergent preference is disabled',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 24),
                            const Text(
                              'Wash Time',
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
                                  '15 Min',
                                  selectedWashTime == '15 Min',
                                  setModalState,
                                  () {
                                    setModalState(() {
                                      setState(() {
                                        selectedWashTime = '15 Min';
                                      });
                                    });
                                  },
                                ),
                                const SizedBox(width: 10),
                                _buildModalOptionButton(
                                  '30 Min',
                                  selectedWashTime == '30 Min',
                                  setModalState,
                                  () {
                                    setModalState(() {
                                      setState(() {
                                        selectedWashTime = '30 Min';
                                      });
                                    });
                                  },
                                ),
                                const SizedBox(width: 10),
                                _buildModalOptionButton(
                                  '45 Min',
                                  selectedWashTime == '45 Min',
                                  setModalState,
                                  () {
                                    setModalState(() {
                                      setState(() {
                                        selectedWashTime = '45 Min';
                                      });
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Center(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);

                                  // Navigate to your existing payment details page
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PaymentDetailsPage(
                                        hubName: widget.hubName,
                                        hubId: widget.hubId,
                                        deviceId: device['deviceid'] ?? 0,
                                        machineId: machineId,
                                        washType: deviceType,
                                        washMode: selectedWashMode,
                                        washTime: selectedWashTime,
                                        detergent: selectedDetergent,
                                        detergentEnabled:
                                            detergentPreferenceEnabled,
                                        totalPrice: _calculateTotalPrice(),
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2196F3),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 48,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
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
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: isSelected ? const Color(0xFF2196F3) : Colors.grey[300]!,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? const Color(0xFF2196F3) : Colors.grey[700],
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
