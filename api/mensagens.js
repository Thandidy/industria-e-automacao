// api/mensagens.js
import { FieldValue } from 'firebase-admin/firestore';
import dbPadrao from './firebase.js';

// Trava em memória para evitar notificações repetidas em disparos paralelos (TTL de 15 segundos)
const notificacoesRecentes = new Map();

function jaFoiNotificadoRecentemente(chave) {
  const agora = Date.now();
  if (notificacoesRecentes.has(chave)) {
    const tempo = notificacoesRecentes.get(chave);
    if (agora - tempo < 15000) {
      return true;
    }
  }
  notificacoesRecentes.set(chave, agora);
  // Limpeza periódica do mapa
  if (notificacoesRecentes.size > 200) {
    for (const [k, t] of notificacoesRecentes.entries()) {
      if (agora - t > 30000) notificacoesRecentes.delete(k);
    }
  }
  return false;
}

/**
 * Busca dados complementares da máquina na coleção 'maquinas'
 */
export async function buscarMaquina(db = dbPadrao, { id, tag } = {}) {
  if (!db) return null;
  try {
    if (id) {
      const doc = await db.collection('maquinas').doc(id).get();
      if (doc.exists) {
        return { id: doc.id, ...doc.data() };
      }
    }
    if (tag) {
      const snap = await db.collection('maquinas').where('tag', '==', tag).limit(1).get();
      if (!snap.empty) {
        return { id: snap.docs[0].id, ...snap.docs[0].data() };
      }
    }
  } catch (err) {
    console.error('[mensagens.js] Erro ao buscar máquina:', err?.message || err);
  }
  return null;
}

// Helper para normalizar textos removendo acentos e convertendo para minúsculas
export function normalizarTexto(txt) {
  return (txt || '')
    .toString()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim();
}

/**
 * Busca usuários com perfis específicos que tenham telefone cadastrado
 * Ex: perfis = ['tecnico', 'supervisor'] ou ['gestor', 'supervisor']
 */
export async function buscarUsuariosPorPerfis(db = dbPadrao, perfis = []) {
  if (!db || !perfis.length) return [];
  try {
    const snap = await db.collection('usuarios').get();
    const resultados = [];
    const perfisNorm = perfis.map(normalizarTexto);

    snap.forEach((doc) => {
      const data = doc.data();
      const p = normalizarTexto(data.perfil);
      const tel = (data.telefone || '').toString().trim();

      if (tel && perfisNorm.some((perfil) => p.includes(perfil))) {
        resultados.push({
          id: doc.id,
          nome: data.nome || data.nomeFuncionario || 'Colaborador',
          perfil: p,
          telefone: tel
        });
      }
    });

    return resultados;
  } catch (err) {
    console.error('[mensagens.js] Erro ao buscar usuários por perfil:', err?.message || err);
    return [];
  }
}

/**
 * Busca um usuário por ID ou Nome na coleção 'usuarios' (com fallback para solicitacoes_login)
 */
