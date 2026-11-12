// lib/views/solicitar_acesso_view.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import '../widgets/snackbar_helper.dart';

/// Tela para novos usuários solicitarem cadastro/acesso ao sistema SIGE.
/// Os dados são enviados para a coleção 'solicitacoes_login' no Firestore,
/// acionando a notificação via WhatsApp para o gestor aprovar ou rejeitar.
class SolicitarAcessoView extends StatefulWidget {
  const SolicitarAcessoView({super.key});

  @override
  State<SolicitarAcessoView> createState() => _SolicitarAcessoViewState();
}

class _SolicitarAcessoViewState extends State<SolicitarAcessoView> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  PerfilUsuario _selectedPerfil = PerfilUsuario.operador;
  bool _isLoading = false;
  bool _obscureSenha = true;
  bool _obscureConfirmar = true;

  // Guarda o ID da solicitação recém enviada para acompanhar em tempo real
  String? _solicitacaoId;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  String _perfilParaString(PerfilUsuario perfil) {
    switch (perfil) {
      case PerfilUsuario.operador:
        return 'Operador';
      case PerfilUsuario.tecnico:
        return 'Técnico';
      case PerfilUsuario.supervisor:
        return 'Supervisor';
      case PerfilUsuario.gestor:
        return 'Gestor Industrial';
    }
  }

  Future<void> _enviarSolicitacao() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final nome = _nomeController.text.trim();
      final email = _emailController.text.trim();
      final telefone = _telefoneController.text.trim();
      final senha = _senhaController.text;
      final perfilStr = _perfilParaString(_selectedPerfil);

      // Envia os dados para a coleção solicitacoes_login no Firestore
      final docRef = await FirebaseFirestore.instance.collection('solicitacoes_login').add({
        'nome': nome,
        'nomeFuncionario': nome,
        'email': email,
        'telefone': telefone,
        'senha': senha,
        'perfil': perfilStr,
        'status': 'pendente',
        'notificado': false,
        'criadoEm': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _solicitacaoId = docRef.id;
        _isLoading = false;
      });

      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Solicitação enviada com sucesso! Aguardando aprovação via WhatsApp.',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Erro ao enviar solicitação: $e',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitação de Cadastro'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _solicitacaoId != null
                  ? _buildAguardandoAprovacao(theme)
                  : _buildFormulario(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormulario(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_add_alt_1,
              size: 56,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Novo Cadastro de Acesso',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Preencha seus dados para solicitar autorização de acesso ao gestor via WhatsApp.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),

          // Nome Completo
          TextFormField(
            controller: _nomeController,
            decoration: const InputDecoration(
              labelText: 'Nome Completo',
              prefixIcon: Icon(Icons.badge_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Informe seu nome completo';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // E-mail / Login
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail ou Matrícula',
              prefixIcon: Icon(Icons.alternate_email),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Informe seu e-mail ou matrícula';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Telefone / WhatsApp (Opcional)
          TextFormField(
            controller: _telefoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telefone / WhatsApp (Opcional)',
              hintText: 'Ex: 11999998888',
              helperText: 'Você receberá uma mensagem no WhatsApp quando seu acesso for aprovado',
              prefixIcon: Icon(Icons.phone_android),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Perfil desejado
          DropdownButtonFormField<PerfilUsuario>(
            initialValue: _selectedPerfil,
            decoration: const InputDecoration(
              labelText: 'Perfil de Acesso Desejado',
              prefixIcon: Icon(Icons.manage_accounts_outlined),
              border: OutlineInputBorder(),
            ),
            items: PerfilUsuario.values.map((perfil) {
              return DropdownMenuItem(
                value: perfil,
                child: Text(perfil.nome),
              );
            }).toList(),
            onChanged: (novo) {
              if (novo != null) {
                setState(() => _selectedPerfil = novo);
              }
            },
          ),
          const SizedBox(height: 16),

          // Senha
          TextFormField(
            controller: _senhaController,
            obscureText: _obscureSenha,
            decoration: InputDecoration(
              labelText: 'Senha de Acesso',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureSenha ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscureSenha = !_obscureSenha),
              ),
            ),
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'A senha deve ter pelo menos 6 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirmar Senha
          TextFormField(
            controller: _confirmarSenhaController,
            obscureText: _obscureConfirmar,
            decoration: InputDecoration(
              labelText: 'Confirmar Senha',
              prefixIcon: const Icon(Icons.lock_reset),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmar ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscureConfirmar = !_obscureConfirmar),
              ),
            ),
            validator: (value) {
              if (value != _senhaController.text) {
                return 'As senhas não coincidem';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Botão Enviar Solicitação
          ElevatedButton(
            onPressed: _isLoading ? null : _enviarSolicitacao,
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
                    'Solicitar Acesso',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Já possui cadastro? Fazer login'),
          ),
        ],
      ),
    );
  }

  Widget _buildAguardandoAprovacao(ThemeData theme) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('solicitacoes_login')
          .doc(_solicitacaoId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final status = (data['status'] ?? 'pendente').toString().toLowerCase();

        if (status == 'aprovado') {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                'Cadastro Aprovado!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'O gestor autorizou sua solicitação pelo WhatsApp. Seus dados foram salvos com sucesso e seu acesso está liberado!',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.login),
                label: const Text('Ir para o Login'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          );
        } else if (status == 'rejeitado') {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cancel_outlined, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Solicitação Rejeitada',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sua solicitação de acesso foi rejeitada pelo gestor.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () {
                  setState(() => _solicitacaoId = null);
                },
                child: const Text('Tentar Novamente'),
              ),
            ],
          );
        }

        // Status Pendente
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            const SizedBox(height: 24),
            Text(
              'Aguardando Aprovação do Gestor',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade400),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_android, color: Colors.green, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Uma mensagem com seu pedido foi enviada ao WhatsApp do gestor. Esta tela atualizará automaticamente assim que ele responder.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Protocolo: $_solicitacaoId',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Voltar para o Login'),
            ),
          ],
        );
      },
    );
  }
}

