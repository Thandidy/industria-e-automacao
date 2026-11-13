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

---

## 5. Integração com WhatsApp Bot (`sige-whatsapp-bot`)
- [x] **5.1. Compatibilidade entre Módulos JS:**
  - Migração completa de `mensagens.js` para ES Modules (`import`/`export`), em total conformidade com `package.json` (`"type": "module"`) e `index.js`.
- [x] **5.2. Notificação Direta ao Novo Usuário Aprovado:**
  - Quando o gestor aprova uma solicitação de login no WhatsApp, o bot envia automaticamente uma mensagem de boas-vindas ao WhatsApp do colaborador informando login, perfil e liberação de acesso.
- [x] **5.3. Notificação Específica de Parada de Máquina e Motivo para Técnicos:**
  - O bot notifica individualmente a equipe técnica com nome da máquina, TAG, localização física e o motivo da parada.
  - No app Flutter, cards e painel técnico destacam o motivo exato da parada.
- [x] **5.4. Notificação de Suprimentos, Designação e Reparo Finalizado:**
  - Suprimentos solicitados enviados para supervisores; designação exclusiva enviada para o técnico indicado; finalização de reparo enviada para chefia, supervisores e gestores.

---

## 6. Funcionalidade "Esqueci Minha Senha" (Código de 6 Dígitos via WhatsApp & E-mail)

Este módulo implementa o fluxo completo de recuperação e redefinição de senha para usuários cadastrados, com envio automatizado de código de 6 dígitos para WhatsApp ou E-mail e registro em coleção dedicada no Firestore.

### 6.1. Modelagem de Dados & Coleção `recuperacoes_senha`
- [x] **6.1.1. Definição do Schema da Coleção no Firestore**
  - Coleção: `recuperacoes_senha`
  - Campos do documento:
    - `usuarioId`: ID do usuário na coleção `usuarios` (String)
    - `nome`: Nome do usuário para personalização da mensagem (String)
    - `identificador`: E-mail ou Telefone digitado pelo usuário (String)
    - `canal`: Canal de envio (`'whatsapp'` ou `'email'`) (String)
    - `codigo`: Código aleatório de 6 dígitos numéricos (ex: `'492817'`) (String)
    - `status`: Status do envio (`'pendente'`, `'enviado'`, `'concluido'`, `'expirado'`, `'cancelado'`) (String)
    - `usado`: Booleano indicando se o código já foi consumido (`false` por padrão)
    - `tentativas`: Contador de tentativas de validação incorretas (int, máx. 5)
    - `criadoEm`: Timestamp do momento da solicitação (Timestamp/DateTime)
    - `expiraEm`: Timestamp de expiração (15 minutos após a criação) (Timestamp/DateTime)
    - `enviadoEm`: Timestamp do envio efetuado pelo bot (Timestamp)
    - `concluidoEm`: Timestamp em que a senha foi atualizada com sucesso (Timestamp)

- [x] **6.1.2. Criação do Modelo Dart `RecuperacaoSenha`**
  - Criar `lib/models/recuperacao_senha.dart` com atributos, construtor, `toMap()`, `fromFirestore()` e métodos utilitários:
    - `bool get isExpirado`
    - `bool get isValido`

---

### 6.2. Interface do Usuário (Flutter - `industria-e-automacao`)
- [x] **6.2.1. Botão "Esqueci minha senha" na `LoginView`**
  - Adicionar link/botão `TextButton` "Esqueci minha senha" em `lib/views/login_view.dart` posicionado logo abaixo do campo de senha ou próximo ao botão de solicitação de acesso.
  - Navegar para a nova tela `RecuperarSenhaView`.

- [x] **6.2.2. Criação da View `RecuperarSenhaView` (`lib/views/recuperar_senha_view.dart`)**
  - Estrutura em 3 etapas sequenciais (Step/PageView ou Máquina de Estados):
    - **Etapa 1: Identificação (E-mail ou WhatsApp)**
      - Campo de entrada único inteligente para E-mail ou Telefone com máscara/validador.
      - Detecção automática do tipo de dado informado (se contém `@` trata como e-mail; se apenas números/formato telefone trata como telefone).
      - Busca na coleção `usuarios` para validar se o e-mail ou telefone informado existe cadastrado.
      - Geração do código seguro de 6 dígitos numéricos (`Random.secure()`).
      - Invalidação de códigos anteriores pendentes do mesmo usuário no Firestore.
      - Gravação do novo documento em `recuperacoes_senha` com `status: 'pendente'`.
      - Transição suave para a Etapa 2.
    - **Etapa 2: Validação do Código de 6 Dígitos**
      - Campo visual com formatação de 6 dígitos (OTP) ou `TextFormField` com máscara de 6 números.
      - Informação clara indicando para onde o código foi enviado: *"Código enviado para o WhatsApp (XX) XXXXX-XXXX"* ou *"Código enviado para o e-mail us***@empresa.com"*.
      - Temporizador regressivo visual de validade (15 minutos).
      - Botão "Reenviar Código" com cooldown de 60 segundos para evitar abusos e custos de envio.
      - Validação contra o Firestore: confere se o código digitado bate com o ativo, se `expiraEm > agora` e se `usado == false`.
      - Controle de tentativas incorretas (bloqueio do código se errar mais de 5 vezes).
      - Transição para a Etapa 3 após validação bem-sucedida.
    - **Etapa 3: Definição da Nova Senha**
      - Campos "Nova Senha" e "Confirmar Nova Senha" com botões de alternância de visibilidade (olho).
      - Validação de força da senha (mínimo 6 ou 8 dígitos, consistência entre os campos).
      - Ao submeter:
        - Atualização do campo `senha` no documento do usuário em `usuarios`.
        - Atualização do documento em `recuperacoes_senha`: `usado: true`, `status: 'concluido'`, `concluidoEm: agora`.
        - Exibição de Snackbar amigável de sucesso (`SnackbarHelper.showSnackbar`).
        - Redirecionamento automático de volta para a `LoginView`.

