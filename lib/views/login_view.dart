// lib/views/login_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../providers/auth_provider.dart';
import '../widgets/snackbar_helper.dart';

/// Tela de login com campos de usuário/senha e seleção rápida de perfil.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  PerfilUsuario _selectedPerfil = PerfilUsuario.operador;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = _userIdController.text.trim();
      final password = _passwordController.text;

      final authProvider = context.read<AuthProvider>();
      await authProvider.login(userId, password, _selectedPerfil);

      if (!mounted) return;

      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Login realizado com sucesso! Bem-vindo, ${authProvider.nome ?? "Usuário"}',
        isSuccess: true,
      );

      Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Falha no login: ${e.toString()}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLoginRapido(PerfilUsuario perfil) async {
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.loginRapido(perfil);

      if (!mounted) return;

      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Conectado como ${perfil.nome} (${authProvider.nome})',
        isSuccess: true,
      );

      Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Falha ao acessar: ${e.toString()}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cabeçalho / Logo
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.precision_manufacturing,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Indústria & Manutenção',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Controle de Ativos e Gestão de Ocorrências',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Campo de Usuário
                    TextFormField(
                      controller: _userIdController,
                      decoration: const InputDecoration(
                        labelText: 'Matrícula / ID de Usuário',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Informe o ID de usuário';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Campo de Senha
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Senha de Acesso',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Informe sua senha';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Seleção de Perfil
                    DropdownButtonFormField<PerfilUsuario>(
                      initialValue: _selectedPerfil,
                      decoration: const InputDecoration(
                        labelText: 'Perfil de Acesso',
                        prefixIcon: Icon(Icons.manage_accounts_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: PerfilUsuario.values.map((perfil) {
                        return DropdownMenuItem(
                          value: perfil,
                          child: Row(
                            children: [
                              Icon(perfil.icon, size: 20, color: _perfilColor(perfil)),
                              const SizedBox(width: 8),
                              Text(perfil.nome),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (novo) {
                        if (novo != null) {
                          setState(() => _selectedPerfil = novo);
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // Botão Entrar
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Entrar',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(height: 36),

                    // Divisor
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OU ACESSO RÁPIDO DEMO',
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Botões de Demonstração
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: PerfilUsuario.values.map((perfil) {
                        return _DemoButton(
                          perfil: perfil,
                          onPressed: _isLoading ? null : () => _handleLoginRapido(perfil),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _perfilColor(PerfilUsuario perfil) {
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

class _DemoButton extends StatelessWidget {
  final PerfilUsuario perfil;
  final VoidCallback? onPressed;

  const _DemoButton({
    required this.perfil,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cor = _perfilColor(perfil);

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(perfil.icon, size: 18, color: cor),
      label: Text(
        perfil.nome,
        style: TextStyle(color: cor, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: cor.withValues(alpha: 0.6)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  static Color _perfilColor(PerfilUsuario perfil) {
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
