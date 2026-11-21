// lib/views/equipamento_detalhe_view.dart

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../models/equipamento.dart';
import '../models/ocorrencia.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../providers/auth_provider.dart';
import '../providers/ocorrencia_provider.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/status_badge.dart';
import '../widgets/snackbar_helper.dart';

/// Tela de detalhes de um equipamento com timeline e ações RBAC por perfil.
class EquipamentoDetalheView extends StatefulWidget {
  final String equipamentoId;

  const EquipamentoDetalheView({
    super.key,
    required this.equipamentoId,
  });

  @override
  State<EquipamentoDetalheView> createState() => _EquipamentoDetalheViewState();
}

class _EquipamentoDetalheViewState extends State<EquipamentoDetalheView> {
  final _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 1. Operador: Formulário validado para Registrar Parada Crítica
  Future<void> _abrirModalRegistrarParada(Equipamento equipamento) async {
    final formKey = GlobalKey<FormState>();
    final motivoController = TextEditingController();
    String prioridadeSelecionada = 'Alta';

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Registrar Parada Crítica'),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Equipamento: ${equipamento.tag} - ${equipamento.nome}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: motivoController,
                    decoration: const InputDecoration(
                      labelText: 'Motivo Inicial da Parada',
                      hintText: 'Ex.: Ruído anormal, vazamento de óleo...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    validator: (v) => (v == null || v.trim().length < 5)
                        ? 'Informe o motivo inicial (mín. 5 letras)'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: prioridadeSelecionada,
                    decoration: const InputDecoration(
                      labelText: 'Grau de Prioridade',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Baixa', child: Text('Baixa')),
                      DropdownMenuItem(value: 'Média', child: Text('Média')),
                      DropdownMenuItem(value: 'Alta', child: Text('Alta')),
                      DropdownMenuItem(value: 'Crítica', child: Text('Crítica (Exige Supervisor)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => prioridadeSelecionada = v);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Confirmar Parada', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmou != true) return;
    if (!mounted) return;

    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) return;

    setState(() => _isLoading = true);
    try {
      await context.read<OcorrenciaProvider>().registrarParadaCritica(
            equipamentoId: equipamento.id,
            motivo: motivoController.text.trim(),
            prioridade: prioridadeSelecionada,
            usuario: usuario,
          );

      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Parada registrada com sucesso. Notificação enviada à manutenção.',
        isWarning: true,
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 1.1 Operador: Solicitar Atendimento
  Future<void> _solicitarAtendimento(Ocorrencia ocorrencia) async {
    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) return;

    setState(() => _isLoading = true);
    try {
      await context.read<OcorrenciaProvider>().solicitarAtendimento(
            ocorrenciaId: ocorrencia.id,
            usuario: usuario,
          );

      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Solicitação urgente enviada via WhatsApp para o Supervisor e Técnico!',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. Técnico: Assumir Manutenção
  Future<void> _assumirManutencao(Ocorrencia ocorrencia) async {
    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) return;

    setState(() => _isLoading = true);
    try {
      await context.read<OcorrenciaProvider>().assumirAtendimento(
            ocorrenciaId: ocorrencia.id,
            usuario: usuario,
          );

      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Você assumiu a ocorrência. Equipamento em Manutenção.',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2.1 Técnico: Pausar por Falta de Material
  Future<void> _abrirModalPausaMaterial(Ocorrencia ocorrencia) async {
    final controller = TextEditingController();

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pausar Atendimento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Informe o material/insumo que está aguardando:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Material em Falta',
                hintText: 'Ex.: Retentor 45mm, correia trapezoidal...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar Pausa'),
          ),
        ],
      ),
    );

    if (confirmou != true) return;
    if (!mounted) return;

    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) return;

    setState(() => _isLoading = true);
    try {
      await context.read<OcorrenciaProvider>().pausarAguardandoMaterial(
            ocorrenciaId: ocorrencia.id,
            motivoPausa: controller.text.trim().isNotEmpty
                ? controller.text.trim()
                : 'Aguardando materiais do almoxarifado',
            usuario: usuario,
          );

      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Status atualizado para "Aguardando Material".',
        isWarning: true,
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2.2 Técnico: Preencher Laudo e Finalizar Ocorrência (Validação estrita)
  Future<void> _abrirModalLaudoFinalizacao(Ocorrencia ocorrencia) async {
    final formKey = GlobalKey<FormState>();
    final laudoController = TextEditingController();
    final pecasController = TextEditingController();

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assignment_turned_in, color: Colors.green),
            SizedBox(width: 8),
            Text('Laudo Técnico de Liberação'),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Equipamento: ${ocorrencia.equipamentoTag}'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: laudoController,
                  decoration: const InputDecoration(
                    labelText: 'Parecer Técnico Detalhado *',
                    hintText: 'Descreva os reparos, testes e calibrações efetuadas...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  validator: (v) {
                    if (v == null || v.trim().length < 10) {
                      return 'O laudo é obrigatório (mínimo 10 caracteres)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pecasController,
                  decoration: const InputDecoration(
                    labelText: 'Peças/Componentes Substituídos (opcional)',
                    hintText: 'Separe por vírgula (ex: Rolamento 6205, Óleo ISO 68)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Emitir Laudo & Finalizar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmou != true) return;
    if (!mounted) return;

    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) return;

    final pecas = pecasController.text
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    setState(() => _isLoading = true);
    try {
      await context.read<OcorrenciaProvider>().finalizarAtendimentoComLaudo(
            ocorrenciaId: ocorrencia.id,
            laudoTecnico: laudoController.text.trim(),
            pecasTrocadas: pecas,
            usuario: usuario,
          );

      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Laudo emitido! Equipamento liberado com sucesso.',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3. Supervisor: Aprovar Manutenção Crítica e Designar Técnico
  Future<void> _abrirModalAprovarEDesignar(Ocorrencia ocorrencia) async {
    final provider = context.read<OcorrenciaProvider>();
    final tecnicos = provider.tecnicosDisponiveis;
    String? tecnicoIdSelecionado;
    String? tecnicoNomeSelecionado;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.verified_user, color: Colors.teal),
              SizedBox(width: 8),
              Text('Aprovar Manutenção Crítica'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Equipamento: ${ocorrencia.equipamentoTag} — ${ocorrencia.motivo}'),
              const SizedBox(height: 12),
              const Text(
                'Esta é uma parada crítica. Ao aprovar, designe o técnico exclusivo que executará o reparo:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Text('Selecione o Técnico Responsável:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (tecnicos.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Nenhum técnico cadastrado encontrado.', style: TextStyle(color: Colors.red)),
                )
              else
                RadioGroup<String>(
                  groupValue: tecnicoIdSelecionado,
                  onChanged: (v) {
                    setDialogState(() {
                      tecnicoIdSelecionado = v;
                      final tec = tecnicos.firstWhere((t) => t['id'] == v, orElse: () => {});
                      tecnicoNomeSelecionado = tec['nome'];
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: tecnicos.map((tec) => RadioListTile<String>(
                          title: Text(tec['nome']!),
                          subtitle: Text('ID: ${tec['id']}'),
                          value: tec['id']!,
                        )).toList(),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text('Aprovar e Designar', style: TextStyle(color: Colors.white)),
              onPressed: tecnicoIdSelecionado == null
                  ? null
                  : () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );

    if (confirmou != true || tecnicoIdSelecionado == null || tecnicoNomeSelecionado == null) return;
    if (!mounted) return;

    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) return;

    setState(() => _isLoading = true);
    try {
      await provider.aprovarEDesignarTecnico(
        ocorrenciaId: ocorrencia.id,
        tecnicoId: tecnicoIdSelecionado!,
        tecnicoNome: tecnicoNomeSelecionado!,
        usuario: usuario,
      );

      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Manutenção aprovada e designada para $tecnicoNomeSelecionado!',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3. Supervisor: Reatribuir Prioridade
  Future<void> _abrirModalReatribuirPrioridade(Ocorrencia ocorrencia) async {
    String prioridade = ocorrencia.prioridade;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Reatribuir Prioridade da Ocorrência'),
          content: DropdownButtonFormField<String>(
            initialValue: prioridade,
            decoration: const InputDecoration(labelText: 'Nova Prioridade', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'Baixa', child: Text('Baixa')),
              DropdownMenuItem(value: 'Média', child: Text('Média')),
              DropdownMenuItem(value: 'Alta', child: Text('Alta')),
              DropdownMenuItem(value: 'Crítica', child: Text('Crítica')),
            ],
            onChanged: (v) {
              if (v != null) setDialogState(() => prioridade = v);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Atualizar Prioridade'),
            ),
          ],
        ),
      ),
    );

    if (confirmou != true) return;
    if (!mounted) return;

    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) return;

    setState(() => _isLoading = true);
    try {
      await context.read<OcorrenciaProvider>().reatribuirPrioridade(
            ocorrenciaId: ocorrencia.id,
            novaPrioridade: prioridade,
            usuario: usuario,
          );

      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Prioridade alterada para "$prioridade" pelo Supervisor.',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3.1 Supervisor: Contra-assinatura para aprovar retorno de máquinas críticas
  Future<void> _abrirModalContraAssinatura(Ocorrencia ocorrencia) async {
    final parecerController = TextEditingController(text: 'Retorno inspecionado e aprovado para operação.');

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified, color: Colors.purple),
            SizedBox(width: 8),
            Text('Contra-assinatura de Liberação'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta máquina passou por intervenção Crítica e exige validação do Supervisor para voltar a operar.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: parecerController,
              decoration: const InputDecoration(
                labelText: 'Parecer do Supervisor',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Contra-assinar e Liberar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmou != true) return;
    if (!mounted) return;

    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) return;

    setState(() => _isLoading = true);
    try {
      await context.read<OcorrenciaProvider>().contraAssinarRetorno(
            ocorrenciaId: ocorrencia.id,
            parecerSupervisor: parecerController.text.trim(),
            usuario: usuario,
          );

      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Equipamento formalmente contra-assinado e liberado para Operando!',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3.2 Supervisor: Entregar Material ao Técnico
  Future<void> _abrirModalEntregarMaterial(Ocorrencia ocorrencia) async {
    final formKey = GlobalKey<FormState>();
    final descricaoController = TextEditingController();

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.local_shipping, color: Colors.teal),
            SizedBox(width: 8),
            Text('Entregar Material'),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Equipamento: ${ocorrencia.equipamentoTag}'),
                if (ocorrencia.tecnicoResponsavel != null) ...[
                  const SizedBox(height: 4),
                  Text('Técnico: ${ocorrencia.tecnicoResponsavel}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: descricaoController,
                  decoration: const InputDecoration(
                    labelText: 'Materiais / Insumos Entregues',
                    hintText: 'Ex.: 2x Rolamento 6205, 1L Óleo ISO 68...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory),
                  ),
                  maxLines: 3,
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Descreva os materiais entregues'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('Confirmar Entrega', style: TextStyle(color: Colors.white)),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
          ),
        ],
      ),
    );

    if (confirmou != true) return;
    if (!mounted) return;

    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) return;

    setState(() => _isLoading = true);
    try {
      await context.read<OcorrenciaProvider>().entregarMaterial(
            ocorrenciaId: ocorrencia.id,
            descricaoEntrega: descricaoController.text.trim(),
            usuario: usuario,
          );

      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Material entregue! Manutenção retomada automaticamente.',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3.3 Supervisor: Atribuir Manutenção a um Técnico Específico
  Future<void> _abrirModalAtribuirTecnico(Ocorrencia ocorrencia) async {
    final provider = context.read<OcorrenciaProvider>();
    final tecnicos = provider.tecnicosDisponiveis;
    String? tecnicoIdSelecionado;
    String? tecnicoNomeSelecionado;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_pin_circle, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Atribuir a Técnico'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Equipamento: ${ocorrencia.equipamentoTag} — ${ocorrencia.motivo}'),
              if (ocorrencia.tecnicoResponsavel != null) ...[
                const SizedBox(height: 4),
                Text('Técnico atual: ${ocorrencia.tecnicoResponsavel}',
                    style: TextStyle(color: Colors.orange.shade300, fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 16),
              const Text('Selecione o técnico responsável:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: tecnicoIdSelecionado,
                onChanged: (v) {
                  setDialogState(() {
                    tecnicoIdSelecionado = v;
                    final tec = tecnicos.firstWhere((t) => t['id'] == v, orElse: () => {});
                    tecnicoNomeSelecionado = tec['nome'];
                  });
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: tecnicos.map((tec) => RadioListTile<String>(
                        title: Text(tec['nome']!),
                        subtitle: Text('ID: ${tec['id']}'),
                        value: tec['id']!,
                      )).toList(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              icon: const Icon(Icons.assignment_ind, color: Colors.white),
              label: const Text('Atribuir Técnico', style: TextStyle(color: Colors.white)),
              onPressed: tecnicoIdSelecionado == null
                  ? null
                  : () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );

    if (confirmou != true || tecnicoIdSelecionado == null || tecnicoNomeSelecionado == null) return;
    if (!mounted) return;

    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) return;

    setState(() => _isLoading = true);
    try {
      await context.read<OcorrenciaProvider>().atribuirTecnico(
            ocorrenciaId: ocorrencia.id,
            tecnicoId: tecnicoIdSelecionado!,
            tecnicoNome: tecnicoNomeSelecionado!,
            usuario: usuario,
          );

      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Ocorrência atribuída ao técnico $tecnicoNomeSelecionado!',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final ocorrenciaProvider = context.watch<OcorrenciaProvider>();

    final equipamento = ocorrenciaProvider.equipamentosPorId[widget.equipamentoId];

    final ocorrenciasDoEquipamento = ocorrenciaProvider.ocorrencias
        .where((o) => o.equipamentoId == widget.equipamentoId)
        .toList();

    final ocorrenciaAtiva = ocorrenciasDoEquipamento.cast<Ocorrencia?>().firstWhere(
          (o) =>
              o?.status == StatusOcorrencia.aberta ||
              o?.status == StatusOcorrencia.emAndamento ||
              o?.status == StatusOcorrencia.aguardandoMaterial ||
              o?.status == StatusOcorrencia.aguardandoAprovacao,
          orElse: () => null,
        );

    return Scaffold(
      appBar: CustomAppBar(
        title: equipamento?.nome ?? 'Detalhes do Equipamento',
        usuario: authProvider.usuario,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : equipamento == null
              ? const _EmptyState()
              : RefreshIndicator(
                  onRefresh: () async {
                    await ocorrenciaProvider.carregarOcorrencias();
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeaderEquipamento(equipamento: equipamento),
                        const SizedBox(height: 20),
                        _MetricasEquipamento(equipamento: equipamento),
                        const SizedBox(height: 20),

                        // Bloco de Ações RBAC dinâmico
                        _AcoesRBACCard(
                          equipamento: equipamento,
                          ocorrenciaAtiva: ocorrenciaAtiva,
                          onRegistrarParada: () => _abrirModalRegistrarParada(equipamento),
                          onSolicitarAtendimento: ocorrenciaAtiva != null
                              ? () => _solicitarAtendimento(ocorrenciaAtiva)
                              : null,
                          onAssumirManutencao: ocorrenciaAtiva != null
                              ? () => _assumirManutencao(ocorrenciaAtiva)
                              : null,
                          onAprovarEDesignar: ocorrenciaAtiva != null
                              ? () => _abrirModalAprovarEDesignar(ocorrenciaAtiva)
                              : null,
                          onPausarMaterial: ocorrenciaAtiva != null
                              ? () => _abrirModalPausaMaterial(ocorrenciaAtiva)
                              : null,
                          onFinalizarLaudo: ocorrenciaAtiva != null
                              ? () => _abrirModalLaudoFinalizacao(ocorrenciaAtiva)
                              : null,
                          onReatribuirPrioridade: ocorrenciaAtiva != null
                              ? () => _abrirModalReatribuirPrioridade(ocorrenciaAtiva)
                              : null,
                          onContraAssinar: ocorrenciaAtiva != null
                              ? () => _abrirModalContraAssinatura(ocorrenciaAtiva)
                              : null,
                          onEntregarMaterial: ocorrenciaAtiva != null
                              ? () => _abrirModalEntregarMaterial(ocorrenciaAtiva)
                              : null,
                          onAtribuirTecnico: ocorrenciaAtiva != null
                              ? () => _abrirModalAtribuirTecnico(ocorrenciaAtiva)
                              : null,
                        ),

                        const SizedBox(height: 24),
                        _TimelineEquipamento(ocorrencias: ocorrenciasDoEquipamento),
                      ],
                    ),
                  ),
                ),
    );
  }
}

/// Bloco inteligente de ações que respeita o RBAC
class _AcoesRBACCard extends StatelessWidget {
  final Equipamento equipamento;
  final Ocorrencia? ocorrenciaAtiva;
  final VoidCallback onRegistrarParada;
  final VoidCallback? onSolicitarAtendimento;
  final VoidCallback? onAssumirManutencao;
  final VoidCallback? onAprovarEDesignar;
  final VoidCallback? onPausarMaterial;
  final VoidCallback? onFinalizarLaudo;
  final VoidCallback? onReatribuirPrioridade;
  final VoidCallback? onContraAssinar;
  final VoidCallback? onEntregarMaterial;
  final VoidCallback? onAtribuirTecnico;

  const _AcoesRBACCard({
    required this.equipamento,
    required this.ocorrenciaAtiva,
    required this.onRegistrarParada,
    this.onSolicitarAtendimento,
    this.onAssumirManutencao,
    this.onAprovarEDesignar,
    this.onPausarMaterial,
    this.onFinalizarLaudo,
    this.onReatribuirPrioridade,
    this.onContraAssinar,
    this.onEntregarMaterial,
    this.onAtribuirTecnico,
  });

  @override
  Widget build(BuildContext context) {
    final status = equipamento.status;
    final usuario = context.watch<AuthProvider>().usuario;
    final perfil = usuario?.perfil;
    final oc = ocorrenciaAtiva;

    final ehCritica = (oc != null && oc.ehCritica) || equipamento.grauCritico;
    final estaAprovada = (oc?.aprovadaManutencao == true) || (equipamento.aprovadaManutencao == true);
    final precisaAprovacao = ehCritica && !estaAprovada;

    final tecDesignadoId = oc?.tecnicoDesignadoId ?? equipamento.tecnicoDesignadoId;
    final tecDesignadoNome = oc?.tecnicoDesignado ?? equipamento.tecnicoDesignado;
    final temTecnicoDesignado = (tecDesignadoId != null && tecDesignadoId.trim().isNotEmpty) ||
        (tecDesignadoNome != null && tecDesignadoNome.trim().isNotEmpty);
    final souTecnicoDesignado = usuario != null &&
        ((tecDesignadoId != null && usuario.id == tecDesignadoId) ||
         (tecDesignadoNome != null &&
          usuario.nome.trim().toLowerCase() == tecDesignadoNome.trim().toLowerCase()));

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, size: 20, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text(
                  'Ações Operacionais Permitidas',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Gestor: Informação de acesso executivo
            if (perfil == PerfilUsuario.gestor) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueGrey.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: Colors.teal, size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Perfil Gestor Industrial: Modo executivo. Você possui acesso irrestrito ao Gerenciamento de Máquinas e Relatórios & KPIs.',
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 1. Operador
            if (perfil == PerfilUsuario.operador) ...[
              if (status == StatusEquipamento.operando)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.warning, color: Colors.white),
                  label: const Text('Registrar Parada de Máquina', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: onRegistrarParada,
                )
              else if (oc != null)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 3,
                  ),
                  icon: const Icon(Icons.notification_important, color: Colors.white),
                  label: const Text(
                    'Solicitar Atendimento de Manutenção (Avisar Equipe)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onPressed: onSolicitarAtendimento,
                ),
            ],

            // 2. Supervisor (Exatamente 3 botões conforme regra de negócio)
            if (perfil == PerfilUsuario.supervisor) ...[
              if (oc != null) ...[
                // Botão 1: Aprovar Manutenção & Designar Técnico
                // REGRA: Supervisor só pode designar técnicos em casos de paradas críticas!
                Builder(
                  builder: (context) {
                    final podeDesignar = oc.ehCritica;
                    return ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: podeDesignar ? Colors.teal.shade700 : null,
                        disabledBackgroundColor: Colors.grey.withValues(alpha: 0.15),
                        disabledForegroundColor: Colors.white38,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: Icon(
                        podeDesignar ? Icons.verified_user : Icons.lock_outline,
                        color: podeDesignar ? Colors.white : Colors.white38,
                      ),
                      label: Text(
                        podeDesignar
                            ? (oc.tecnicoDesignado != null
                                ? 'Aprovar Manutenção & Designar Técnico (${oc.tecnicoDesignado})'
                                : 'Aprovar Manutenção & Designar Técnico')
                            : 'Designação Restrita a Paradas Críticas (Livre p/ Técnicos)',
                        style: TextStyle(
                          color: podeDesignar ? Colors.white : Colors.white38,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: podeDesignar ? onAprovarEDesignar : null,
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Botão 2: Entregar Materiais (Inicialmente bloqueado; só desbloqueia se um técnico pedir por flag no DB)
                Builder(
                  builder: (context) {
                    final solicitouMaterial = oc.solicitouMaterial ||
                        equipamento.solicitouMaterial ||
                        oc.status == StatusOcorrencia.aguardandoMaterial ||
                        status == StatusEquipamento.aguardandoMaterial;

                    final temTecnicoAtrelado = oc.tecnicoDesignado != null ||
                        oc.tecnicoResponsavel != null ||
                        equipamento.tecnicoDesignado != null;

                    final podeEntregar = solicitouMaterial && temTecnicoAtrelado;

                    return ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        disabledBackgroundColor: Colors.grey.withValues(alpha: 0.15),
                        disabledForegroundColor: Colors.white38,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: Icon(
                        podeEntregar ? Icons.local_shipping : Icons.lock,
                        color: podeEntregar ? Colors.white : Colors.white38,
                      ),
                      label: Text(
                        podeEntregar
                            ? 'Entregar Material ao Técnico'
                            : 'Entregar Materiais (Bloqueado — Aguardando Pedido do Técnico)',
                        style: TextStyle(
                          color: podeEntregar ? Colors.white : Colors.white38,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: podeEntregar ? onEntregarMaterial : null,
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Botão 3: Reatribuir Prioridade
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  icon: const Icon(Icons.low_priority),
                  label: Text('Reatribuir Prioridade (Atual: ${oc.prioridade})'),
                  onPressed: onReatribuirPrioridade,
                ),
              ],
            ],

            // 3. Técnico
            if (perfil == PerfilUsuario.tecnico) ...[
              // Caso A: Parada Crítica Aguardando Aprovação
              if (precisaAprovacao) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade700),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_clock, color: Colors.amber, size: 24),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Parada Crítica — Aguardando Aprovação e Designação pelo Supervisor. O atendimento só pode ser iniciado após a validação da supervisão.',
                          style: TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ]
              // Caso Intermediário: Pausada por Falta de Materiais (Bloqueia o Técnico até entrega do Supervisor)
              else if (status == StatusEquipamento.aguardandoMaterial) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade700, width: 1.5),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, color: Colors.amber, size: 24),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Manutenção Pausada por Falta de Materiais — O técnico não pode retomar o atendimento até que o Supervisor realize a entrega dos materiais solicitados.',
                          style: TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ]
              // Caso B: Parada Crítica Aprovada
              else if (ehCritica && estaAprovada) ...[
                if (status == StatusEquipamento.parada ||
                    status == StatusEquipamento.aguardandoAprovacao) ...[
                  if (souTecnicoDesignado)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.play_arrow, color: Colors.white),
                      label: Text(
                        'Iniciar Atendimento Designado ($tecDesignadoNome)',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      onPressed: onAssumirManutencao,
                    )
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        disabledBackgroundColor: Colors.grey.withValues(alpha: 0.15),
                        disabledForegroundColor: Colors.white54,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.lock, size: 18, color: Colors.white54),
                      label: Text(
                        'Bloqueado: Designado a $tecDesignadoNome',
                        style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                      ),
                      onPressed: null, // Bloqueado: Outro técnico não pode assumir
                    ),
                ],
              ]
              // Caso C: Parada Não-Crítica (Baixa, Média, Alta)
              else if (!ehCritica &&
                  status == StatusEquipamento.parada &&
                  oc != null) ...[
                if (temTecnicoDesignado && !souTecnicoDesignado)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      disabledBackgroundColor: Colors.grey.withValues(alpha: 0.15),
                      disabledForegroundColor: Colors.white54,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.lock, size: 18, color: Colors.white54),
                    label: Text(
                      'Bloqueado: Designado a $tecDesignadoNome',
                      style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                    ),
                    onPressed: null, // Bloqueado: Outro técnico não pode assumir
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: temTecnicoDesignado ? Colors.teal.shade700 : Colors.orange.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: Icon(temTecnicoDesignado ? Icons.play_arrow : Icons.build, color: Colors.white),
                    label: Text(
                      temTecnicoDesignado
                          ? 'Assumir Manutenção (Designado a Você)'
                          : 'Assumir Manutenção',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    onPressed: onAssumirManutencao,
                  ),
              ],

              // Se já estiver em manutenção (Técnico trabalhando)
              if (status == StatusEquipamento.manutencao && oc != null) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.inventory_2_outlined, color: Colors.amber),
                  label: const Text('Pausar: Aguardando Material'),
                  onPressed: onPausarMaterial,
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.assignment_turned_in, color: Colors.white),
                  label: const Text('Preencher Laudo & Finalizar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: onFinalizarLaudo,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Header com gradiente e informações principais
class _HeaderEquipamento extends StatelessWidget {
  final Equipamento equipamento;

  const _HeaderEquipamento({required this.equipamento});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(equipamento.statusIcon, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      equipamento.nome,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      equipamento.tag,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                status: equipamento.status,
                equipamento: equipamento,
                size: 20,
              ),
            ],
          ),
          if (equipamento.tecnicoDesignado != null && equipamento.status != StatusEquipamento.operando) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.shade900.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.tealAccent.shade400, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.assignment_ind, size: 14, color: Colors.tealAccent),
                  const SizedBox(width: 6),
                  Text(
                    'Técnico Designado: ${equipamento.tecnicoDesignado}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.tealAccent),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoLabel(icone: Icons.location_on, label: equipamento.localizacao),
              const SizedBox(width: 16),
              _InfoLabel(icone: Icons.access_time, label: 'Atualizado: ${equipamento.formatoUltimaAtualizacao}'),
            ],
          ),
          if (equipamento.motivoParada != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Motivo: ${equipamento.motivoParada}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoLabel extends StatelessWidget {
  final IconData icone;
  final String label;

  const _InfoLabel({required this.icone, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, size: 14, color: Colors.white.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
      ],
    );
  }
}

class _MetricasEquipamento extends StatelessWidget {
  final Equipamento equipamento;

  const _MetricasEquipamento({required this.equipamento});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icone: Icons.timer,
            valor: Helpers.formatDuration(equipamento.tempoOperacaoTotal.toInt()),
            label: 'Operação',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icone: Icons.stop_circle_outlined,
            valor: '${equipamento.numeroParadas}',
            label: 'Paradas',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icone: Icons.access_time,
            valor: equipamento.formatoTempoParado,
            label: 'T. Parado',
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icone;
  final String valor;
  final String label;

  const _MetricCard({
    required this.icone,
    required this.valor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Icon(icone, size: 26, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            valor,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEquipamento extends StatelessWidget {
  final List<Ocorrencia> ocorrencias;

  const _TimelineEquipamento({required this.ocorrencias});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Histórico de Ocorrências e Laudos',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (ocorrencias.isEmpty)
          const Text('Nenhuma ocorrência registrada para esta máquina.')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ocorrencias.length,
            itemBuilder: (context, index) {
              final oc = ocorrencias[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(oc.prioridadeIcon, size: 16, color: oc.prioridadeColor),
                              const SizedBox(width: 6),
                              Text(oc.motivo, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Text(
                            oc.status.nome,
                            style: TextStyle(
                              color: oc.status == StatusOcorrencia.finalizada
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(oc.descricao, style: const TextStyle(fontSize: 13)),
                      if (oc.observacaoFinal != null && oc.observacaoFinal!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'Laudo Técnico: ${oc.observacaoFinal}',
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Equipamento não localizado.'));
  }
}
