// lib/widgets/permission_guard.dart

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../models/usuario.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';

/// Widget declarativo de RBAC para renderizar componentes
/// exclusivamente se o usuário possuir a permissão necessária.
class PermissionGuard extends StatelessWidget {
  final AppPermission permission;
  final Widget child;
  final Widget? fallback;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final usuario = context.select<AuthProvider, Usuario?>((p) => p.usuario);

    if (usuario != null && usuario.can(permission)) {
      return child;
    }

    return fallback ?? const SizedBox.shrink();
  }
}

/// Extensão de conveniência no BuildContext para checagens rápidas
extension RBACContext on BuildContext {
  bool can(AppPermission permission) {
    final user = read<AuthProvider>().usuario;
    return user?.can(permission) ?? false;
  }

  Usuario? get currentUser => read<AuthProvider>().usuario;
  PerfilUsuario? get currentRole => read<AuthProvider>().perfil;
}