export async function buscarUsuarioPorIdOuNome(db = dbPadrao, { id, nome } = {}) {
  if (!db) return null;
  try {
    let usuario = null;

    if (id) {
      const doc = await db.collection('usuarios').doc(id).get();
      if (doc.exists) {
        usuario = { id: doc.id, ...doc.data() };
      }
    }

    if (!usuario && nome) {
      const snap = await db.collection('usuarios').where('nome', '==', nome).limit(1).get();
      if (!snap.empty) {
        usuario = { id: snap.docs[0].id, ...snap.docs[0].data() };
      } else {
        const todos = await db.collection('usuarios').get();
        const nomeNorm = normalizarTexto(nome);
        for (const d of todos.docs) {
          const uNome = normalizarTexto(d.data().nome || d.data().nomeFuncionario);
          if (uNome === nomeNorm || uNome.includes(nomeNorm) || nomeNorm.includes(uNome)) {
            usuario = { id: d.id, ...d.data() };
            break;
          }
        }
      }
    }

    // Se o usuário não tem telefone registrado em 'usuarios', busca em 'solicitacoes_login'
    if ((!usuario || !usuario.telefone) && (id || nome)) {
      if (id) {
        const sDoc = await db.collection('solicitacoes_login').doc(id).get();
        if (sDoc.exists) {
          const sData = sDoc.data();
          if (usuario) {
            usuario.telefone = usuario.telefone || sData.telefone;
          } else {
            usuario = { id: sDoc.id, ...sData };
          }
        }
      }
      if ((!usuario || !usuario.telefone) && nome) {
        const todosS = await db.collection('solicitacoes_login').get();
        const nomeNorm = normalizarTexto(nome);
        for (const d of todosS.docs) {
          const sNome = normalizarTexto(d.data().nome || d.data().nomeFuncionario);
          if (sNome === nomeNorm || sNome.includes(nomeNorm)) {
            const sData = d.data();
            if (usuario) {
              usuario.telefone = usuario.telefone || sData.telefone;
            } else {
              usuario = { id: d.id, ...sData };
            }
            break;
          }
        }
      }
    }

    return usuario;
  } catch (err) {
    console.error('[mensagens.js] Erro ao buscar usuário:', err?.message || err);
  }
  return null;
}

/**
 * Envia uma mensagem para múltiplos destinatários via WhatsApp, evitando números duplicados
 */
export async function enviarParaDestinatarios(enviarMensagem, telefones = [], mensagem) {
  if (typeof enviarMensagem !== 'function') {
    console.error('[mensagens.js] enviarMensagem não é uma função.');
    return;
  }
  const enviados = new Set();
  for (const tel of telefones) {
    if (!tel) continue;
    let sanitizado = tel.replace(/\D/g, '');
    if (!sanitizado) continue;
    if (sanitizado.length === 10 || sanitizado.length === 11) {
      sanitizado = '55' + sanitizado;
    }
    if (enviados.has(sanitizado)) continue;
    enviados.add(sanitizado);

    try {
      await enviarMensagem(sanitizado, mensagem);
    } catch (e) {
      console.error(`[mensagens.js] Falha ao enviar WhatsApp para ${sanitizado}:`, e?.message || e);
    }
  }
}
  }
}

/**
 * 1. Notifica sempre que uma máquina parar:
 *    - Envia para o TELEFONE_CHEFE
 *    - Envia para todos os Técnicos e Supervisores com telefone cadastrado
 */
export async function notificarParadaMaquina({ db = dbPadrao, enviarMensagem, telefoneChefe, maquina, ocorrencia }) {
  const chave = `parada_${ocorrencia?._id || ocorrencia?.id || maquina?.id}_${maquina?.tag || ''}`;
  if (jaFoiNotificadoRecentemente(chave)) return;

  const nome = maquina?.nome || ocorrencia?.equipamentoNome || 'Máquina';
  const tag = maquina?.tag || ocorrencia?.equipamentoTag || maquina?.codigo || 'N/A';
  const localizacao = maquina?.localizacao || 'Chão de Fábrica';
  const ehCritica = ocorrencia?.grauCritico === true || maquina?.grauCritico === true ||
                    String(ocorrencia?.prioridade || '').toLowerCase().includes('crit');
  const motivo = ocorrencia?.motivo || ocorrencia?.descricao || maquina?.motivoParada || 'Parada operacional registrada';
  const solicitante = ocorrencia?.solicitante || 'Operador de Produção';
  const horario = new Date().toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });

  const mensagem = `🚨 *ALERTA DE PARADA: MÁQUINA ${tag}*\n\n` +
                   `A máquina *${nome}* (TAG: *${tag}*) localizada em *${localizacao}* acabou de PARAR!\n\n` +
                   `📌 *Motivo da Parada:* ${motivo}\n` +
                   `⚠️ *Classificação:* ${ehCritica ? '🔴 CRÍTICA (Exige aprovação do Supervisor)' : '🟢 Normal (Liberada para início imediato)'}\n` +
                   `👤 *Registrado por:* ${solicitante}\n` +
                   `🕒 *Horário:* ${horario}\n\n` +
                   `👉 Acesse o seu *Painel Técnico* no aplicativo SIGE para verificar a máquina e os procedimentos necessários.`;

  // Destinatários: Chefe + Técnicos + Supervisores
  const equipeAlerta = await buscarUsuariosPorPerfis(db, ['tecnico', 'supervisor']);
  const telefones = [telefoneChefe, ...equipeAlerta.map((u) => u.telefone)].filter(Boolean);

  console.log(`[WhatsApp] Notificando parada da máquina ${nome} (${tag}) - Motivo: "${motivo}" para ${telefones.length} destinatário(s)...`);
  await enviarParaDestinatarios(enviarMensagem, telefones, mensagem);
}

