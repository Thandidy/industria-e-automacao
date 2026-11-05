// lib/views/painel_supervisor_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ocorrencia.dart';
import '../models/usuario.dart';
import '../providers/auth_provider.dart';
import '../providers/ocorrencia_provider.dart';
import '../utils/constants.dart';
import '../widgets/snackbar_helper.dart';

/// Painel Operacional Exclusivo do Supervisor
/// Possui abas dedicadas para:
/// 1. "Aguardando Material" - Realizar a entrega de materiais aos técnicos.
/// 2. "Atribuir Técnicos" - Direcionar ou reatribuir ocorrências a técnicos específicos.
class PainelSupervisorView extends StatefulWidget {
  const PainelSupervisorView({super.key});

  @override
  State<PainelSupervisorView> createState() => _PainelSupervisorViewState();
}

class _PainelSupervisorViewState extends State<PainelSupervisorView> {
  bool _isLoading = false;

  Future<void> _abrirModalEntregarMaterial(BuildContext context, Ocorrencia ocorrencia) async {
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
                Text(
                  'Equipamento: ${ocorrencia.equipamentoTag}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Motivo: ${ocorrencia.motivo}'),
                if (ocorrencia.tecnicoResponsavel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Técnico aguardando: ${ocorrencia.tecnicoResponsavel}',
                    style: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: descricaoController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição dos Materiais Entregues',
                    hintText: 'Ex.: 2x Rolamentos, Correia 1200mm...',
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
        message: 'Material entregue com sucesso! Manutenção em andamento.',
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

  Future<void> _abrirModalAtribuirTecnico(BuildContext context, Ocorrencia ocorrencia) async {
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
              Text('Atribuir Técnico'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Equipamento: ${ocorrencia.equipamentoTag} (${ocorrencia.motivo})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (ocorrencia.tecnicoResponsavel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Técnico atual: ${ocorrencia.tecnicoResponsavel}',
                    style: TextStyle(color: Colors.orange.shade700, fontStyle: FontStyle.italic),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Selecione o técnico para este chamado:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...tecnicos.map((tec) => RadioListTile<String>(
                      title: Text(tec['nome']!),
                      subtitle: Text('ID: ${tec['id']}'),
                      value: tec['id']!,
                      groupValue: tecnicoIdSelecionado,
                      onChanged: (v) {
                        setDialogState(() {
                          tecnicoIdSelecionado = v;
                          tecnicoNomeSelecionado = tec['nome'];
                        });
                      },
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              icon: const Icon(Icons.assignment_ind, color: Colors.white),
              label: const Text('Atribuir', style: TextStyle(color: Colors.white)),
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
        message: 'Ocorrência atribuída com sucesso a $tecnicoNomeSelecionado!',
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

    // 1. Ocorrências aguardando material
    final ocorrenciasAguardandoMaterial = todasOcorrencias
        .where((o) => o.status == StatusOcorrencia.aguardandoMaterial)
        .toList();

    // 2. Ocorrências ativas elegíveis para atribuição de técnico (não finalizadas)
    final ocorrenciasParaAtribuicao = todasOcorrencias
        .where((o) => o.status != StatusOcorrencia.finalizada)
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.supervisor_account, color: Colors.white),
              SizedBox(width: 8),
              Text('Painel do Supervisor'),
            ],
          ),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.local_shipping),
                text: 'Aguardando Material (${ocorrenciasAguardandoMaterial.length})',
              ),
              Tab(
                icon: const Icon(Icons.assignment_ind),
                text: 'Atribuir Técnicos (${ocorrenciasParaAtribuicao.length})',
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Aba 1: Entregar Materiais
                  _buildAbaMateriais(context, ocorrenciasAguardandoMaterial),

                  // Aba 2: Atribuir Técnicos
                  _buildAbaAtribuicao(context, ocorrenciasParaAtribuicao),
                ],
              ),
      ),
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
              style: TextStyle(color: Colors.grey.shade600),
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
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.teal.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(
                      label: Text(
                        oc.equipamentoTag,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.teal.shade50,
                    ),
                    Chip(
                      label: Text(oc.prioridade),
                      backgroundColor: oc.prioridade == 'Crítica'
                          ? Colors.red.shade100
                          : Colors.orange.shade100,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  oc.motivo,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (oc.tecnicoResponsavel != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.build_circle, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('Técnico Responsável: ${oc.tecnicoResponsavel}'),
                    ],
                  ),
                ],
                const Divider(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    icon: const Icon(Icons.local_shipping, color: Colors.white),
                    label: const Text(
                      'Entregar Material',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () => _abrirModalEntregarMaterial(context, oc),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAbaAtribuicao(BuildContext context, List<Ocorrencia> lista) {
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in, size: 64, color: Colors.indigo.shade300),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma ocorrência pendente.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
        final temTecnico = oc.tecnicoResponsavel != null && oc.tecnicoResponsavel!.isNotEmpty;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: temTecnico ? Colors.grey.shade300 : Colors.orange.shade300,
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
                        Chip(
                          label: Text(
                            oc.equipamentoTag,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(oc.status.nome),
                          backgroundColor: oc.status.cor.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: oc.status.cor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Chip(
                      label: Text(oc.prioridade),
                      backgroundColor: oc.prioridade == 'Crítica'
                          ? Colors.red.shade100
                          : Colors.orange.shade100,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  oc.motivo,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      temTecnico ? Icons.check_circle : Icons.warning_amber_rounded,
                      size: 16,
                      color: temTecnico ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      temTecnico
                          ? 'Técnico Responsável: ${oc.tecnicoResponsavel}'
                          : 'Nenhum técnico atribuído ainda',
                      style: TextStyle(
                        fontWeight: temTecnico ? FontWeight.normal : FontWeight.bold,
                        color: temTecnico ? null : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: temTecnico ? Colors.indigo.shade600 : Colors.indigo,
                    ),
                    icon: const Icon(Icons.assignment_ind, color: Colors.white),
                    label: Text(
                      temTecnico ? 'Reatribuir Técnico' : 'Atribuir Técnico',
                      style: const TextStyle(color: Colors.white),
                    ),
                    onPressed: () => _abrirModalAtribuirTecnico(context, oc),
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

