// lib/widgets/custom_app_bar.dart

import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../utils/constants.dart';

/// AppBar personalizada com o nome do usuário e seu perfil.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Usuario? usuario;
  final Widget? leading;
  final List<Widget>? actions;
  final double elevation;

  const CustomAppBar({
    super.key,
    required this.title,
    this.usuario,
    this.leading,
    this.actions,
    this.elevation = 0,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          if (usuario != null) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                usuario!.nome.isNotEmpty
                    ? usuario!.nome[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (usuario != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: _perfilCor(usuario!.perfil),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                usuario!.perfil.nome.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      elevation: elevation,
      leading: leading,
      actions: actions,
      centerTitle: false,
    );
  }

  static Color _perfilCor(PerfilUsuario perfil) {
    switch (perfil) {
      case PerfilUsuario.operador:
        return Colors.blue;
      case PerfilUsuario.tecnico:
        return Colors.green;
      case PerfilUsuario.supervisor:
        return Colors.orange;
      case PerfilUsuario.gestor:
        return Colors.purple;
    }
  }
}