/**
 * 2. Notifica quando a máquina precisar de suprimentos / insumos:
 *    - Envia para o TELEFONE_CHEFE
 *    - Envia para todos os Supervisores com telefone cadastrado
 */
export async function notificarFaltaMaterial({ db = dbPadrao, enviarMensagem, telefoneChefe, maquina, ocorrencia }) {
  const chave = `suprimento_${ocorrencia?._id || ocorrencia?.id || maquina?.id}`;
  if (jaFoiNotificadoRecentemente(chave)) return;

  const nome = maquina?.nome || ocorrencia?.equipamentoNome || 'Máquina';
  const tag = maquina?.tag || ocorrencia?.equipamentoTag || 'N/A';
  const localizacao = maquina?.localizacao || 'Parque Industrial';
  const tecResponsavel = ocorrencia?.tecnicoResponsavel || maquina?.tecnicoDesignado || 'Técnico';
  const motivoPausa = ocorrencia?.motivoPausa || ocorrencia?.descricao || 'Aguardando peças/materiais';

  const mensagem = `📦 *SOLICITAÇÃO DE SUPRIMENTOS (SIGE)*\n\n` +
                   `A máquina *${nome}* (${tag}) necessita de suprimentos para prosseguir!\n` +
                   `📍 *Localização:* ${localizacao}\n` +
                   `🛠️ *Técnico:* ${tecResponsavel}\n` +
                   `📝 *Material em Falta:* ${motivoPausa}\n\n` +
                   `👉 *Ação necessária:* Acesse a aba *"Suprir Materiais"* no Painel do Supervisor no SIGE para realizar a entrega e liberar a manutenção.`;

  // Destinatários: Chefe + Supervisores
  const supervisores = await buscarUsuariosPorPerfis(db, ['supervisor']);
  const telefones = [telefoneChefe, ...supervisores.map((u) => u.telefone)].filter(Boolean);

  console.log(`[WhatsApp] Notificando necessidade de suprimentos para ${telefones.length} supervisor(es)...`);
  await enviarParaDestinatarios(enviarMensagem, telefones, mensagem);
}

/**
 * 3. Notifica o técnico que foi designado exclusivamente para um serviço:
 *    - Mensagem personalizada no WhatsApp do próprio técnico designado
 */
