import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:cabina360_v2_2/models/permission_config.dart';
import 'package:cabina360_v2_2/services/permission_service.dart';

/// A single row showing a permission's status with an action button.
class PermissionItemWidget extends StatelessWidget {
  final PermissionConfig config;
  final PermissionStatus status;
  final VoidCallback onRequest;

  const PermissionItemWidget({
    required this.config,
    required this.status,
    required this.onRequest,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isGranted = status.isGranted;
    final isPermanentlyDenied = status.isPermanentlyDenied;
    final isDenied = status.isDenied || status.isLimited || status.isRestricted;

    // Choose colors and icons based on status
    final Color statusColor;
    final IconData statusIcon;
    final String statusText;
    final String actionText;

    if (isGranted) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Concedido';
      actionText = '';
    } else if (isPermanentlyDenied) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = 'Denegado permanentemente';
      actionText = 'Abrir ajustes';
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.error_outline;
      statusText = config.isRequired ? 'Requerido' : 'Opcional';
      actionText = 'Conceder';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isGranted
            ? BorderSide(color: Colors.green.withValues(alpha: 0.4), width: 1)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(config.icon, color: statusColor, size: 24),
            ),
            const SizedBox(width: 14),
            // Title + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        config.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!config.isRequired)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Opcional',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    config.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status / Action
            if (isGranted)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, color: statusColor, size: 24),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 28,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: isPermanentlyDenied
                            ? Colors.red
                            : Theme.of(context).primaryColor,
                      ),
                      onPressed: isPermanentlyDenied
                          ? () async {
                              await PermissionService.instance.openSettings();
                            }
                          : onRequest,
                      child: Text(
                        actionText,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
