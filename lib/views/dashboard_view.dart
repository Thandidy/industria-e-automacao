// lib/views/dashboard_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/equipamento.dart';
import '../utils/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/equipamento_provider.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/equipamento_card.dart';
import '../widgets/search_filter_bar.dart';
import 'equipamento_detalhe_view.dart';
import 'painel_tecnico_view.dart';
import 'relatorios_view.dart';

/// Tela principal do aplicativo - Dashboard com listagem e status de equipamentos.
class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<String> _selectedStatuses = ['TODOS'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Equipamento> _filtrarEquipamentos(List<Equipamento> equipamentos) {
    return equipamentos.where((eq) {
      final matchesSearch = _searchQuery.isEmpty ||
          eq.nome.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          eq.tag.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          eq.localizacao.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _selectedStatuses.contains('TODOS') ||
          _selectedStatuses.contains(eq.status.name);

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final equipamentoProvider = context.watch<EquipamentoProvider>();

    if (!authProvider.autenticado) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Faça login para acessar o sistema'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                child: const Text('Ir para Login'),
              ),
            ],
          ),
        ),
      );
    }

    final podeRegistrarParada = authProvider.perfil == PerfilUsuario.operador ||
        authProvider.perfil == PerfilUsuario.gestor;

    final equipamentosFiltrados = _filtrarEquipamentos(equipamentoProvider.equipamentos);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Dashboard Operacional',
        usuario: authProvider.usuario,
        leading: IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Sair',
          onPressed: () {
            context.read<AuthProvider>().logout();
            Navigator.of(context).pushReplacementNamed('/login');
          },
        ),
        actions: [
          if (authProvider.perfil == PerfilUsuario.tecnico ||
              authProvider.perfil == PerfilUsuario.gestor)
            IconButton(
              icon: const Icon(Icons.build_circle_outlined),
              tooltip: 'Painel Técnico',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PainelTecnicoView()),
                );
              },
            ),
          if (authProvider.perfil == PerfilUsuario.supervisor ||
              authProvider.perfil == PerfilUsuario.gestor)
            IconButton(
              icon: const Icon(Icons.analytics_outlined),
              tooltip: 'Relatórios & KPIs',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RelatoriosView()),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          SearchFilterBar(
            searchController: _searchController,
            onSearchChanged: (query) {
              setState(() {
                _searchQuery = query;
              });
            },
            statusFilters: _selectedStatuses,
            onStatusFiltersChanged: (statuses) {
              setState(() {
                _selectedStatuses = statuses;
              });
            },
          ),

          // Resumo executivo de métricas rápidas
          if (equipamentoProvider.equipamentos.isNotEmpty) ...[
            _ResumoExecutive(
              equipamentos: equipamentoProvider.equipamentos,
              statusCounts: equipamentoProvider.statusCounts,
            ),
          ],

          // Lista de equipamentos
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await equipamentoProvider.carregarEquipamentos();
              },
              child: equipamentoProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : equipamentosFiltrados.isEmpty
                      ? const _EmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: equipamentosFiltrados.length,
                          itemBuilder: (context, index) {
                            final equipamento = equipamentosFiltrados[index];
                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => EquipamentoDetalheView(
                                      equipamentoId: equipamento.id,
                                    ),
                                  ),
                                );
                              },
                              child: EquipamentoCard(
                                equipamento: equipamento,
                                showActions: true,
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: podeRegistrarParada
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).pushNamed('/registro-parada');
              },
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('Registrar Parada'),
            )
          : null,
    );
  }
}

/// Linha de indicadores rápidos (KPIs de status dos equipamentos).
class _ResumoExecutive extends StatelessWidget {
  final List<Equipamento> equipamentos;
  final Map<StatusEquipamento, int> statusCounts;

  const _ResumoExecutive({
    required this.equipamentos,
    required this.statusCounts,
  });

  @override
  Widget build(BuildContext context) {
    final total = equipamentos.length;
    final operando = statusCounts[StatusEquipamento.operando] ?? 0;
    final paradas = statusCounts[StatusEquipamento.parada] ?? 0;
    final manutencao = statusCounts[StatusEquipamento.manutencao] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _ResumoCard(
            label: 'Total',
            valor: total.toString(),
            cor: Colors.blueGrey,
            icone: Icons.devices,
          ),
          const SizedBox(width: 8),
          _ResumoCard(
            label: 'Operando',
            valor: operando.toString(),
            cor: AppCores.operando,
            icone: Icons.check_circle,
          ),
          const SizedBox(width: 8),
          _ResumoCard(
            label: 'Paradas',
            valor: paradas.toString(),
            cor: AppCores.parada,
            icone: Icons.error,
          ),
          const SizedBox(width: 8),
          _ResumoCard(
            label: 'Manutenção',
            valor: manutencao.toString(),
            cor: AppCores.manutencao,
            icone: Icons.build,
          ),
        ],
      ),
    );
  }
}

class _ResumoCard extends StatelessWidget {
  final String label;
  final String valor;
  final Color cor;
  final IconData icone;

  const _ResumoCard({
    required this.label,
    required this.valor,
    required this.cor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, size: 16, color: cor),
                const SizedBox(width: 4),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum equipamento encontrado',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tente ajustar seus termos de busca ou filtros.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
