// Emergency Alert Banner Widget for TALOWA Messages
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class EmergencyAlertBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onTap;

  const EmergencyAlertBanner({
    super.key,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.red,
        border: Border(
          bottom: BorderSide(color: Colors.red, width: 1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            const Icon(
              Icons.warning,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}