export async function notificarDesignacaoTecnico({ db = dbPadrao, enviarMensagem, maquina, ocorrencia, supervisorNome, tecnicoId, tecnicoNome }) {
  const tecId = tecnicoId || ocorrencia?.tecnicoDesignadoId || maquina?.tecnicoDesignadoId;
  const tecNome = tecnicoNome || ocorrencia?.tecnicoDesignado || maquina?.tecnicoDesignado;

  if (!tecId && !tecNome) return;

  const chave = `designacao_${ocorrencia?._id || ocorrencia?.id || maquina?.id}_${tecId || tecNome}`;
  if (jaFoiNotificadoRecentemente(chave)) return;

  const tecnico = await buscarUsuarioPorIdOuNome(db, { id: tecId, nome: tecNome });
  if (!tecnico || !tecnico.telefone) {
    console.log(`[WhatsApp] Técnico designado ${tecNome} não possui telefone cadastrado.`);
    return;
  }

  const supNome = supervisorNome || ocorrencia?.supervisorResponsavel || 'o Supervisor';
  const nomeMaquina = maquina?.nome || ocorrencia?.equipamentoNome || 'Máquina';
  const tagMaquina = maquina?.tag || ocorrencia?.equipamentoTag || 'N/A';
  const motivo = ocorrencia?.motivo || ocorrencia?.descricao || maquina?.motivoParada || 'Parada crítica';
  const ehCritica = ocorrencia?.grauCritico === true || maquina?.grauCritico === true;

  const mensagem = `🔧 *SIGE - DESIGNAÇÃO DE MANUTENÇÃO*\n\n` +
                   `Olá, *${tecnico.nome || tecNome}*! 👋\n` +
                   `O supervisor *${supNome}* te designou para iniciar a manutenção na máquina *${nomeMaquina}* (${tagMaquina}) que teve a ocorrência:\n` +
                   `📌 *${motivo}*\n` +
                   `⚠️ *Grau:* ${ehCritica ? 'Crítico (Exclusivo)' : 'Normal'}\n\n` +
                   `👉 Abra o aplicativo SIGE e acerte o atendimento no seu *Painel Técnico*.`;

  console.log(`[WhatsApp] Notificando técnico ${tecnico.nome} (${tecnico.telefone}) sobre designação de serviço...`);
  await enviarParaDestinatarios(enviarMensagem, [tecnico.telefone], mensagem);
}

/**
 * 4. Notifica quando o reparo/manutenção for finalizado:
 *    - Notifica a Equipe Técnica (todos os técnicos cadastrados)
 *    - Notifica o Supervisor, Gestores e o Telefone do Chefe
 *    - Destaca: Técnico responsável e Laudo Técnico detalhado
 */
export async function notificarReparoFinalizado({ db = dbPadrao, enviarMensagem, telefoneChefe, maquina, ocorrencia }) {
  const chave = `finalizado_${ocorrencia?._id || ocorrencia?.id || maquina?.id}`;
  if (jaFoiNotificadoRecentemente(chave)) return;

  if (!ocorrencia && maquina?.id && db) {
    try {
      const snap = await db.collection('ocorrencias')
        .where('equipamentoId', '==', maquina.id)
        .limit(10)
        .get();
      if (!snap.empty) {
        const docs = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
        docs.sort((a, b) => new Date(b.dataFim || b.dataAbertura || 0) - new Date(a.dataFim || a.dataAbertura || 0));
        ocorrencia = docs.find((d) => {
          const s = String(d.status ?? '').toLowerCase();
          return s === 'finalizada' || s === '4' || s === '3';
        }) || docs[0];
      }
    } catch (e) {
      console.error('[mensagens.js] Falha ao recuperar ocorrência finalizada:', e?.message || e);
    }
  }

  const nome = maquina?.nome || ocorrencia?.equipamentoNome || 'Máquina';
  const tag = maquina?.tag || ocorrencia?.equipamentoTag || 'N/A';
  const localizacao = maquina?.localizacao || 'Chão de Fábrica';

  let tecFinalizou = ocorrencia?.tecnicoFinalizou ||
                     ocorrencia?.tecnicoResponsavel ||
                     maquina?.tecnicoFinalizou ||
                     maquina?.tecnicoResponsavel ||
                     ocorrencia?.tecnicoDesignado ||
                     maquina?.tecnicoDesignado;

  if (!tecFinalizou && Array.isArray(ocorrencia?.historico)) {
    const itemFin = [...ocorrencia.historico].reverse().find(
      (h) => h.tipo === 'finalizacao' || h.tipo === 'inicio'
    );
    if (itemFin?.por) tecFinalizou = itemFin.por;
  }
  if (!tecFinalizou) tecFinalizou = 'Técnico de Manutenção';

  let parecerTecnico = ocorrencia?.laudoTecnico ||
                       ocorrencia?.parecerTecnico ||
                       ocorrencia?.observacaoFinal ||
                       maquina?.laudoTecnico ||
                       maquina?.parecerTecnico ||
                       ocorrencia?.solucao;

  if (!parecerTecnico && Array.isArray(ocorrencia?.historico)) {
    const itemFin = [...ocorrencia.historico].reverse().find((h) => h.tipo === 'finalizacao');
    if (itemFin?.descricao) {
      parecerTecnico = itemFin.descricao.replace(/^Laudo Técnico de Liberação:\s*/i, '');
    }
  }
  if (!parecerTecnico || parecerTecnico.trim() === '') {
    parecerTecnico = 'Manutenção corretiva e preventiva concluída com sucesso. Equipamento testado e liberado para produção.';
  }

  let pecasTexto = '';
  if (Array.isArray(ocorrencia?.pecasTrocadas) && ocorrencia.pecasTrocadas.length > 0) {
    pecasTexto = ocorrencia.pecasTrocadas.join(', ');
  }

  const horario = new Date().toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });

  const mensagem = `✅ *SIGE - MANUTENÇÃO FINALIZADA E LIBERADA* 🏭\n\n` +
                   `A máquina *${nome}* (TAG: *${tag}*) teve seu conserto finalizado e já está liberada para operar normalmente!\n\n` +
                   `👷‍♂️ *Técnico Responsável (Assumiu e Finalizou):*\n` +
                   `👉 *${tecFinalizou}*\n\n` +
                   `📋 *PARECER TÉCNICO DE LIBERAÇÃO:*\n` +
                   `"${parecerTecnico.trim()}"\n\n` +
                   (pecasTexto ? `🔩 *Peças Substituídas:* ${pecasTexto}\n\n` : '') +
                   `📍 *Local:* ${localizacao}\n` +
                   `🕒 *Horário:* ${horario}\n` +
                   `🚀 *Status:* Operando 100% no chão de fábrica.`;

  const tecnicos = await buscarUsuariosPorPerfis(db, ['tecnico']);
  const lideranca = await buscarUsuariosPorPerfis(db, ['supervisor', 'gestor']);
  const telefones = [
    telefoneChefe,
    ...tecnicos.map((u) => u.telefone),
    ...lideranca.map((u) => u.telefone)
  ].filter(Boolean);

  console.log(`[WhatsApp] Notificando finalização da manutenção ${tag} para ${telefones.length} destinatário(s)...`);
  await enviarParaDestinatarios(enviarMensagem, telefones, mensagem);
}