---

### 6.3. Serviço de Disparo WhatsApp & E-mail (`sige-whatsapp-bot`)
- [x] **6.3.1. Listener Firestore para Códigos de Recuperação em `sige-whatsapp-bot/index.js`**
  - Criar observador em tempo real:
    `db.collection('recuperacoes_senha').where('status', '==', 'pendente').onSnapshot(...)`
  - Evitar envios duplicados com trava em memória (Map/Set temporário de IDs).

- [x] **6.3.2. Disparo de WhatsApp via Baileys**
  - Quando `canal === 'whatsapp'`:
    - Sanitizar telefone do usuário com DDI (55) e DDD.
    - Montar mensagem formatada e visualmente clara com o código:
      ```
      🔐 *SIGE - RECUPERAÇÃO DE SENHA*

      Olá, *[Nome]*! 👋
      Você solicitou a redefinição de sua senha de acesso.

      Seu código de verificação é:
      👉 *[CODIGO_6_DIGITOS]* 👈

      ⏰ *Validade:* 15 minutos.
      ⚠️ Se você não solicitou este código, por favor desconsidere este aviso.
      ```
    - Chamar `enviarMensagemWhatsApp(telefone, mensagem)`.
    - Atualizar documento no Firestore: `status: 'enviado'`, `enviadoEm: FieldValue.serverTimestamp()`.

- [x] **6.3.3. Disparo de E-mail Automático com Nodemailer**
  - Adicionar biblioteca `nodemailer` no `package.json` do `sige-whatsapp-bot`.
  - Configurar variáveis de ambiente no `.env`:
    - `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_SECURE`, `EMAIL_FROM`
  - Quando `canal === 'email'`:
    - Montar template HTML corporativo moderno com a identidade SIGE (Logotipo, caixa destacada para o código de 6 dígitos, avisos de segurança e validade de 15 minutos).
    - Enviar e-mail via transporter do Nodemailer.
    - Atualizar documento no Firestore: `status: 'enviado'`, `enviadoEm: FieldValue.serverTimestamp()`.

---

### 6.4. Regras de Segurança e Tolerância a Falhas
- [x] **6.4.1. Proteção Anti-Abuso / Rate-Limiting**
  - Impedir que o mesmo usuário solicite mais de 3 códigos por hora.
  - Bloquear códigos com mais de 5 tentativas incorretas consecutivas.
- [x] **6.4.2. Expiração Rígida**
  - O código expira estritamente após 15 minutos. Códigos expirados são rejeitados na validação.
- [x] **6.4.3. Uso Único (One-Time Password)**
  - O código só pode ser utilizado uma única vez (`usado: true`).
- [x] **6.4.4. Tratamento de Exceções & Feedback ao Usuário**
  - Mensagens amigáveis caso o e-mail ou telefone não seja localizado no sistema.
  - Feedback visual claro de carregamento enquanto o código é gerado ou verificado.

---

### 6.5. Testes e Validação de Ponta a Ponta
- [ ] **6.5.1. Teste de Fluxo via Telefone (WhatsApp):**
  - Inserir telefone cadastrado no app -> Verificar criação em `recuperacoes_senha` -> Verificar mensagem no WhatsApp com código -> Digitar código no app -> Alterar senha -> Efetuar login com a nova senha.
- [ ] **6.5.2. Teste de Fluxo via E-mail:**
  - Inserir e-mail cadastrado no app -> Verificar criação em `recuperacoes_senha` -> Receber e-mail com código -> Digitar código no app -> Alterar senha -> Efetuar login com a nova senha.
- [ ] **6.5.3. Teste de Casos de Borda:**
  - Código incorreto digitado -> Mensagem de erro e contagem de tentativas.
  - Código expirado após 15 min -> Mensagem de expiração e opção de reenviar.
  - Telefone ou e-mail inexistente -> Mensagem amigável de que o usuário não foi localizado.
