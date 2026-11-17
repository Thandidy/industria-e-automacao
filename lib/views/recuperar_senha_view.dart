// lib/views/recuperar_senha_view.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import '../widgets/snackbar_helper.dart';

enum EtapaRecuperacao {
  identificacao,
  codigo,
  novaSenha,
}

/// Tela de Recuperação de Senha do SIGE
/// Permite recuperar via WhatsApp ou E-mail com código de 6 dígitos.
class RecuperarSenhaView extends StatefulWidget {
  const RecuperarSenhaView({super.key});

  @override
  State<RecuperarSenhaView> createState() => _RecuperarSenhaViewState();
}

class _RecuperarSenhaViewState extends State<RecuperarSenhaView> {
  EtapaRecuperacao _etapaAtual = EtapaRecuperacao.identificacao;

  // Controllers
  final _identificadorController = TextEditingController();
  final _codigoController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  final _formKeyIdentificacao = GlobalKey<FormState>();
  final _formKeyCodigo = GlobalKey<FormState>();
  final _formKeySenha = GlobalKey<FormState>();

  // Estados de controle
  bool _isLoading = false;
  bool _obscureSenha = true;
  bool _obscureConfirmar = true;

  // Dados do processo em andamento
  String? _usuarioId;
  String? _usuarioNome;
  String? _usuarioEmail;
  String? _usuarioTelefone;
  String? _recuperacaoDocId;
  String _canalUtilizado = 'whatsapp'; // 'whatsapp' | 'email'
  String _destinatarioFormatado = '';
  DateTime? _expiraEm;

  // Temporizadores
  Timer? _timerExpira;
  int _segundosRestantes = 900; // 15 minutos = 900 segundos
  Timer? _timerCooldownReenvio;
  int _cooldownReenvio = 0;