/**
 * 5. Notifica o Supervisor e o Técnico Responsável quando o operador clica em "Solicitar Atendimento":
 */
export async function notificarSolicitacaoUrgente({ db = dbPadrao, enviarMensagem, telefoneChefe, maquina, ocorrencia, solicitante }) {
  const chaveThrottle = `urgencia_${ocorrencia?._id || ocorrencia?.id || maquina?.id}`;
  if (jaFoiNotificadoRecentemente(chaveThrottle)) return;

  const nome = maquina?.nome || ocorrencia?.equipamentoNome || 'Máquina';
  const tag = maquina?.tag || ocorrencia?.equipamentoTag || 'N/A';
  const localizacao = maquina?.localizacao || 'Chão de Fábrica';
  const motivo = ocorrencia?.motivo || ocorrencia?.descricao || maquina?.motivoParada || 'Parada operacional';
  const opNome = solicitante || ocorrencia?.solicitanteUrgencia || 'Operador de Produção';
  const tecResponsavel = ocorrencia?.tecnicoDesignado || ocorrencia?.tecnicoResponsavel || maquina?.tecnicoDesignado;
  const tecId = ocorrencia?.tecnicoDesignadoId || maquina?.tecnicoDesignadoId;
  const horario = new Date().toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });

  const mensagem = `🚨 *SIGE - SOLICITAÇÃO URGENTE DE ATENDIMENTO* 🚨\n\n` +
                   `Atenção! O operador *${opNome}* solicitou atendimento prioritário para a máquina *${nome}* (TAG: *${tag}*)!\n\n` +
                   `📍 *Localização:* ${localizacao}\n` +
                   `⚠️ *Motivo do Entrave:* ${motivo}\n` +
                   `🛠️ *Técnico Responsável:* ${tecResponsavel ? tecResponsavel : 'Pendente de atendimento'}\n` +
                   `⏰ *Horário:* ${horario}\n\n` +
                   `👉 *Ação imediata:* O supervisor e o técnico responsável devem atuar imediatamente para que o entrave seja resolvido o mais rápido possível!`;

  const telefones = new Set();
  if (telefoneChefe) telefones.add(telefoneChefe);

  const supervisores = await buscarUsuariosPorPerfis(db, ['supervisor']);
  supervisores.forEach((s) => s.telefone && telefones.add(s.telefone));

  if (tecId || tecResponsavel) {
    const tecUser = await buscarUsuarioPorIdOuNome(db, { id: tecId, nome: tecResponsavel });
    if (tecUser && tecUser.telefone) {
      telefones.add(tecUser.telefone);
    }
  } else {
    const tecnicos = await buscarUsuariosPorPerfis(db, ['tecnico']);
    tecnicos.forEach((t) => t.telefone && telefones.add(t.telefone));
  }

  console.log(`[WhatsApp] Disparando alerta de urgência da máquina ${tag} para ${telefones.size} destinatário(s)...`);
  await enviarParaDestinatarios(enviarMensagem, Array.from(telefones), mensagem);
}

