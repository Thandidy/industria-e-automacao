// lib/views/gerenciamento_maquinas_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/equipamento.dart';
import '../providers/auth_provider.dart';
import '../providers/equipamento_provider.dart';
import '../utils/constants.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/status_badge.dart';

/// Tela EXCLUSIVA do Gestor Industrial para CRUD de equipamentos.
/// Usuários Operadores e Técnicos são bloqueados pelo RouteGuard.
class GerenciamentoMaquinasView extends StatefulWidget {
  const GerenciamentoMaquinasView({super.key});

  @override
  State<GerenciamentoMaquinasView> createState() => _GerenciamentoMaquinasViewState();
}

class _GerenciamentoMaquinasViewState extends State<GerenciamentoMaquinasView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  StatusEquipamento? _selectedStatusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _abrirModalCadastro(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final tagController = TextEditingController();
    final nomeController = TextEditingController();
    final localizacaoController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Cadastrar Nova Máquina'),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: tagController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'TAG do Ativo',
                    hintText: 'Ex.: CNC-09, PR-05',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe a TAG do equipamento'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Máquina',
                    hintText: 'Ex.: Torno Mecânico CNC 5 Eixos',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.precision_manufacturing),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe o nome da máquina'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: localizacaoController,
                  decoration: const InputDecoration(
                    labelText: 'Setor / Localização',
                    hintText: 'Ex.: Linha 03 - Pavilhão A',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe a localização'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;

              final auth = context.read<AuthProvider>();
              final usuario = auth.usuario;
              if (usuario == null) return;

              final novoEquipamento = Equipamento(
                id: 'eq-${DateTime.now().millisecondsSinceEpoch}',
                tag: tagController.text.trim().toUpperCase(),
                nome: nomeController.text.trim(),
                localizacao: localizacaoController.text.trim(),
                status: StatusEquipamento.operando,
                ultimoAtualizacao: DateTime.now(),
              );

              try {
                context
                    .read<EquipamentoProvider>()
                    .adicionarEquipamento(novoEquipamento, usuario);

                Navigator.of(ctx).pop();
                SnackbarHelper.showSnackbar(
                  context: context,
                  message: 'Máquina ${novoEquipamento.tag} cadastrada com sucesso!',
                  isSuccess: true,
                );
              } catch (e) {
                SnackbarHelper.showSnackbar(
                  context: context,
                  message: e.toString().replaceFirst('Exception: ', ''),
                  isError: true,
                );
              }
            },
            child: const Text('Cadastrar'),
          ),
        ],
      ),
    );
  }

  void _abrirModalEdicao(BuildContext context, Equipamento eq) {
    final formKey = GlobalKey<FormState>();
    final tagController = TextEditingController(text: eq.tag);
    final nomeController = TextEditingController(text: eq.nome);
    final localizacaoController = TextEditingController(text: eq.localizacao);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.teal),
            SizedBox(width: 8),
            Text('Editar Máquina'),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: tagController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Código / TAG do Ativo',
                    hintText: 'Ex.: CNC-09, PR-05',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe o código/TAG da máquina'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Máquina',
                    hintText: 'Ex.: Torno Mecânico CNC 5 Eixos',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.precision_manufacturing),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe o nome da máquina'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: localizacaoController,
                  decoration: const InputDecoration(
                    labelText: 'Setor / Localização',
                    hintText: 'Ex.: Linha 03 - Pavilhão A',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe a localização'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            icon: const Icon(Icons.save, color: Colors.white, size: 18),
            label: const Text('Salvar Alterações', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final auth = context.read<AuthProvider>();
              final usuario = auth.usuario;
              if (usuario == null) return;

              try {
                await context.read<EquipamentoProvider>().editarEquipamento(
                      id: eq.id,
                      tag: tagController.text,
                      nome: nomeController.text,
                      localizacao: localizacaoController.text,
                      usuario: usuario,
                    );

                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                if (!context.mounted) return;
                SnackbarHelper.showSnackbar(
                  context: context,
                  message: 'Máquina ${tagController.text.toUpperCase()} atualizada com sucesso!',
                  isSuccess: true,
                );
              } catch (e) {
                if (!context.mounted) return;
                SnackbarHelper.showSnackbar(
                  context: context,
                  message: e.toString().replaceFirst('Exception: ', ''),
                  isError: true,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmarRemocao(BuildContext context, Equipamento eq) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Remover Equipamento'),
          ],
        ),
        content: Text(
          'Tem certeza que deseja remover definitivamente a máquina ${eq.tag} (${eq.nome}) do parque industrial? Esta ação é irreversível.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final auth = context.read<AuthProvider>();
              final usuario = auth.usuario;
              if (usuario == null) return;

              try {
                context
                    .read<EquipamentoProvider>()
                    .removerEquipamento(eq.id, usuario);

                Navigator.of(ctx).pop();
                SnackbarHelper.showSnackbar(
                  context: context,
                  message: 'Máquina ${eq.tag} removida com sucesso.',
                  isWarning: true,
                );
              } catch (e) {
                SnackbarHelper.showSnackbar(
                  context: context,
                  message: e.toString().replaceFirst('Exception: ', ''),
                  isError: true,
                );
              }
            },
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final eqProvider = context.watch<EquipamentoProvider>();

    final maquinas = eqProvider.equipamentos.where((e) {
      if (_selectedStatusFilter != null && e.status != _selectedStatusFilter) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return e.tag.toLowerCase().contains(q) ||
          e.nome.toLowerCase().contains(q) ||
          e.localizacao.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Gerenciamento de Máquinas',
        usuario: auth.usuario,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Filtrar por TAG, nome ou setor...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: _selectedStatusFilter == null,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedStatusFilter = null);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.pending_actions, size: 16, color: Colors.orangeAccent),
                    label: const Text('Aguardando Aprovação'),
                    selected: _selectedStatusFilter == StatusEquipamento.aguardandoAprovacao,
                    onSelected: (selected) {
                      setState(() => _selectedStatusFilter = selected ? StatusEquipamento.aguardandoAprovacao : null);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.check_circle, size: 16, color: Colors.green),
                    label: const Text('Operando'),
                    selected: _selectedStatusFilter == StatusEquipamento.operando,
                    onSelected: (selected) {
                      setState(() => _selectedStatusFilter = selected ? StatusEquipamento.operando : null);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.stop_circle, size: 16, color: Colors.red),
                    label: const Text('Parada'),
                    selected: _selectedStatusFilter == StatusEquipamento.parada,
                    onSelected: (selected) {
                      setState(() => _selectedStatusFilter = selected ? StatusEquipamento.parada : null);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.build, size: 16, color: Colors.blue),
                    label: const Text('Manutenção'),
                    selected: _selectedStatusFilter == StatusEquipamento.manutencao,
                    onSelected: (selected) {
                      setState(() => _selectedStatusFilter = selected ? StatusEquipamento.manutencao : null);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.inventory_2, size: 16, color: Colors.amber),
                    label: const Text('Aguardando Material'),
                    selected: _selectedStatusFilter == StatusEquipamento.aguardandoMaterial,
                    onSelected: (selected) {
                      setState(() => _selectedStatusFilter = selected ? StatusEquipamento.aguardandoMaterial : null);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: maquinas.isEmpty
                ? const Center(child: Text('Nenhum equipamento cadastrado.'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: maquinas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final eq = maquinas[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: eq.statusColor.withValues(alpha: 0.2),
                            child: Icon(eq.statusIcon, color: eq.statusColor),
                          ),
                          title: Text(
                            '${eq.tag} - ${eq.nome}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Localização: ${eq.localizacao} | Status: ${eq.statusNome}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatusBadge(status: eq.status, equipamento: eq),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.teal),
                                tooltip: 'Editar Máquina',
                                onPressed: () => _abrirModalEdicao(context, eq),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Remover Máquina',
                                onPressed: () => _confirmarRemocao(context, eq),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirModalCadastro(context),
        icon: const Icon(Icons.add),
        label: const Text('Nova Máquina'),
      ),
    );
  }
}