  @override
  void dispose() {
    _timerExpira?.cancel();
    _timerCooldownReenvio?.cancel();
    _identificadorController.dispose();
    _codigoController.dispose();
    _novaSenhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  // Mascara e-mail para exibição segura (ex: te***@empresa.com)
  String _mascararEmail(String email) {
    if (!email.contains('@')) return email;
    final partes = email.split('@');
    final nome = partes[0];
    final dominio = partes[1];
    if (nome.length <= 2) {
      return '$nome***@$dominio';
    }
    return '${nome.substring(0, 2)}***${nome.substring(nome.length - 1)}@$dominio';
  }

  // Mascara telefone para exibição segura (ex: (13) 9****-9822)
  String _mascararTelefone(String tel) {
    var digitos = tel.replaceAll(RegExp(r'\D'), '');
    if (digitos.isEmpty) return tel;

    // Se vier com DDI 55 (ex: 5513996949822 -> 13 dígitos ou 551388889999 -> 12 dígitos)
    if (digitos.startsWith('55') && (digitos.length == 12 || digitos.length == 13)) {
      digitos = digitos.substring(2);
    }

    if (digitos.length == 11) {
      // Celular com 9 dígitos: DDD (2) + 9 (1) + 4 mascarados + 4 visíveis
      // Ex: 13 99694 9822 -> (13) 9****-9822
      final ddd = digitos.substring(0, 2);
      final ultimos4 = digitos.substring(7);
      return '($ddd) 9****-$ultimos4';
    } else if (digitos.length == 10) {
      // Fixo ou número antigo com 8 dígitos: DDD (2) + 4 mascarados + 4 visíveis
      // Ex: 13 3232 9822 -> (13) ****-9822
      final ddd = digitos.substring(0, 2);
      final ultimos4 = digitos.substring(6);
      return '($ddd) ****-$ultimos4';
    } else if (digitos.length >= 8) {
      // Sem DDD informado, apenas número local
      final ultimos4 = digitos.substring(digitos.length - 4);
      return '****-$ultimos4';
    }

    return tel;
  }

  void _iniciarContadorExpiracao() {
    _timerExpira?.cancel();
    _segundosRestantes = 900; // 15 minutos
    _timerExpira = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_segundosRestantes <= 1) {
        timer.cancel();
        setState(() => _segundosRestantes = 0);
      } else {
        setState(() => _segundosRestantes--);
      }
    });
  }

  void _iniciarCooldownReenvio() {
    _timerCooldownReenvio?.cancel();
    setState(() => _cooldownReenvio = 60);
    _timerCooldownReenvio = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownReenvio <= 1) {
        timer.cancel();
        setState(() => _cooldownReenvio = 0);
      } else {
        setState(() => _cooldownReenvio--);
      }
    });
  }

  String _formatarTempoRestante(int totalSegundos) {
    final minutos = totalSegundos ~/ 60;
    final segundos = totalSegundos % 60;
    return '${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
  }

  /// 1. Busca o usuário no Firestore e envia o código de 6 dígitos
  Future<void> _solicitarCodigo() async {
    if (!_formKeyIdentificacao.currentState!.validate()) return;

    final input = _identificadorController.text.trim();
    final ehEmail = input.contains('@');

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      DocumentSnapshot? usuarioDoc;
      Map<String, dynamic>? usuarioData;

      if (ehEmail) {
        // Busca por e-mail (exato ou lowercase)
        final snap = await firestore
            .collection('usuarios')
            .where('email', isEqualTo: input.toLowerCase())
            .limit(1)
            .get();

        if (snap.docs.isNotEmpty) {
          usuarioDoc = snap.docs.first;
          usuarioData = usuarioDoc.data() as Map<String, dynamic>?;
        } else {
          // Tenta busca exata sem lowercase
          final snapExato = await firestore
              .collection('usuarios')
              .where('email', isEqualTo: input)
              .limit(1)
              .get();
          if (snapExato.docs.isNotEmpty) {
            usuarioDoc = snapExato.docs.first;
            usuarioData = usuarioDoc.data() as Map<String, dynamic>?;
          }
        }
      } else {
        // Busca por telefone
        final digitosInput = input.replaceAll(RegExp(r'\D'), '');
        final ultimos8 = digitosInput.length >= 8 ? digitosInput.substring(digitosInput.length - 8) : digitosInput;

        // Consulta todos os usuários para comparação robusta de formato de telefone
        final snapUsuarios = await firestore.collection('usuarios').get();
        for (final doc in snapUsuarios.docs) {
          final data = (doc.data() as Map<String, dynamic>?) ?? {};
          final telDoc = (data['telefone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
          if (telDoc.isNotEmpty && telDoc.endsWith(ultimos8)) {
            usuarioDoc = doc;
            usuarioData = data;
            break;
          }
        }
      }

      if (usuarioDoc == null || usuarioData == null) {
        if (!mounted) return;
        SnackbarHelper.showSnackbar(
          context: context,
          message: ehEmail
              ? 'Nenhum usuário localizado com o e-mail informado.'
              : 'Nenhum usuário localizado com o telefone informado.',
          isError: true,
        );
        return;
      }

      final userId = usuarioDoc.id;
      final nome = usuarioData['nome'] ?? usuarioData['nomeFuncionario'] ?? 'Colaborador';
      final email = usuarioData['email'] ?? '';
      final tel = usuarioData['telefone'] ?? '';

      if (!ehEmail && (tel == null || tel.toString().trim().isEmpty)) {
        if (!mounted) return;
        SnackbarHelper.showSnackbar(
          context: context,
          message: 'Este usuário não possui telefone cadastrado. Tente recuperar informando seu e-mail.',
          isError: true,
        );
        return;
      }

      // Gera código numérico aleatório de 6 dígitos
      final rng = Random.secure();
      final codigo = (100000 + rng.nextInt(900000)).toString();
      final agora = DateTime.now();
      final expiraEm = agora.add(const Duration(minutes: 15));

      // Invalida solicitações pendentes anteriores deste mesmo usuário
      final pendentesAnteriores = await firestore
          .collection('recuperacoes_senha')
          .where('usuarioId', isEqualTo: userId)
          .where('status', isEqualTo: 'pendente')
          .get();

      final batch = firestore.batch();
      for (final docAntigo in pendentesAnteriores.docs) {
        batch.update(docAntigo.reference, {'status': 'cancelado'});
      }
      await batch.commit();

      // Grava na coleção dedicada 'recuperacoes_senha'
      final docCriado = await firestore.collection('recuperacoes_senha').add({
        'usuarioId': userId,
        'nome': nome,
        'email': email,
        'telefone': tel,
        'identificador': input,
        'canal': ehEmail ? 'email' : 'whatsapp',
        'codigo': codigo,
        'status': 'pendente',
        'usado': false,
        'tentativas': 0,
        'criadoEm': FieldValue.serverTimestamp(),
        'expiraEm': Timestamp.fromDate(expiraEm),
      });

      if (!mounted) return;

      setState(() {
        _usuarioId = userId;
        _usuarioNome = nome;
        _usuarioEmail = email;
        _usuarioTelefone = tel;
        _recuperacaoDocId = docCriado.id;
        _canalUtilizado = ehEmail ? 'email' : 'whatsapp';
        _destinatarioFormatado = ehEmail ? _mascararEmail(email) : _mascararTelefone(tel.toString());
        _expiraEm = expiraEm;
        _etapaAtual = EtapaRecuperacao.codigo;
      });

      _iniciarContadorExpiracao();
      _iniciarCooldownReenvio();

      SnackbarHelper.showSnackbar(
        context: context,
        message: ehEmail
            ? 'Código gerado! Enviando para o seu e-mail...'
            : 'Código gerado! Enviando para o seu WhatsApp...',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Erro ao processar solicitação: ${e.toString().replaceFirst("Exception: ", "")}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 2. Valida o código de 6 dígitos informado
  Future<void> _validarCodigo() async {
    if (!_formKeyCodigo.currentState!.validate()) return;
    if (_recuperacaoDocId == null) return;

    final codigoDigitado = _codigoController.text.trim();

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final docRef = firestore.collection('recuperacoes_senha').doc(_recuperacaoDocId);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        if (!mounted) return;
        SnackbarHelper.showSnackbar(
          context: context,
          message: 'Solicitação não encontrada. Inicie o processo novamente.',
          isError: true,
        );
        return;
      }

      final data = docSnap.data() ?? {};
      final codigoCorreto = data['codigo']?.toString() ?? '';
      final usado = data['usado'] == true;
      final tentativas = (data['tentativas'] as num?)?.toInt() ?? 0;
      final expiraTimestamp = data['expiraEm'] as Timestamp?;
      final expiraEmData = expiraTimestamp?.toDate() ?? DateTime.now();

      if (usado) {
        if (!mounted) return;
        SnackbarHelper.showSnackbar(
          context: context,
          message: 'Este código já foi utilizado.',
          isError: true,
        );
        return;
      }

      if (DateTime.now().isAfter(expiraEmData) || _segundosRestantes <= 0) {
        if (!mounted) return;
        SnackbarHelper.showSnackbar(
          context: context,
          message: 'Este código expirou. Solicite um novo código.',
          isError: true,
        );
        return;
      }

      if (tentativas >= 5) {
        await docRef.update({'status': 'bloqueado'});
        if (!mounted) return;
        SnackbarHelper.showSnackbar(
          context: context,
          message: 'Número excessivo de tentativas incorretas. Solicite um novo código.',
          isError: true,
        );
        return;
      }

      // Validação do código
      if (codigoDigitado != codigoCorreto) {
        final novasTentativas = tentativas + 1;
        await docRef.update({'tentativas': novasTentativas});
        final restantes = 5 - novasTentativas;

        if (!mounted) return;
        SnackbarHelper.showSnackbar(
          context: context,
          message: restantes > 0
              ? 'Código incorreto. Você tem mais $restantes tentativa(s).'
              : 'Código bloqueado por tentativas excessivas.',
          isError: true,
        );
        return;
      }

      // Código válido! Avança para o passo de nova senha
      if (!mounted) return;
      setState(() {
        _etapaAtual = EtapaRecuperacao.novaSenha;
      });

      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Código confirmado com sucesso! Agora defina sua nova senha.',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Erro ao validar código: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 3. Atualiza a senha no banco e finaliza o processo
  Future<void> _atualizarSenha() async {
    if (!_formKeySenha.currentState!.validate()) return;
    if (_usuarioId == null || _recuperacaoDocId == null) return;

    final novaSenha = _novaSenhaController.text;

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Atualiza a senha na coleção de usuários
      await firestore.collection('usuarios').doc(_usuarioId).update({
        'senha': novaSenha,
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      // 2. Marca o código como utilizado e concluído
      await firestore.collection('recuperacoes_senha').doc(_recuperacaoDocId).update({
        'usado': true,
        'status': 'concluido',
        'concluidoEm': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Senha atualizada com sucesso! Você já pode entrar com sua nova senha.',
        isSuccess: true,
      );

      // Retorna para a tela de login
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Erro ao atualizar a senha: $e',
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
      appBar: AppBar(
        title: const Text('Recuperação de Senha'),
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
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildEtapaConteudo(theme),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEtapaConteudo(ThemeData theme) {
    switch (_etapaAtual) {
      case EtapaRecuperacao.identificacao:
        return _buildEtapaIdentificacao(theme);
      case EtapaRecuperacao.codigo:
        return _buildEtapaCodigo(theme);
      case EtapaRecuperacao.novaSenha:
        return _buildEtapaNovaSenha(theme);
    }
  }

  /// ETAPA 1: Identificação (Telefone ou E-mail)
  Widget _buildEtapaIdentificacao(ThemeData theme) {
    return Form(
      key: _formKeyIdentificacao,
      child: Column(
        key: const ValueKey('etapa_identificacao'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppCores.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset,
              size: 54,
              color: AppCores.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Esqueceu sua senha?',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Informe o seu e-mail cadastrado ou o seu número de WhatsApp para receber um código de 6 dígitos de verificação.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),

          TextFormField(
            controller: _identificadorController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail ou Telefone com DDD',
              hintText: 'ex: usuario@empresa.com ou 11999998888',
              prefixIcon: Icon(Icons.contact_mail_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Informe seu e-mail ou telefone';
              }
              final limpo = value.trim();
              if (!limpo.contains('@')) {
                final digitos = limpo.replaceAll(RegExp(r'\D'), '');
                if (digitos.length < 8) {
                  return 'Informe um telefone válido com DDD (mínimo 8 dígitos)';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Informações visuais sobre os canais
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 20, color: AppCores.amareloAlerta),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Se inserir o telefone, você receberá via WhatsApp. Se inserir o e-mail, receberá na sua caixa de entrada.',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isLoading ? null : _solicitarCodigo,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Enviar Código',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('Lembrou sua senha? Voltar ao login'),
          ),
        ],
      ),
    );
  }

  /// ETAPA 2: Validação do Código de 6 Dígitos
  Widget _buildEtapaCodigo(ThemeData theme) {
    final ehWhatsApp = _canalUtilizado == 'whatsapp';

    return Form(
      key: _formKeyCodigo,
      child: Column(
        key: const ValueKey('etapa_codigo'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ehWhatsApp
                  ? const Color(0xFF25D366).withValues(alpha: 0.15)
                  : AppCores.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              ehWhatsApp ? Icons.phone_android : Icons.mark_email_read_outlined,
              size: 54,
              color: ehWhatsApp ? const Color(0xFF25D366) : AppCores.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Código de Verificação',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            ehWhatsApp
                ? 'Enviamos um código de 6 dígitos para o seu WhatsApp no número:\n$_destinatarioFormatado'
                : 'Enviamos um código de 6 dígitos para o seu e-mail:\n$_destinatarioFormatado',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Campo de Código OTP estilizado
          TextFormField(
            controller: _codigoController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 10,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              hintText: '000000',
              hintStyle: TextStyle(
                letterSpacing: 10,
                color: Colors.white24,
              ),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(vertical: 16),
            ),
            validator: (value) {
              if (value == null || value.trim().length != 6) {
                return 'Digite o código completo com 6 dígitos';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Temporizador de Expiração
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 18,
                color: _segundosRestantes < 120 ? AppCores.parada : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Código expira em: ${_formatarTempoRestante(_segundosRestantes)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _segundosRestantes < 120 ? AppCores.parada : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isLoading || _segundosRestantes <= 0 ? null : _validarCodigo,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Verificar Código',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 12),

          // Botão Reenviar Código com Cooldown
          TextButton.icon(
            onPressed: _cooldownReenvio > 0 || _isLoading ? null : _solicitarCodigo,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(
              _cooldownReenvio > 0
                  ? 'Reenviar código em (${_cooldownReenvio}s)'
                  : 'Não recebeu? Reenviar código',
            ),
          ),

          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    setState(() {
                      _etapaAtual = EtapaRecuperacao.identificacao;
                      _codigoController.clear();
                    });
                  },
            child: const Text('Alterar telefone ou e-mail'),
          ),
        ],
      ),
    );
  }

  /// ETAPA 3: Definição da Nova Senha
  Widget _buildEtapaNovaSenha(ThemeData theme) {
    return Form(
      key: _formKeySenha,
      child: Column(
        key: const ValueKey('etapa_novasenha'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppCores.operando.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 54,
              color: AppCores.operando,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Redefinir Senha',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Olá, $_usuarioNome! Crie uma nova senha de acesso segura para sua conta.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Nova Senha
          TextFormField(
            controller: _novaSenhaController,
            obscureText: _obscureSenha,
            decoration: InputDecoration(
              labelText: 'Nova Senha',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureSenha ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureSenha = !_obscureSenha),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Informe a nova senha';
              }
              if (value.length < 6) {
                return 'A senha deve possuir pelo menos 6 caracteres';
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
              labelText: 'Confirmar Nova Senha',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmar ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureConfirmar = !_obscureConfirmar),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirme a nova senha';
              }
              if (value != _novaSenhaController.text) {
                return 'As senhas não coincidem';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),

          ElevatedButton(
            onPressed: _isLoading ? null : _atualizarSenha,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Atualizar Senha',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
