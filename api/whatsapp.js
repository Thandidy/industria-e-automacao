// api/whatsapp.js
import { makeWASocket, useMultiFileAuthState, DisconnectReason, Browsers } from '@whiskeysockets/baileys';
import pino from 'pino';
import qrcode from 'qrcode';
import qrcodeTerminal from 'qrcode-terminal';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';
import { db, FieldValue } from './firebase.js';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Configuração flexível do telefone e LID do Chefe
const TELEFONE_CHEFE_CONFIG = (process.env.TELEFONE_CHEFE || '').trim().replace(/['"]/g, '');
const CHEFE_DIGITOS = TELEFONE_CHEFE_CONFIG.replace(/\D/g, '');
const CHEFE_ULTIMOS_8 = CHEFE_DIGITOS.slice(-8);
const TELEFONE_CHEFE_JID = CHEFE_DIGITOS ? CHEFE_DIGITOS + '@s.whatsapp.net' : '';

const LID_CHEFE_CONFIG = (process.env.LID_CHEFE || '').trim().replace(/['"]/g, '');
const LID_CHEFE_ID = LID_CHEFE_CONFIG.split('@')[0].split(':')[0];

let sockAtual = null;
let currentQRDataUrl = null;
let rawQRString = null;
let connectionStatus = 'disconnected'; // 'disconnected' | 'connecting' | 'waiting_qr' | 'connected'
let lastDisconnectReason = null;
let callbacksOnOpen = [];

const cacheMsgParaSolicitacao = new Map();
const decisoesEmProcessamento = new Set();

export function onWhatsAppOpen(cb) {
  if (connectionStatus === 'connected' && sockAtual) {
    try { cb(sockAtual); } catch (e) { console.error(e); }
  } else {
    callbacksOnOpen.push(cb);
  }
}

export function ehDoChefe(msgKey) {
  const remetente = msgKey.remoteJid || '';
  const participant = msgKey.participant || '';

  if (LID_CHEFE_ID) {
    const rLid = remetente.split('@')[0].split(':')[0];
    const pLid = participant.split('@')[0].split(':')[0];
    if (rLid === LID_CHEFE_ID || pLid === LID_CHEFE_ID) return true;
  }

  if (CHEFE_ULTIMOS_8) {
    const extrairDigitos = (jid) => (jid || '').split('@')[0].split(':')[0].replace(/\D/g, '');
    const rDigitos = extrairDigitos(remetente);
    const pDigitos = extrairDigitos(participant);
    if (rDigitos.endsWith(CHEFE_ULTIMOS_8) || pDigitos.endsWith(CHEFE_ULTIMOS_8)) return true;
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
    // formato já ok
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

export async function connectToWhatsApp({ printTerminal = false, authFolder = 'auth_info' } = {}) {
  if (sockAtual && connectionStatus === 'connected') {
    return sockAtual;
  }

  connectionStatus = 'connecting';
  const { state, saveCreds } = await useMultiFileAuthState(authFolder);

  const sock = makeWASocket({
    auth: state,
    printQRInTerminal: false,
    logger: pino({ level: 'error' }),
    browser: Browsers.windows('Desktop'),
    syncFullHistory: false,
    defaultQueryTimeoutMs: 60000,
    keepAliveIntervalMs: 30000
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
        console.log('📷 Escaneie o QR Code abaixo com o seu WhatsApp:');
        qrcodeTerminal.generate(qr, { small: true });
      }
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
        console.log(`[WhatsApp] Reconectando em 3s... (código: ${statusCode})`);
        setTimeout(() => connectToWhatsApp({ printTerminal, authFolder }), 3000);
      } else {
        console.log('❌ Sessão desconectada ou credenciais revogadas pelo WhatsApp.');
        if (fs.existsSync(authFolder)) {
          try { fs.rmSync(authFolder, { recursive: true, force: true }); } catch (_) {}
        }
      }
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
    }
  });

  sock.ev.on('creds.update', saveCreds);

  // Escuta Reações de Emojis
  sock.ev.on('messages.reaction', async (reactions) => {
    for (const item of reactions) {
      const { key, reaction } = item;
      const targetMsgId = key?.id;
      const emoji = reaction?.text;

      if (!emoji || !targetMsgId) continue;
      if (!ehDoChefe(key)) continue;

      const acao = identificarAcao(emoji);
      if (!acao) continue;

      console.log(`[Reação Detectada] Emoji "${emoji}" -> Ação: ${acao} na msg ${targetMsgId}`);

      await processarDecisao({
        whatsappMsgId: targetMsgId,
        acao,
        remetenteJid: key.remoteJid,
        sock
      });
    }
  });

  // Escuta Mensagens Recebidas
  sock.ev.on('messages.upsert', async (m) => {
    if (m.type !== 'notify') return;

    for (const msg of m.messages) {
      if (!msg.message) continue;
      const remetente = msg.key.remoteJid;

      if (msg.message.reactionMessage) continue;
      if (msg.key.fromMe) continue;
      if (!ehDoChefe(msg.key)) continue;

      const textoMensagem = msg.message.conversation || msg.message.extendedTextMessage?.text || '';
      const textoLimpo = textoMensagem.replace(/[*_~`]/g, '').trim();
      if (!textoLimpo) continue;

      console.log(`[Mensagem do Chefe] "${textoLimpo}" de ${remetente}`);

      const matchComando = textoLimpo.match(/^(aprovar|rejeitar)\s+(.+)$/i);
      if (matchComando) {
        const acao = matchComando[1].toLowerCase();
        const solicitacaoId = matchComando[2].trim();
        await processarDecisao({ solicitacaoId, acao, remetenteJid: remetente, sock });
        continue;
      }

      const quotedMsgId = msg.message.extendedTextMessage?.contextInfo?.stanzaId;
      const acaoCitada = identificarAcao(textoLimpo);

      if (quotedMsgId && acaoCitada) {
        await processarDecisao({ whatsappMsgId: quotedMsgId, acao: acaoCitada, remetenteJid: remetente, sock });
        continue;
      }

      if (acaoCitada) {
        await sock.sendMessage(remetente, {
          text: `ℹ️ Para responder por texto, informe o ID junto:\nExemplo: *${acaoCitada} ID_DA_SOLICITACAO*\nOu simplesmente reaja à mensagem da solicitação com 👍 ou ❌.`
        });
      }
    }
  });

  return sock;
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
  identificarAcao
};
