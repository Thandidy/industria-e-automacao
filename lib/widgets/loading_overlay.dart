// lib/widgets/loading_overlay.dart

import 'package:flutter/material.dart';

/// Overlay de carregamento (loading) que impede interação durante processos.
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String? message;
  final Widget? child;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    this.message,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (child != null) child!,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      message!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Widget utilitário para mostrar loading de forma mais simples.
class LoadingWidget extends StatelessWidget {
  final bool isLoading;
  final String? message;
  final Widget? child;

  const LoadingWidget({
    super.key,
    required this.isLoading,
    this.message,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: isLoading,
      message: message,
      child: child,
    );
  }
}
