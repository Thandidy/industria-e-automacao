// api/whatsapp.js
import { makeWASocket, useMultiFileAuthState, DisconnectReason, Browsers } from '@whiskeysockets/baileys';
import pino from 'pino';
import qrcode from 'qrcode';
import qrcodeTerminal from 'qrcode-terminal';
import fs from 'fs';
import path from 'path';
import os from 'os';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';
import { db, FieldValue } from './firebase.js';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Diretório de autenticação seguro: no Vercel (onde /var/task é Read-Only), usa /tmp
export function obterDiretorioAuth() {
  if (process.env.VERCEL || process.platform === 'linux') {
    const dir = path.join(os.tmpdir(), 'sige_auth_info');
    if (!fs.existsSync(dir)) {
      try { fs.mkdirSync(dir, { recursive: true }); } catch (_) {}
    }
    return dir;
  }
  const dir = path.resolve(process.cwd(), 'auth_info');
  if (!fs.existsSync(dir)) {
    try { fs.mkdirSync(dir, { recursive: true }); } catch (_) {}
  }
  return dir;
}

const TELEFONE_CHEFE_CONFIG = (process.env.TELEFONE_CHEFE || '').trim().replace(/['"]/g, '');
const CHEFE_DIGITOS = TELEFONE_CHEFE_CONFIG.replace(/\D/g, '');
const CHEFE_ULTIMOS_8 = CHEFE_DIGITOS.slice(-8);
const TELEFONE_CHEFE_JID = CHEFE_DIGITOS ? CHEFE_DIGITOS + '@s.whatsapp.net' : '';

const LID_CHEFE_CONFIG = (process.env.LID_CHEFE || '').trim().replace(/['"]/g, '');
const LID_CHEFE_ID = LID_CHEFE_CONFIG.split('@')[0].split(':')[0];

// Conjunto de LIDs do WhatsApp conhecidos do Chefe (carregado do .env e aprendido dinamicamente)
const lidsChefeConhecidos = new Set();
if (LID_CHEFE_ID) {
  lidsChefeConhecidos.add(LID_CHEFE_ID);
}

export function aprenderLidChefe(jid) {
  if (!jid) return;
  const id = jid.split('@')[0].split(':')[0];
  if (id && !lidsChefeConhecidos.has(id)) {
    lidsChefeConhecidos.add(id);
    console.log(`\n============================================================`);
    console.log(`🎯 [LID DO CHEFE IDENTIFICADO]: ${id}@lid`);
    console.log(`👉 Para fixar no Vercel ou .env, adicione:`);
    console.log(`LID_CHEFE=${id}@lid`);
    console.log(`============================================================\n`);
  }
}

let sockAtual = null;
let currentQRDataUrl = null;
let rawQRString = null;
let connectionStatus = 'disconnected'; // 'disconnected' | 'connecting' | 'waiting_qr' | 'connected'
let lastDisconnectReason = null;
let callbacksOnOpen = [];
let qrWaiters = [];

const cacheMsgParaSolicitacao = new Map();
const decisoesEmProcessamento = new Set();

function notificarWaiters() {
  const estado = getWhatsAppState();
  const waiters = [...qrWaiters];
  qrWaiters = [];
  waiters.forEach((resolve) => {
    try { resolve(estado); } catch (_) {}
  });
}

/**
 * Aguarda de forma assíncrona até que o QR Code seja gerado ou o socket conecte
 */
export function aguardarQRouConexao(timeoutMs = 9000) {
  if (currentQRDataUrl || connectionStatus === 'connected') {
    return Promise.resolve(getWhatsAppState());
  }

  return new Promise((resolve) => {
    let concluido = false;

    const wrappedResolve = (estado) => {
      if (!concluido) {
        concluido = true;
        resolve(estado);
      }
    };

    qrWaiters.push(wrappedResolve);

    setTimeout(() => {
      if (!concluido) {
        concluido = true;
        qrWaiters = qrWaiters.filter((w) => w !== wrappedResolve);
        resolve(getWhatsAppState());
      }
    }, timeoutMs);
  });
}

export function onWhatsAppOpen(cb) {
  if (connectionStatus === 'connected' && sockAtual) {
    try { cb(sockAtual); } catch (e) { console.error(e); }
  } else {
    callbacksOnOpen.push(cb);
  }
}

export function ehDoChefe(msgKey) {
  if (!msgKey) return false;
  const remetente = msgKey.remoteJid || '';
  const participant = msgKey.participant || '';

  const rLid = remetente.split('@')[0].split(':')[0];
  const pLid = participant.split('@')[0].split(':')[0];

  // 1. Checagem por LID do WhatsApp (configurado no .env ou auto-detectado dinamicamente)
  if (lidsChefeConhecidos.has(rLid) || lidsChefeConhecidos.has(pLid)) {
    return true;
  }

  // 2. Checagem por Telefone (últimos 8 dígitos ou número completo)
  const extrairDigitos = (jid) => (jid || '').split('@')[0].split(':')[0].replace(/\D/g, '');
  const rDigitos = extrairDigitos(remetente);
  const pDigitos = extrairDigitos(participant);

  if (CHEFE_ULTIMOS_8 && (rDigitos.endsWith(CHEFE_ULTIMOS_8) || pDigitos.endsWith(CHEFE_ULTIMOS_8))) {
    return true;
  }
  if (CHEFE_DIGITOS && (rDigitos === CHEFE_DIGITOS || pDigitos === CHEFE_DIGITOS)) {
    return true;
  }

  return false;
}

export function identificarAcao(textoOuEmoji) {
  if (!textoOuEmoji) return null;
  const valor = textoOuEmoji.trim().toLowerCase();

  if (/👍|✅|✔️|🆗|👏|🙌|💚|🟢/.test(valor)) return 'aprovar';
  if (/👎|❌|✖️|🚫|⛔|🔴/.test(valor)) return 'rejeitar';

  if (/^(aprovar|aprovado|aprova|aceitar|aceito|sim|ok)$/i.test(valor)) return 'aprovar';
  if (/^(rejeitar|rejeitado|rejeita|recusar|recuso|não|nao)$/i.test(valor)) return 'rejeitar';

  return null;
}

export async function processarDecisao({ solicitacaoId, whatsappMsgId, acao, remetenteJid, sock = sockAtual }) {
  const chaveTemporaria = solicitacaoId || whatsappMsgId;
  if (chaveTemporaria && decisoesEmProcessamento.has(chaveTemporaria)) return;
  if (chaveTemporaria) {
    decisoesEmProcessamento.add(chaveTemporaria);
    setTimeout(() => decisoesEmProcessamento.delete(chaveTemporaria), 10000);
  }

  try {
    let docRef = null;
    let docSnap = null;

    if (solicitacaoId) {
      docRef = db.collection('solicitacoes_login').doc(solicitacaoId);
      docSnap = await docRef.get();
    }

    if ((!docSnap || !docSnap.exists) && whatsappMsgId && cacheMsgParaSolicitacao.has(whatsappMsgId)) {
      const idCache = cacheMsgParaSolicitacao.get(whatsappMsgId);
      docRef = db.collection('solicitacoes_login').doc(idCache);
      docSnap = await docRef.get();
    }

    if ((!docSnap || !docSnap.exists) && whatsappMsgId) {
      const consulta = await db.collection('solicitacoes_login')
        .where('whatsappMsgId', '==', whatsappMsgId)
        .limit(1)
        .get();

      if (!consulta.empty) {
        docSnap = consulta.docs[0];
        docRef = docSnap.ref;
      }
    }

    if (!docSnap || !docSnap.exists) {
      console.log(`[Aviso] Solicitação não localizada para ID=${solicitacaoId || 'N/A'}, MsgId=${whatsappMsgId || 'N/A'}`);
      if (remetenteJid && sock) {
        await sock.sendMessage(remetenteJid, {
          text: `❌ Não foi possível localizar a solicitação correspondente a esta ação.`
        });
      }
      return;
    }

    const id = docSnap.id;
    if (decisoesEmProcessamento.has(id)) return;
    decisoesEmProcessamento.add(id);
    setTimeout(() => decisoesEmProcessamento.delete(id), 10000);

    const dados = docSnap.data();
    const nome = dados.nome || dados.nomeFuncionario || 'Usuário';

    if (dados.status !== 'pendente') {
      const msgStatus = `ℹ️ A solicitação de *${nome}* já foi *${dados.status}* anteriormente.`;
      console.log(`[Info] ${msgStatus}`);
      if (remetenteJid && sock) {
        await sock.sendMessage(remetenteJid, { text: msgStatus });
      }
      return;
    }

    const novoStatus = acao === 'aprovar' ? 'aprovado' : 'rejeitado';

    await docRef.update({
      status: novoStatus,
      respondidoEm: FieldValue.serverTimestamp()
    });

    if (novoStatus === 'aprovado') {
      await db.collection('usuarios').doc(id).set({
        nome: nome,
        email: dados.email,
        telefone: dados.telefone || '',
        perfil: dados.perfil || 'operador',
        senha: dados.senha,
        status: 'aprovado',
        criadoEm: dados.criadoEm || new Date().toISOString(),
        ultimoLogin: new Date().toISOString()
      });

      console.log(`[Sucesso] ✅ Usuário ${nome} (${id}) APROVADO e adicionado em 'usuarios'!`);
      if (remetenteJid && sock) {
        await sock.sendMessage(remetenteJid, {
          text: `👍 Solicitação de *${nome}* foi *APROVADA* com sucesso!\nUsuário liberado para acessar o SIGE.`
        });
      }

      if (dados.telefone) {
        const msgBoasVindas = `🎉 *ACESSO APROVADO - SIGE INDUSTRIAL*\n\n` +
                              `Olá, *${nome}*! 👋\n` +
                              `Sua solicitação de acesso ao sistema *SIGE* foi *APROVADA* com sucesso pelo gestor!\n\n` +
                              `🏷️ *Perfil Autorizado:* ${dados.perfil || 'Operador'}\n` +
                              `📧 *Login:* ${dados.email}\n\n` +
                              `👉 Você já pode abrir o aplicativo e fazer login com sua senha cadastrada. Bom trabalho!`;

        await enviarMensagemWhatsApp(dados.telefone, msgBoasVindas);
      }
    } else {
      console.log(`[Sucesso] ❌ Solicitação de ${nome} (${id}) REJEITADA.`);
      if (remetenteJid && sock) {
        await sock.sendMessage(remetenteJid, {
          text: `❌ A solicitação de *${nome}* foi *REJEITADA*.`
        });
      }

      if (dados.telefone) {
        const msgRejeitado = `❌ *SOLICITAÇÃO DE ACESSO - SIGE*\n\n` +
                             `Olá, *${nome}*.\n` +
                             `Informamos que sua solicitação de acesso ao sistema SIGE foi analisada e *rejeitada* pela gestão.\n` +
                             `Em caso de dúvidas, procure o seu supervisor imediato.`;
        await enviarMensagemWhatsApp(dados.telefone, msgRejeitado);
      }
    }
  } catch (error) {
    console.error('Erro ao processar decisão no Firestore:', error);
  }
}

export async function enviarMensagemWhatsApp(destinatario, mensagem) {
  if (!sockAtual || connectionStatus !== 'connected') {
    console.warn('[WhatsApp] Tentativa de envio com WhatsApp desconectado.');
    return { sucesso: false, erro: 'WhatsApp não está conectado' };
  }

  let jid = destinatario;
  if (!jid) {
    jid = TELEFONE_CHEFE_JID;
  } else if (jid.endsWith('@s.whatsapp.net') || jid.endsWith('@lid')) {
    // formato ok
  } else {
    let digitos = jid.replace(/\D/g, '');
    if (digitos.length === 10 || digitos.length === 11) {
      digitos = '55' + digitos;
    }
    jid = digitos + '@s.whatsapp.net';
  }

  try {
    const sent = await sockAtual.sendMessage(jid, { text: mensagem });
    console.log(`[WhatsApp] Mensagem enviada com sucesso para ${jid}`);
    return { sucesso: true, messageId: sent?.key?.id };
  } catch (error) {
    console.error(`[WhatsApp] Falha ao enviar para ${jid}:`, error?.message || error);
    return { sucesso: false, erro: error?.message || String(error) };
  }
}

export async function connectToWhatsApp({ printTerminal = false, authFolder = null } = {}) {
  if (sockAtual && connectionStatus === 'connected') {
    return sockAtual;
  }

  const pastaFinalAuth = authFolder || obterDiretorioAuth();
  connectionStatus = 'connecting';

  try {
    const { state, saveCreds } = await useMultiFileAuthState(pastaFinalAuth);

    const sock = makeWASocket({
      auth: state,
      printQRInTerminal: false,
      logger: pino({ level: 'silent' }),
      browser: Browsers.windows('Desktop'),
      syncFullHistory: false,
      defaultQueryTimeoutMs: 60000,
      keepAliveIntervalMs: 25000,
      connectTimeoutMs: 45000
    });

    sockAtual = sock;

    sock.ev.on('connection.update', async (update) => {
      const { connection, lastDisconnect, qr } = update;

      if (qr) {
        rawQRString = qr;
        connectionStatus = 'waiting_qr';
        try {
          currentQRDataUrl = await qrcode.toDataURL(qr, { margin: 2, scale: 8 });
        } catch (_) {}

        if (printTerminal) {
          console.log('\n📷 Escaneie o QR Code abaixo com o seu WhatsApp:');
          qrcodeTerminal.generate(qr, { small: true });
        }

        notificarWaiters();
      }

      if (connection === 'close') {
        const statusCode = lastDisconnect?.error?.output?.statusCode || lastDisconnect?.error?.code;
        lastDisconnectReason = statusCode;
        const shouldReconnect = statusCode !== DisconnectReason.loggedOut;

        connectionStatus = 'disconnected';
        currentQRDataUrl = null;
        rawQRString = null;

        try {
          sock.ev.removeAllListeners();
          sock.end?.();
        } catch (_) {}

        if (shouldReconnect) {
          console.log(`[WhatsApp] Reconectando em 2s... (código: ${statusCode})`);
          setTimeout(() => connectToWhatsApp({ printTerminal, authFolder: pastaFinalAuth }), 2000);
        } else {
          console.log('❌ Sessão desconectada ou credenciais revogadas pelo WhatsApp.');
          if (fs.existsSync(pastaFinalAuth)) {
            try { fs.rmSync(pastaFinalAuth, { recursive: true, force: true }); } catch (_) {}
          }
        }

        notificarWaiters();
      } else if (connection === 'open') {
        console.log('✅ WhatsApp conectado com sucesso e pronto!');
        connectionStatus = 'connected';
        currentQRDataUrl = null;
        rawQRString = null;

        const callbacks = [...callbacksOnOpen];
        callbacksOnOpen = [];
        callbacks.forEach((cb) => {
          try { cb(sock); } catch (e) { console.error(e); }
        });

        notificarWaiters();
      }
    });

    sock.ev.on('creds.update', saveCreds);

    // 1. Escuta REAÇÕES com emojis (👍, 👎, ✅, ❌)
    sock.ev.on('messages.reaction', async (reactions) => {
      for (const item of reactions) {
        const { key, reaction } = item;
        const targetMsgId = key?.id;
        const emoji = reaction?.text;

        if (!emoji || !targetMsgId) continue;

        const acao = identificarAcao(emoji);
        if (!acao) continue;

        // Se a reação foi feita em uma mensagem enviada pelo bot ao chefe sobre uma solicitação
        let ehMsgDeSolicitacao = cacheMsgParaSolicitacao.has(targetMsgId);
        if (!ehMsgDeSolicitacao) {
          try {
            const snap = await db.collection('solicitacoes_login')
              .where('whatsappMsgId', '==', targetMsgId)
              .limit(1)
              .get();
            if (!snap.empty) {
              ehMsgDeSolicitacao = true;
              cacheMsgParaSolicitacao.set(targetMsgId, snap.docs[0].id);
            }
          } catch (_) {}
        }

        // Se é uma mensagem que o bot enviou para aprovação, a reação SÓ PODE vir do chefe!
        const autorizado = ehDoChefe(key) || ehMsgDeSolicitacao;

        if (autorizado) {
          aprenderLidChefe(key.remoteJid);
          if (key.participant) aprenderLidChefe(key.participant);

          console.log(`[Reação Detectada] Emoji "${emoji}" -> Ação: ${acao} na msg ${targetMsgId} (De: ${key.remoteJid})`);

          await processarDecisao({
            whatsappMsgId: targetMsgId,
            acao,
            remetenteJid: key.remoteJid,
            sock
          });
        } else {
          console.log(`[Reação ignorada] Emoji "${emoji}" na msg ${targetMsgId} de ${key.remoteJid}${key.participant ? ' (Part: ' + key.participant + ')' : ''} (Não pertence a solicitação ativa nem bate com o chefe)`);
        }
      }
    });

    // 2. Escuta MENSAGENS recebidas
    sock.ev.on('messages.upsert', async (m) => {
      if (m.type !== 'notify') return;

      for (const msg of m.messages) {
        if (!msg.message) continue;
        const remetente = msg.key.remoteJid;

        if (msg.message.reactionMessage) continue;
        if (msg.key.fromMe) continue;

        const quotedMsgId = msg.message.extendedTextMessage?.contextInfo?.stanzaId;
        const textoMensagem = msg.message.conversation || msg.message.extendedTextMessage?.text || '';
        const textoLimpo = textoMensagem.replace(/[*_~`]/g, '').trim();

        if (!textoLimpo) continue;

        const matchComando = textoLimpo.match(/^(aprovar|rejeitar)\s+(.+)$/i);
        const acaoCitada = identificarAcao(textoLimpo);

        // Verifica se está citando uma mensagem de solicitação pendente enviada ao chefe
        let citaSolicitacao = false;
        if (quotedMsgId) {
          if (cacheMsgParaSolicitacao.has(quotedMsgId)) {
            citaSolicitacao = true;
          } else {
            try {
              const snap = await db.collection('solicitacoes_login')
                .where('whatsappMsgId', '==', quotedMsgId)
                .limit(1)
                .get();
              if (!snap.empty) {
                citaSolicitacao = true;
                cacheMsgParaSolicitacao.set(quotedMsgId, snap.docs[0].id);
              }
            } catch (_) {}
          }
        }

        const autorizado = ehDoChefe(msg.key) || citaSolicitacao;
        if (!autorizado) {
          console.log(`[Mensagem Recebida] De: ${remetente}${msg.key.participant ? ' (Participante: ' + msg.key.participant + ')' : ''} | Texto: "${textoLimpo}" | Ignorada pois não corresponde ao chefe (Esperado Tel=${CHEFE_DIGITOS})`);
          continue;
        }

        aprenderLidChefe(remetente);
        if (msg.key.participant) aprenderLidChefe(msg.key.participant);

        console.log(`[Mensagem do Chefe] "${textoLimpo}" de ${remetente}`);

        if (matchComando) {
          const acao = matchComando[1].toLowerCase();
          const solicitacaoId = matchComando[2].trim();
          await processarDecisao({ solicitacaoId, acao, remetenteJid: remetente, sock });
          continue;
        }

        if (quotedMsgId && acaoCitada) {
          await processarDecisao({ whatsappMsgId: quotedMsgId, acao: acaoCitada, remetenteJid: remetente, sock });
          continue;
        }

        if (acaoCitada) {
          await sock.sendMessage(remetente, {
            text: `ℹ️ Para responder por texto, cite a mensagem da solicitação ou informe o ID junto:\nExemplo: *${acaoCitada} ID_DA_SOLICITACAO*\nOu simplesmente reaja à mensagem da solicitação com 👍 ou ❌.`
          });
        }
      }
    });

    return sock;
  } catch (err) {
    console.error('[WhatsApp] Erro ao inicializar socket Baileys:', err);
    connectionStatus = 'disconnected';
    notificarWaiters();
    return null;
  }
}

export function getWhatsAppState() {
  return {
    sock: sockAtual,
    status: connectionStatus,
    hasQR: !!currentQRDataUrl,
    qrDataUrl: currentQRDataUrl,
    rawQR: rawQRString,
    lastDisconnectReason,
    telefoneChefe: TELEFONE_CHEFE_CONFIG,
    lidChefe: LID_CHEFE_CONFIG,
    cacheMsgParaSolicitacao
  };
}

export default {
  connectToWhatsApp,
  enviarMensagemWhatsApp,
  getWhatsAppState,
  onWhatsAppOpen,
  processarDecisao,
  ehDoChefe,
  identificarAcao,
  aguardarQRouConexao,
  obterDiretorioAuth
};
