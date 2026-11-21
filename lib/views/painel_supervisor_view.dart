// lib/views/painel_supervisor_view.dart

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../models/ocorrencia.dart';
import '../providers/auth_provider.dart';
import '../providers/ocorrencia_provider.dart';
import '../utils/constants.dart';
import '../widgets/snackbar_helper.dart';

/// Painel Operacional Exclusivo do Supervisor
/// Abas dedicadas:
/// 1. "Aprovações Críticas & Designação" - Aprovar manutenções de grau crítico e designar técnico exclusivo.
/// 2. "Suprimento de Materiais" - Entregar insumos e peças para técnicos continuarem o reparo.
class PainelSupervisorView extends StatefulWidget {
  const PainelSupervisorView({super.key});

  @override
  State<PainelSupervisorView> createState() => _PainelSupervisorViewState();
}

class _PainelSupervisorViewState extends State<PainelSupervisorView> {
  bool _isLoading = false;

  Future<void> _abrirModalAprovarEDesignar(Ocorrencia ocorrencia) async {
    final provider = context.read<OcorrenciaProvider>();
    final tecnicos = provider.tecnicosDisponiveis;
    String? tecnicoIdSelecionado = ocorrencia.tecnicoDesignadoId;
    String? tecnicoNomeSelecionado = ocorrencia.tecnicoDesignado;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assignment_ind, color: Colors.purpleAccent),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Aprovar & Designar Técnico', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Equipamento: ${ocorrencia.equipamentoTag}\nMotivo: ${ocorrencia.motivo}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Selecione o técnico exclusivo que será autorizado a iniciar o conserto:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                if (tecnicos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Nenhum técnico cadastrado na coleção de usuários.', style: TextStyle(color: Colors.grey)),
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
                            title: Text(tec['nome']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('ID: ${tec['id']}'),
                            value: tec['id']!,
                          )).toList(),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent.shade700),
              icon: const Icon(Icons.verified, color: Colors.white),
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
      await context.read<OcorrenciaProvider>().aprovarEDesignarTecnico(
            ocorrenciaId: ocorrencia.id,
            tecnicoId: tecnicoIdSelecionado!,
            tecnicoNome: tecnicoNomeSelecionado!,
            usuario: usuario,
          );

      if (!mounted) return;
      SnackbarHelper.showSnackbar(
        context: context,
        message: 'Manutenção aprovada com sucesso! Técnico designado: $tecnicoNomeSelecionado.',
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

  Future<void> _abrirModalEntregarMaterial(Ocorrencia ocorrencia) async {
    final formKey = GlobalKey<FormState>();
    final descricaoController = TextEditingController();

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                Text(
                  'Equipamento: ${ocorrencia.equipamentoTag}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Motivo: ${ocorrencia.motivo}'),
                if (ocorrencia.tecnicoResponsavel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Técnico aguardando: ${ocorrencia.tecnicoResponsavel}',
                    style: TextStyle(color: Colors.teal.shade300, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: descricaoController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição dos Materiais Entregues',
                    hintText: 'Ex.: Rolamento 6205, Correia trapezoidal 1200mm...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory_2),
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
        message: 'Material entregue com sucesso! Manutenção liberada.',
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
    final ocorrenciaProvider = context.watch<OcorrenciaProvider>();
    final todasOcorrencias = ocorrenciaProvider.ocorrencias;

    // 1. Ocorrências críticas pendentes de aprovação ou designação
    final ocorrenciasCriticasPendentes = todasOcorrencias
        .where((o) => o.ehCritica && o.status != StatusOcorrencia.finalizada)
        .toList();

    // 2. Ocorrências aguardando material
    final ocorrenciasAguardandoMaterial = todasOcorrencias
        .where((o) => o.status == StatusOcorrencia.aguardandoMaterial)
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.supervisor_account, color: Colors.white),
              SizedBox(width: 10),
              Text('Painel do Supervisor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.analytics_outlined, color: Colors.white),
              tooltip: 'Ir para Relatórios & KPIs',
              onPressed: () => Navigator.of(context).pushNamed('/relatorios'),
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3.5,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.75),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: [
              Tab(
                icon: const Icon(Icons.gavel, size: 22),
                text: 'Aprovações Críticas (${ocorrenciasCriticasPendentes.length})',
              ),
              Tab(
                icon: const Icon(Icons.local_shipping, size: 22),
                text: 'Suprir Materiais (${ocorrenciasAguardandoMaterial.length})',
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildAbaAprovacoes(context, ocorrenciasCriticasPendentes),
                  _buildAbaMateriais(context, ocorrenciasAguardandoMaterial),
                ],
              ),
      ),
    );
  }

  Widget _buildAbaAprovacoes(BuildContext context, List<Ocorrencia> lista) {
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user_outlined, size: 64, color: Colors.purple.shade200),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma parada crítica pendente de aprovação.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Paradas não-críticas são atendidas livremente pelos técnicos.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lista.length,
      itemBuilder: (ctx, index) {
        final oc = lista[index];
        final precisaAprovacao = oc.precisaAprovacao;

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: precisaAprovacao ? Colors.purpleAccent.shade400 : Colors.teal.shade300,
              width: 1.5,
            ),
          ),
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
                        Icon(
                          precisaAprovacao ? Icons.pending_actions : Icons.verified,
                          color: precisaAprovacao ? Colors.purpleAccent : Colors.tealAccent,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          oc.equipamentoTag,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.redAccent),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error, size: 14, color: Colors.redAccent),
                          SizedBox(width: 4),
                          Text('Grau Crítico', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  oc.motivo,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  oc.descricao,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          precisaAprovacao ? 'Status: Aguardando Aprovação' : 'Status: Aprovado p/ Manutenção',
                          style: TextStyle(
                            color: precisaAprovacao ? Colors.purpleAccent : Colors.tealAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (oc.tecnicoDesignado != null)
                          Text(
                            'Técnico Designado: ${oc.tecnicoDesignado}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                          ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: precisaAprovacao ? Colors.purpleAccent.shade700 : Colors.indigo,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      icon: Icon(precisaAprovacao ? Icons.gavel : Icons.edit, size: 16, color: Colors.white),
                      label: Text(
                        precisaAprovacao ? 'Aprovar & Designar' : 'Reatribuir Técnico',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      onPressed: () => _abrirModalAprovarEDesignar(oc),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAbaMateriais(BuildContext context, List<Ocorrencia> lista) {
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.teal.shade300),
            const SizedBox(height: 16),
            const Text(
              'Nenhum chamado aguardando material.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Todas as solicitações de peças e insumos foram atendidas.',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lista.length,
      itemBuilder: (ctx, index) {
        final oc = lista[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.teal.shade400),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      oc.equipamentoTag,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2, size: 14, color: Colors.amber),
                          SizedBox(width: 4),
                          Text('Aguardando Peças', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  oc.motivo,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                if (oc.tecnicoResponsavel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Técnico solicitante: ${oc.tecnicoResponsavel}',
                    style: TextStyle(color: Colors.teal.shade300, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    icon: const Icon(Icons.local_shipping, size: 16, color: Colors.white),
                    label: const Text('Entregar Material', style: TextStyle(color: Colors.white)),
                    onPressed: () => _abrirModalEntregarMaterial(oc),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
