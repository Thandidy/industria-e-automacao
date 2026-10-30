// lib/widgets/snackbar_helper.dart

import 'package:flutter/material.dart';

/// Helper para exibir SnackBars padronizados com base no tipo de mensagem.
class SnackbarHelper {
  static void showSnackbar({
    required BuildContext context,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    SnackBarAction? actionWidget,
    Duration? duration,
    bool isError = false,
    bool isSuccess = false,
    bool isWarning = false,
  }) {
    final theme = Theme.of(context);

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            _getIcon(isError, isSuccess, isWarning),
            size: 20,
            color: _getIconColor(isError, isSuccess, isWarning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _getTextColor(isError, isSuccess, isWarning),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: _getBackgroundColor(isError, isSuccess, isWarning),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      duration: duration ?? const Duration(seconds: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      action: actionWidget ??
          (actionLabel != null && onAction != null
              ? SnackBarAction(
                  label: actionLabel,
                  onPressed: onAction,
                  textColor: _getIconColor(isError, isSuccess, isWarning),
                )
              : null),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static IconData _getIcon(
    bool isError,
    bool isSuccess,
    bool isWarning,
  ) {
    if (isError) return Icons.error_outline;
    if (isSuccess) return Icons.check_circle_outline;
    if (isWarning) return Icons.warning_amber_rounded;
    return Icons.info_outline;
  }

  static Color _getIconColor(bool isError, bool isSuccess, bool isWarning) {
    if (isError) return Colors.red;
    if (isSuccess) return Colors.green;
    if (isWarning) return Colors.amber;
    return Colors.blue;
  }

  static Color _getTextColor(bool isError, bool isSuccess, bool isWarning) {
    if (isError) return Colors.red;
    if (isSuccess) return Colors.green;
    if (isWarning) return Colors.amber;
    return Colors.blue;
  }

  static Color _getBackgroundColor(bool isError, bool isSuccess, bool isWarning) {
    if (isError) return Colors.red.shade900;
    if (isSuccess) return Colors.green.shade900;
    if (isWarning) return Colors.amber.shade900;
    return Colors.blue.shade900;
  }
}
