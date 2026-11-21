// lib/views/dashboard_view.dart

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../models/equipamento.dart';
import '../models/usuario.dart';
import '../utils/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/equipamento_provider.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/equipamento_card.dart';
import '../widgets/permission_guard.dart';
import '../widgets/search_filter_bar.dart';
import 'equipamento_detalhe_view.dart';

/// Tela principal do aplicativo - Dashboard com listagem e status de equipamentos
/// totalmente protegida com RBAC (Role-Based Access Control).
class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<String> _selectedStatuses = ['TODOS'];
  bool _ordenarPorMaisTempoParado = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Equipamento> _filtrarEquipamentos(List<Equipamento> equipamentos) {
    var lista = equipamentos.where((eq) {
      final matchesSearch = _searchQuery.isEmpty ||
          eq.nome.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          eq.tag.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          eq.localizacao.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _selectedStatuses.contains('TODOS') ||
          _selectedStatuses.contains(eq.status.name);

      return matchesSearch && matchesStatus;
    }).toList();

    // Filtro avançado para o Supervisor: listar e ordenar máquinas indisponíveis há mais tempo
    if (_ordenarPorMaisTempoParado) {
      lista.sort((a, b) => b.tempoParado.compareTo(a.tempoParado));
    }

    return lista;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final equipamentoProvider = context.watch<EquipamentoProvider>();
    final usuario = authProvider.usuario;

    if (!authProvider.autenticado || usuario == null) {
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

    final equipamentosFiltrados = _filtrarEquipamentos(equipamentoProvider.equipamentos);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'SIGE Industrial',
        usuario: usuario,
        leading: IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Sair do Sistema',
          onPressed: () {
            context.read<AuthProvider>().logout();
            Navigator.of(context).pushReplacementNamed('/login');
          },
        ),
        actions: [
          // 1. Botão do Painel Técnico (Apenas Técnico e Gestor)
          PermissionGuard(
            permission: AppPermission.assumirManutencao,
            child: IconButton(
              icon: const Icon(Icons.build_circle_outlined),
              tooltip: 'Painel Técnico',
              onPressed: () => Navigator.of(context).pushNamed('/painel-tecnico'),
            ),
          ),

          // 1.1 Botão do Painel do Supervisor (Apenas Supervisor e Gestor)
          PermissionGuard(
            permission: AppPermission.entregarMaterial,
            child: IconButton(
              icon: const Icon(Icons.supervisor_account),
              tooltip: 'Painel do Supervisor',
              onPressed: () => Navigator.of(context).pushNamed('/painel-supervisor'),
            ),
          ),

          // 2. Botão de Relatórios & KPIs (Supervisor e Gestor)
          PermissionGuard(
            permission: AppPermission.visualizarDashboardKpi,
            child: IconButton(
              icon: const Icon(Icons.analytics_outlined),
              tooltip: 'Relatórios & KPIs',
              onPressed: () => Navigator.of(context).pushNamed('/relatorios'),
            ),
          ),

          // 3. Botão de Gerenciamento de Ativos (EXCLUSIVO do Gestor)
          PermissionGuard(
            permission: AppPermission.crudMaquinas,
            child: IconButton(
              icon: const Icon(Icons.settings_suggest),
              tooltip: 'Gerenciamento de Máquinas',
              onPressed: () => Navigator.of(context).pushNamed('/gerenciamento-maquinas'),
            ),
          ),

        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await equipamentoProvider.carregarEquipamentos();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner de Destaque Visual por Cargo com Acesso Rápido às Abas Exclusivas
                  _RoleHeaderBanner(usuario: usuario),

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

                  // Barra de Filtro Avançado exclusiva do Supervisor / Gestor
                  PermissionGuard(
                    permission: AppPermission.filtrosAvancadosIndisponibilidade,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_list, size: 18, color: Colors.orange),
                          const SizedBox(width: 8),
                          const Text('Filtro de Gestão: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          FilterChip(
                            label: const Text('Indisponíveis há mais tempo'),
                            selected: _ordenarPorMaisTempoParado,
                            onSelected: (val) {
                              setState(() => _ordenarPorMaisTempoParado = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Resumo executivo de métricas rápidas
                  if (equipamentoProvider.equipamentos.isNotEmpty)
                    _ResumoExecutive(
                      equipamentos: equipamentoProvider.equipamentos,
                      statusCounts: equipamentoProvider.statusCounts,
                    ),
                ],
              ),
            ),

            // Lista de equipamentos ou estados vazios/carregando
            if (equipamentoProvider.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (equipamentosFiltrados.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(top: 8, bottom: 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
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
                    childCount: equipamentosFiltrados.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Banner de identidade visual do perfil logado e atalhos rápidos das abas do cargo.
class _RoleHeaderBanner extends StatelessWidget {
  final Usuario usuario;

  const _RoleHeaderBanner({required this.usuario});

  @override
  Widget build(BuildContext context) {
    Color roleColor;
    IconData roleIcon;
    String roleTitle;
    String roleDescription;
    List<Widget> quickActions = [];

    switch (usuario.perfil) {
      case PerfilUsuario.operador:
        roleColor = const Color(0xFFF59E0B); // Laranja industrial
        roleIcon = Icons.engineering;
        roleTitle = 'Operador de Produção';
        roleDescription = 'Acesso ao chão de fábrica para registro e acompanhamento de paradas de máquinas.';
        quickActions = [
          _QuickActionButton(
            label: 'Linha Operacional',
            icon: Icons.precision_manufacturing,
            color: roleColor,
            onTap: () {},
            isCurrent: true,
          ),
        ];
        break;

      case PerfilUsuario.tecnico:
        roleColor = const Color(0xFF06B6D4); // Ciano
        roleIcon = Icons.build_circle;
        roleTitle = 'Técnico de Manutenção';
        roleDescription = 'Reparo de máquinas, atendimento a paradas e emissão de laudos técnicos.';
        quickActions = [
          _QuickActionButton(
            label: 'Painel Técnico de Manutenção',
            icon: Icons.build_circle_outlined,
            color: roleColor,
            onTap: () => Navigator.of(context).pushNamed('/painel-tecnico'),
          ),
        ];
        break;

      case PerfilUsuario.supervisor:
        roleColor = const Color(0xFF6366F1); // Índigo / Roxo
        roleIcon = Icons.supervisor_account;
        roleTitle = 'Supervisor de Manutenção';
        roleDescription = 'Aprovação de paradas críticas, designação de técnicos, suprimento de materiais e KPIs.';
        quickActions = [
          _QuickActionButton(
            label: 'Aprovações & Materiais',
            icon: Icons.verified_user,
            color: roleColor,
            onTap: () => Navigator.of(context).pushNamed('/painel-supervisor'),
          ),
          const SizedBox(width: 8),
          _QuickActionButton(
            label: 'Relatórios & KPIs',
            icon: Icons.analytics_outlined,
            color: Colors.blueAccent,
            onTap: () => Navigator.of(context).pushNamed('/relatorios'),
          ),
        ];
        break;

      case PerfilUsuario.gestor:
        roleColor = const Color(0xFF10B981); // Esmeralda
        roleIcon = Icons.admin_panel_settings;
        roleTitle = 'Gestor Industrial Executivo';
        roleDescription = 'Governança de ativos industriais: Gestão de máquinas e análise de relatórios & KPIs.';
        quickActions = [
          _QuickActionButton(
            label: 'Gerenciar Máquinas',
            icon: Icons.settings_suggest,
            color: roleColor,
            onTap: () => Navigator.of(context).pushNamed('/gerenciamento-maquinas'),
          ),
          const SizedBox(width: 8),
          _QuickActionButton(
            label: 'Relatórios & KPIs',
            icon: Icons.analytics_outlined,
            color: Colors.teal.shade700,
            onTap: () => Navigator.of(context).pushNamed('/relatorios'),
          ),
        ];
        break;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            roleColor.withValues(alpha: 0.22),
            roleColor.withValues(alpha: 0.08),
            Theme.of(context).cardColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: roleColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: roleColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: roleColor.withValues(alpha: 0.2),
                child: Icon(roleIcon, color: roleColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          usuario.nome.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: roleColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            roleTitle.toUpperCase(),
                            style: TextStyle(
                              color: roleColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      roleDescription,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Acesso Rápido às Abas do Cargo:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: quickActions),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isCurrent;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isCurrent ? color.withValues(alpha: 0.25) : color,
        foregroundColor: isCurrent ? color : Colors.white,
        elevation: isCurrent ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isCurrent ? BorderSide(color: color, width: 1.5) : BorderSide.none,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      onPressed: isCurrent ? null : onTap,
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
    final aguardandoAprovacao = statusCounts[StatusEquipamento.aguardandoAprovacao] ?? 0;

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
          if (aguardandoAprovacao > 0) ...[
            const SizedBox(width: 8),
            _ResumoCard(
              label: 'Aprovação',
              valor: aguardandoAprovacao.toString(),
              cor: AppCores.aguardandoAprovacao,
              icone: Icons.pending_actions,
            ),
          ],
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