/**
 * 6. Varre e notifica máquinas paradas há mais de 3 dias (72 horas)
 */
export async function verificarMaquinasParadas3Dias({ db = dbPadrao, enviarMensagem, telefoneChefe } = {}) {
  if (!db || typeof enviarMensagem !== 'function') return;

  try {
    const agora = Date.now();
    const snap = await db.collection('ocorrencias').get();

    for (const doc of snap.docs) {
      const o = doc.data();
      const status = (o.status ?? '').toString().toLowerCase();

      if (status === '4' || status === 'finalizada') continue;
      if (o.alerta3DiasEnviado === true) continue;

      let dataAberturaMs = null;
      if (o.dataAbertura) {
        if (typeof o.dataAbertura.toDate === 'function') {
          dataAberturaMs = o.dataAbertura.toDate().getTime();
        } else if (typeof o.dataAbertura === 'string') {
          dataAberturaMs = new Date(o.dataAbertura).getTime();
        }
      }

      if (!dataAberturaMs) continue;

      const diffHoras = (agora - dataAberturaMs) / (1000 * 60 * 60);
      const diffDias = Math.floor(diffHoras / 24);

      if (diffHoras >= 72) {
        const maquina = await buscarMaquina(db, { id: o.equipamentoId, tag: o.equipamentoTag });
        const nome = maquina?.nome || o.equipamentoNome || 'Máquina';
        const tag = maquina?.tag || o.equipamentoTag || 'N/A';
        const localizacao = maquina?.localizacao || 'Chão de Fábrica';
        const motivo = o.motivo || o.descricao || 'Parada não resolvida';
        const tec = o.tecnicoDesignado || o.tecnicoResponsavel || 'Nenhum técnico designado';
        const tecId = o.tecnicoDesignadoId;
        const dataFormatada = new Date(dataAberturaMs).toLocaleDateString('pt-BR');

        const mensagem = `⏰ *SIGE - ALERTA: MÁQUINA PARADA HÁ ${diffDias} DIAS* ⚠️\n\n` +
                         `Atenção! A máquina *${nome}* (TAG: *${tag}*) está parada há mais de *3 DIAS* (desde ${dataFormatada})!\n\n` +
                         `📌 *Motivo inicial:* ${motivo}\n` +
                         `📍 *Localização:* ${localizacao}\n` +
                         `🛠️ *Técnico Responsável:* ${tec}\n\n` +
                         `👉 *Cobrança de Resolução:* É necessária a ação prioritária do Supervisor e do Técnico Responsável para sanar o entrave técnico/material e restabelecer a operação da máquina o mais rápido possível!`;

        const telefones = new Set();
        if (telefoneChefe) telefones.add(telefoneChefe);

        const supervisores = await buscarUsuariosPorPerfis(db, ['supervisor']);
        supervisores.forEach((s) => s.telefone && telefones.add(s.telefone));

        if (tecId || tec) {
          const tecUser = await buscarUsuarioPorIdOuNome(db, { id: tecId, nome: tec });
          if (tecUser && tecUser.telefone) telefones.add(tecUser.telefone);
        }

        console.log(`[WhatsApp] ⏰ Disparando alerta de 3 dias parado para máquina ${tag}...`);
        await enviarParaDestinatarios(enviarMensagem, Array.from(telefones), mensagem);

        await doc.ref.update({
          alerta3DiasEnviado: true,
          dataAlerta3Dias: FieldValue.serverTimestamp()
        });
      }
    }
  } catch (err) {
    console.error('[mensagens.js] Erro ao verificar máquinas paradas há 3 dias:', err?.message || err);
  }
}

