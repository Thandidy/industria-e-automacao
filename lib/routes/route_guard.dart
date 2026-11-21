// lib/routes/route_guard.dart

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../models/usuario.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../views/login_view.dart';
import '../views/solicitar_acesso_view.dart';
import '../views/dashboard_view.dart';
import '../views/painel_tecnico_view.dart';
import '../views/relatorios_view.dart';
import '../views/gerenciamento_maquinas_view.dart';
import '../views/painel_supervisor_view.dart';

/// Middleware de navegação (Route Guard) responsável por interceptar
/// e bloquear acessos a rotas não permitidas para o perfil do usuário logado.
class RouteGuard {
  /// Permissão mínima exigida por rota protegida
  static final Map<String, AppPermission> _routePermissions = {
    '/dashboard': AppPermission.visualizarMaquinas,
    '/painel-tecnico': AppPermission.assumirManutencao,
    '/painel-supervisor': AppPermission.entregarMaterial,
    '/relatorios': AppPermission.visualizarDashboardKpi,
    '/gerenciamento-maquinas': AppPermission.crudMaquinas, // Exclusivo do Gestor
  };

  static Route<dynamic> onGenerateRoute(RouteSettings settings, BuildContext context) {
    final rota = settings.name ?? '/dashboard';

    // Rotas públicas (não exigem autenticação)
    if (rota == '/login') {
      return MaterialPageRoute(builder: (_) => const LoginView(), settings: settings);
    }
    if (rota == '/solicitar-acesso') {
      return MaterialPageRoute(builder: (_) => const SolicitarAcessoView(), settings: settings);
    }

    final auth = context.read<AuthProvider>();
    final usuario = auth.usuario;

    // 1. Barreira de autenticação
    if (!auth.autenticado || usuario == null) {
      return MaterialPageRoute(
        builder: (_) => const LoginView(),
        settings: const RouteSettings(name: '/login'),
      );
    }

    // 2. Barreira de autorização baseada em RBAC (Role-Based Access Control)
    final permissaoExigida = _routePermissions[rota];
    if (permissaoExigida != null && !usuario.can(permissaoExigida)) {
      return MaterialPageRoute(
        builder: (_) => AcessoNegadoView(
          rotaSolicitada: rota,
          usuario: usuario,
        ),
        settings: settings,
      );
    }

    // 3. Resolução normal de rotas autorizadas
    switch (rota) {
      case '/dashboard':
        return MaterialPageRoute(builder: (_) => const DashboardView(), settings: settings);
      case '/painel-tecnico':
        return MaterialPageRoute(builder: (_) => const PainelTecnicoView(), settings: settings);
      case '/painel-supervisor':
        return MaterialPageRoute(builder: (_) => const PainelSupervisorView(), settings: settings);
      case '/relatorios':
        return MaterialPageRoute(builder: (_) => const RelatoriosView(), settings: settings);
      case '/gerenciamento-maquinas':
        return MaterialPageRoute(builder: (_) => const GerenciamentoMaquinasView(), settings: settings);
      default:
        return MaterialPageRoute(builder: (_) => const DashboardView(), settings: settings);
    }
  }
}

/// Tela de Acesso Negado (HTTP 403 Forbidden)
class AcessoNegadoView extends StatelessWidget {
  final String rotaSolicitada;
  final Usuario usuario;

  const AcessoNegadoView({
    super.key,
    required this.rotaSolicitada,
    required this.usuario,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acesso Restrito'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.gpp_bad, size: 64, color: Colors.red),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Acesso Não Autorizado',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Seu cargo atual (${usuario.perfil.nome}) não possui permissão para acessar a tela "$rotaSolicitada".',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed('/dashboard');
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Voltar ao Dashboard'),
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
}

