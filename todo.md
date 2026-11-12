# TODO: SIGE - Revamp Visual, Gestão de Aprovação Crítica e Matriz RBAC

Este documento orienta a implementação completa das novas regras de negócio e aprimoramentos visuais solicitados para a aplicação Flutter/Dart.

---

## 1. Status "Aguardando Aprovação" e Limpeza de Estados
- [x] **1.1. Adicionar status "Aguardando Aprovação" aos filtros de Relatórios e Gestão**
  - [x] Adicionar `StatusOcorrencia.aguardandoAprovacao` e `StatusEquipamento.aguardandoAprovacao` nos filtros de `relatorios_view.dart`.
  - [x] Adicionar filtro de status em `gerenciamento_maquinas_view.dart` incluindo "Aguardando Aprovação".
  - [x] Adicionar chip "Aguardando Aprovação" em `search_filter_bar.dart` e `dashboard_view.dart`.
- [x] **1.2. Retirar por completo o estado (resíduo)**
  - [x] Remover o chip/label 'Resíduo' em `search_filter_bar.dart` e substituir por 'Aguardando Material'.
  - [x] Garantir que nenhum arquivo contenha referências residuais à palavra ou estado 'Resíduo'.

---

## 2. Fluxo e Regras de Negócio: Parada Crítica e "Aguardando Aprovação"
- [x] **2.1. Modelos de Dados (`Equipamento` e `Ocorrencia`)**
  - [x] Garantir campos `grauCritico`, `aprovadaManutencao`, `tecnicoDesignado`, `tecnicoDesignadoId` em `Equipamento` e `Ocorrencia`.
  - [x] Atualizar serialização (`toJson`, `fromJson`, `copyWith`) em `equipamento.dart` e `ocorrencia.dart`.
- [x] **2.2. Diferenciação Dinâmica de Ícones (Estado X vs Estado Y)**
  - [x] **Ícone X (Aguardando Aprovação):** Quando uma máquina parar com grau crítico e ainda precisar de aprovação do supervisor (`Icons.pending_actions` / `Icons.gavel` em tom âmbar/roxo de alerta com badge "Crítica - Aguardando Aprovação").
  - [x] **Ícone Y (Aprovada para Manutenção):** Quando o supervisor aprovar e designar o técnico (`Icons.assignment_turned_in` / `Icons.verified` em tom teal/índigo com badge "Aprovada: [Nome do Técnico]").
  - [x] Atualizar `status_badge.dart`, `equipamento_card.dart` e `constants.dart` para refletir os estados e ícones X e Y.
- [x] **2.3. Lógica do Provider (`OcorrenciaProvider` e `EquipamentoProvider`)**
  - [x] **Parada Não-Crítica (Baixa, Média, Alta):**
    - Entra diretamente em status `parada` / `aberta`.
    - Não exige aprovação do supervisor. Qualquer técnico pode assumir/arrumar livremente.
  - [x] **Parada Crítica:**
    - Entra em `aguardandoAprovacao`.
    - Bloqueia técnicos de iniciarem enquanto não houver aprovação e designação de técnico pelo supervisor.
  - [x] **Aprovação e Designação pelo Supervisor:**
    - Supervisor aprova a ocorrência crítica e seleciona o técnico designado.
    - Ocorrência/máquina passa para aprovada com o técnico designado registrado.
  - [x] **Exclusividade do Técnico Designado:**
    - Apenas o técnico designado pode clicar em "Iniciar Atendimento" / "Assumir Manutenção" da máquina crítica.
    - Outros técnicos recebem bloqueio/aviso amigável na tela.
  - [x] **Pausa por Materiais e Suprimento:**
    - Técnico pode pausar a manutenção por falta de materiais (`aguardandoMaterial`).
    - **Bloqueio estrito de retomada:** O técnico fica bloqueado de continuar ou assumir o atendimento enquanto o status for `aguardandoMaterial`.
    - Supervisor supre/entrega os materiais necessários no painel (`entregarMaterial`).
    - Após o supervisor registrar a entrega, o atendimento é retomado automaticamente e o técnico pode proceder para finalizar a manutenção com laudo.

---

## 3. Matriz RBAC Estrita por Cargo
- [x] **3.1. Operadores:**
  - Acesso: Dashboard e Detalhes da máquina.
  - Ações: Visualizar máquinas e registrar paradas de máquinas (incluindo paradas críticas).
- [x] **3.2. Técnicos:**
  - Acesso: Dashboard, Detalhes e `Painel Técnico`.
  - Ações: Reparar livremente máquinas não-críticas; reparar máquinas críticas apenas se designado; pausar por falta de material; finalizar com laudo técnico.
- [x] **3.3. Supervisores:**
  - Acesso: Dashboard, Detalhes, `Painel do Supervisor` e `Relatórios & KPIs`.
  - Ações: Designar técnicos para manutenções críticas (aprovação); suprir/entregar materiais; reatribuir prioridade; consultar relatórios e KPIs.
- [x] **3.4. Gestores Industriais:**
  - Acesso estrito: Dashboard, `Relatórios & KPIs` e `Gerenciamento de Máquinas`.
  - Ações: Consulta executiva de KPIs e Gestão de máquinas (cadastrar, editar dados e remover). Sem menções a termos técnicos 'CRUD' na interface. Sem botões de ações operacionais diretas de técnicos ou supervisores.

---

## 4. Revamp Visual e Destaque das Abas Específicas por Cargo
- [x] **4.1. Visual Identitário por Cargo com Perfil em MAIÚSCULO**
  - Operador: Laranja Industrial (`#F59E0B`), ícone `engineering`.
  - Técnico: Azul Ciano (`#06B6D4`), ícone `build_circle`.
  - Supervisor: Índigo/Roxo (`#6366F1`), ícone `supervisor_account`.
  - Gestor Industrial: Esmeralda/Ouro (`#10B981`), ícone `admin_panel_settings`.
  - Nome e Perfil exibidos em MAIÚSCULO no Dashboard e CustomAppBar (`GESTOR INDUSTRIAL EXECUTIVO`, etc.).
- [x] **4.2. Banner de Acesso Rápido com Alto Destaque no Dashboard**
  - Banners e cards modernos exibindo o cargo do usuário, status da linha e botões de grande destaque direcionando para suas abas exclusivas.
- [x] **4.3. Polimento de UI/UX e Edição de Ativos**
  - Atualização do `theme.dart`, `custom_app_bar.dart`, `equipamento_card.dart`, `status_badge.dart` e tabelas de ocorrências para padrão industrial premium, com alto contraste, fontes nítidas e feedback visual claro.
  - Botão e modal de "Editar Máquina" implementado para alterar TAG/Código, Nome e Localização diretamente no Firestore.