/**
 * Observador principal em tempo real de Ocorrências e Máquinas no Firestore
 */
export function observarOcorrencias({
  db = dbPadrao,
  enviarMensagem,
  telefoneChefe = process.env.TELEFONE_CHEFE,
  nomeColecaoOcorrencias = 'ocorrencias',
  nomeColecaoMaquinas = 'maquinas',
} = {}) {
  if (!db) {
    throw new Error('[mensagens.js] Instância do Firestore não fornecida para observarOcorrencias.');
  }

  const opcoes = { db, enviarMensagem, telefoneChefe };
  const ocorrenciasAnteriores = new Map();
  const maquinasAnteriores = new Map();

  let inicializadoOcorrencias = false;
  let inicializadoMaquinas = false;

  console.log('[mensagens.js] Monitor de ocorrências e máquinas iniciado com sucesso.');

  // 1. Escuta alterações na coleção 'ocorrencias'
  db.collection(nomeColecaoOcorrencias).onSnapshot(
    (snapshot) => {
      const docChanges = snapshot.docChanges();

      if (!inicializadoOcorrencias) {
        docChanges.forEach((change) => {
          ocorrenciasAnteriores.set(change.doc.id, change.doc.data());
        });
        inicializadoOcorrencias = true;
        return;
      }

      docChanges.forEach(async (change) => {
        const id = change.doc.id;
        const dados = change.doc.data();
        const ocorrencia = { _id: id, id, ...dados };
        const maquina = await buscarMaquina(db, { id: dados.equipamentoId, tag: dados.equipamentoTag });

        if (change.type === 'added') {
          ocorrenciasAnteriores.set(id, dados);
          const status = String(dados.status || '').toLowerCase();
          if (status !== 'finalizada' && status !== '3') {
            await notificarParadaMaquina({ ...opcoes, maquina, ocorrencia });
          }
        } else if (change.type === 'modified') {
          const anterior = ocorrenciasAnteriores.get(id) || {};
          ocorrenciasAnteriores.set(id, dados);

          const statusAtual = String(dados.status || '').toLowerCase();
          const statusAnt = String(anterior.status || '').toLowerCase();

          // Mudança para aguardandoMaterial
          if ((statusAtual === 'aguardandomaterial' || statusAtual === '2') && statusAnt !== statusAtual) {
            await notificarFaltaMaterial({ ...opcoes, maquina, ocorrencia });
          }

          // Designação de técnico
          const tecAtual = dados.tecnicoDesignado || dados.tecnicoDesignadoId;
          const tecAnt = anterior.tecnicoDesignado || anterior.tecnicoDesignadoId;
          if (tecAtual && tecAtual !== tecAnt) {
            let supervisorNome = 'Supervisor';
            if (Array.isArray(dados.historico) && dados.historico.length > 0) {
              const ultimoHistorico = dados.historico[dados.historico.length - 1];
              if (ultimoHistorico?.por) {
                supervisorNome = ultimoHistorico.por;
              }
            }
            await notificarDesignacaoTecnico({
              ...opcoes,
              maquina,
              ocorrencia,
              supervisorNome,
              tecnicoId: dados.tecnicoDesignadoId,
              tecnicoNome: dados.tecnicoDesignado
            });
          }

          // Finalização da ocorrência
          if ((statusAtual === 'finalizada' || statusAtual === '4' || statusAtual === '3') && statusAnt !== statusAtual) {
            await notificarReparoFinalizado({ ...opcoes, maquina, ocorrencia });
          }

          // Solicitação urgente
          if (dados.solicitarAtendimentoUrgente === true && anterior.solicitarAtendimentoUrgente !== true) {
            await notificarSolicitacaoUrgente({
              ...opcoes,
              maquina,
              ocorrencia,
              solicitante: dados.solicitanteUrgencia
            });
          }
        } else if (change.type === 'removed') {
          ocorrenciasAnteriores.delete(id);
        }
      });
    },
    (err) => console.error('[mensagens.js] Erro no listener de ocorrências:', err)
  );

  // 2. Escuta alterações na coleção 'maquinas'
  db.collection(nomeColecaoMaquinas).onSnapshot(
    (snapshot) => {
      const docChanges = snapshot.docChanges();

      if (!inicializadoMaquinas) {
        docChanges.forEach((change) => {
          maquinasAnteriores.set(change.doc.id, change.doc.data());
        });
        inicializadoMaquinas = true;
        return;
      }

      docChanges.forEach(async (change) => {
        const id = change.doc.id;
        const dados = change.doc.data();
        const maquina = { id, ...dados };

        if (change.type === 'modified') {
          const anterior = maquinasAnteriores.get(id) || {};
          maquinasAnteriores.set(id, dados);

          const statusAtual = String(dados.status || '').toLowerCase();
          const statusAnt = String(anterior.status || '').toLowerCase();

          if ((statusAtual === 'parada' || statusAtual === 'aguardandoaprovacao') &&
              (statusAnt !== 'parada' && statusAnt !== 'aguardandoaprovacao')) {
            await notificarParadaMaquina({ ...opcoes, maquina, ocorrencia: null });
          }

          if (statusAtual === 'aguardandomaterial' && statusAnt !== 'aguardandomaterial') {
            await notificarFaltaMaterial({ ...opcoes, maquina, ocorrencia: null });
          }

          const tecAtual = dados.tecnicoDesignado || dados.tecnicoDesignadoId;
          const tecAnt = anterior.tecnicoDesignado || anterior.tecnicoDesignadoId;
          if (tecAtual && tecAtual !== tecAnt && dados.aprovadaManutencao) {
            await notificarDesignacaoTecnico({
              ...opcoes,
              maquina,
              ocorrencia: null,
              supervisorNome: 'Supervisor',
              tecnicoId: dados.tecnicoDesignadoId,
              tecnicoNome: dados.tecnicoDesignado
            });
          }

          if (statusAtual === 'operando' && (statusAnt === 'manutencao' || statusAnt === 'aguardandomaterial')) {
            await notificarReparoFinalizado({ ...opcoes, maquina, ocorrencia: null });
          }

          if (dados.solicitarAtendimentoUrgente === true && anterior.solicitarAtendimentoUrgente !== true) {
            await notificarSolicitacaoUrgente({
              ...opcoes,
              maquina,
              ocorrencia: null,
              solicitante: dados.solicitanteUrgencia
            });
          }
        }
      });
    },
    (err) => console.error('[mensagens.js] Erro no listener de máquinas:', err)
  );

  setTimeout(() => verificarMaquinasParadas3Dias(opcoes), 5000);
  setInterval(() => verificarMaquinasParadas3Dias(opcoes), 30 * 60 * 1000);
}

export default {
  buscarMaquina,
  buscarUsuariosPorPerfis,
  buscarUsuarioPorIdOuNome,
  enviarParaDestinatarios,
  notificarParadaMaquina,
  notificarFaltaMaterial,
  notificarDesignacaoTecnico,
  notificarReparoFinalizado,
  notificarSolicitacaoUrgente,
  verificarMaquinasParadas3Dias,
  observarOcorrencias,
};
