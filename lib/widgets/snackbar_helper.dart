// lib/widgets/snackbar_helper.dart

import 'package:material_ui/material_ui.dart';

/// Helper para exibir Toasts / SnackBars modernos no TOPO DA TELA com alta legibilidade e contraste.
class SnackbarHelper {
  static OverlayEntry? _currentToast;

  /// Exibe um toast animado no topo da tela com contraste elevado e alta visibilidade.
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
    final toastDuration = duration ?? const Duration(seconds: 4);

    // Remove toast anterior caso ainda esteja ativo
    try {
      _currentToast?.remove();
      _currentToast = null;
    } catch (_) {}

    final overlay = Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.maybeOf(context);

    // Se o Overlay estiver disponível, exibe o Toast flutuante no TOPO da tela
    if (overlay != null) {
      late OverlayEntry entry;

      entry = OverlayEntry(
        builder: (ctx) => _TopToastWidget(
          message: message,
          isError: isError,
          isSuccess: isSuccess,
          isWarning: isWarning,
          actionLabel: actionLabel,
          onAction: onAction,
          onDismiss: () {
            if (_currentToast == entry) {
              try {
                entry.remove();
              } catch (_) {}
              _currentToast = null;
            }
          },
        ),
      );

      _currentToast = entry;
      overlay.insert(entry);

      // Auto-fechamento após a duração
      Future.delayed(toastDuration, () {
        if (_currentToast == entry) {
          try {
            entry.remove();
          } catch (_) {}
          _currentToast = null;
        }
      });
      return;
    }

    // Fallback padrão via ScaffoldMessenger (também com alto contraste e legibilidade)
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            _getIcon(isError, isSuccess, isWarning),
            size: 22,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: _getBackgroundColor(isError, isSuccess, isWarning),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      duration: toastDuration,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      action: actionWidget ??
          (actionLabel != null && onAction != null
              ? SnackBarAction(
                  label: actionLabel,
                  onPressed: onAction,
                  textColor: Colors.white,
                )
              : null),
    );

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(snackBar);
  }

  static IconData _getIcon(
    bool isError,
    bool isSuccess,
    bool isWarning,
  ) {
    if (isError) return Icons.error_rounded;
    if (isSuccess) return Icons.check_circle_rounded;
    if (isWarning) return Icons.warning_amber_rounded;
    return Icons.info_rounded;
  }

  static Color _getBackgroundColor(bool isError, bool isSuccess, bool isWarning) {
    if (isError) return const Color(0xFFDC2626); // Vermelho vibrante de alto contraste (Red 600)
    if (isSuccess) return const Color(0xFF16A34A); // Verde nítido (Green 600)
    if (isWarning) return const Color(0xFFD97706); // Âmbar vívido (Amber 600)
    return const Color(0xFF6D28D9); // Roxo oficial SIGE
  }
}

/// Widget animado exibido no topo da tela (Top Toast)
class _TopToastWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final bool isSuccess;
  final bool isWarning;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _TopToastWidget({
    required this.message,
    required this.isError,
    required this.isSuccess,
    required this.isWarning,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
  });

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    try {
      await _controller.reverse();
    } catch (_) {}
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = SnackbarHelper._getBackgroundColor(
      widget.isError,
      widget.isSuccess,
      widget.isWarning,
    );
    final iconData = SnackbarHelper._getIcon(
      widget.isError,
      widget.isSuccess,
      widget.isWarning,
    );

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SlideTransition(
            position: _offsetAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 580),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(iconData, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            decoration: TextDecoration.none,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      if (widget.actionLabel != null && widget.onAction != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            widget.onAction?.call();
                            _dismiss();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                          child: Text(
                            widget.actionLabel!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: _dismiss,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
