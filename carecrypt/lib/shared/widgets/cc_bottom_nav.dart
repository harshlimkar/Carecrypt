import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CcBottomNav extends StatelessWidget {
  final int selectedIndex;
  final String role;
  final ValueChanged<int> onTap;

  const CcBottomNav({
    super.key,
    required this.selectedIndex,
    required this.role,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = _getItemsForRole(role);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.3))),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isSelected = i == selectedIndex;
              return GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: isSelected
                      ? BoxDecoration(
                          color: AppTheme.primaryFixed.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(100),
                        )
                      : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item['filled'] as IconData : item['icon'] as IconData,
                        size: 22,
                        color: isSelected ? AppTheme.primary : AppTheme.outline,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['label'] as String,
                        style: AppTextStyles.labelMd.copyWith(
                          color: isSelected ? AppTheme.primary : AppTheme.outline,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getItemsForRole(String role) => switch (role) {
    'patient' => [
        {'icon': Icons.home_outlined, 'filled': Icons.home, 'label': 'Home'},
        {'icon': Icons.folder_outlined, 'filled': Icons.folder, 'label': 'Records'},
        {'icon': Icons.notifications_outlined, 'filled': Icons.notifications, 'label': 'Alerts'},
        {'icon': Icons.key_outlined, 'filled': Icons.key, 'label': 'Access'},
        {'icon': Icons.qr_code_outlined, 'filled': Icons.qr_code, 'label': 'QR'},
      ],
    'doctor' => [
        {'icon': Icons.dashboard_outlined, 'filled': Icons.dashboard, 'label': 'Home'},
        {'icon': Icons.people_outlined, 'filled': Icons.people, 'label': 'Patients'},
        {'icon': Icons.biotech_outlined, 'filled': Icons.biotech, 'label': 'Lab'},
        {'icon': Icons.medication_outlined, 'filled': Icons.medication, 'label': 'Rx'},
      ],
    'lab' => [
        {'icon': Icons.dashboard_outlined, 'filled': Icons.dashboard, 'label': 'Queue'},
        {'icon': Icons.upload_file_outlined, 'filled': Icons.upload_file, 'label': 'Upload'},
      ],
    'pharmacist' => [
        {'icon': Icons.qr_code_scanner_outlined, 'filled': Icons.qr_code_scanner, 'label': 'Scan QR'},
        {'icon': Icons.list_alt_outlined, 'filled': Icons.list_alt, 'label': 'Prescriptions'},
      ],
    'nurse' => [
        {'icon': Icons.nfc_outlined, 'filled': Icons.nfc, 'label': 'NFC'},
        {'icon': Icons.medical_information_outlined, 'filled': Icons.medical_information, 'label': 'Treatment'},
      ],
    _ => [],
  };
}
