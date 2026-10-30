# MVP Indústria e Manutenção - Plano de Implementação

## Status
- [x] Estrutura do projeto criada
- [x] Models criados (usuario, equipamento, ocorrencia, historico)
- [ ] Providers implementados
- [ ] Utilitários criados
- [ ] Widgets reutilizáveis
- [ ] Telas implementadas
- [ ] Teste de compilação

## Estrutura de Arquivos
```
lib/
├── main.dart                    # Entry point, rotas, providers
├── models/
│   ├── usuario.dart             # ✓ Existe
│   ├── equipamento.dart         # ✓ Criado
│   ├── ocorrencia.dart          # ✓ Criado
│   └── historico.dart           # ✓ Criado
├── utils/
│   ├── constants.dart           # ✓ Existe (enums + cores)
│   ├── theme.dart               # NOVO - Tema Material 3 completo
│   ├── validators.dart          # NOVO - Validadores de formulário
│   └── helpers.dart             # NOVO - Helpers de navegação/formatação
├── providers/
│   ├── auth_provider.dart       # NOVO - Estado de autenticação/perfil
│   ├── equipamento_provider.dart# NOVO - Estado dos equipamentos
│   └── ocorrencia_provider.dart # NOVO - Estado das ocorrências
├── views/
│   ├── login_view.dart          # Tela 1: Login/Codigo
│   ├── dashboard_view.dart      # Tela 2: Dashboard Principal
│   ├── equipamento_detalhe_view.dart # Tela 3: Detalhes/Histórico
│   ├── registro_parada_view.dart # Tela 4: Registro de Parada
│   ├── painel_tecnico_view.dart # Tela 5: Painel Técnico
│   └── relatorios_view.dart     # Tela 6: Relatórios/Gestão
└── widgets/
    ├── status_badge.dart        # Badge de status colorido
    ├── equipamento_card.dart    # Card visual do equipamento
    ├── search_filter_bar.dart   # Barra de busca/filtro
    ├── timeline_item.dart       # Item da timeline/histórico
    ├── custom_app_bar.dart      # AppBar personalizada com perfil
    ├── snackbar_helper.dart     # SnackBars padronizados
    └── loading_overlay.dart     # Overlay de carregamento
```

## Fluxo de Telas (6 Obrigatórias)

| Tela | Arquivo | Funcionalidades Principais |
|------|---------|---------------------------|
| **1. Login/Codigo** | `login_view.dart` | Alternância login/codigo, validação, seleção de perfil, mock de usuários |
| **2. Dashboard** | `dashboard_view.dart` | Listagem com cards, busca/filtro por status, cards coloridos por status, botão "Nova Parada" por perfil |
| **3. Detalhes** | `equipamento_detalhe_view.dart` | Header com status, timeline/histórico de ocorrências, ações por perfil |
| **4. Registro Parada** | `registro_parada_view.dart` | Formulário validado, motivos, prioridade, regra: não permitir dupla parada |
| **5. Painel Técnico** | `painel_tecnico_view.dart` | Lista de ocorrências, iniciar/finalizar atendimento, calcular duração |
| **6. Relatórios** | `relatorios_view.dart` | KPIs, gráficos mockados, tabela de máquinas paradas há mais tempo |

## Regras de Negócio na UI
- **Perfis**: Operador (registrar parada), Técnico (iniciar/finalizar), Supervisor/Gestor (relatórios)
- **Feedbacks**: SnackBars coloridos (sucesso/aviso/erro)
- **Restrições**: Sem dupla parada, transições de status válidas (Operando→Parada→Manutenção→Operando)

## Ordem de Implementação
1. **Fase 1**: Models, Providers, Theme base, Widgets reutilizáveis
2. **Fase 2**: Login/Codigo + Atualizar main.dart
3. **Fase 3**: Dashboard + Widgets de listagem
4. **Fase 4**: Detalhes + Timeline
5. **Fase 5**: Registro Parada + Painel Técnico
6. **Fase 6**: Relatórios + Polimento