// api/whatsapp.js
// Comunicação via Firestore como ponte em tempo real.
// QR Code exibido APENAS no terminal; Flutter mostra só o status.

import {
  makeWASocket,
  useMultiFileAuthState,
  DisconnectReason,
  Browsers,
} from '@whiskeysockets/baileys';
import pino from 'pino';
import qrcodeTerminal from 'qrcode-terminal';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';
import os from 'os';
import { db, FieldValue } from './firebase.js';
import { enviarEmail, gerarTemplateNotificacao } from './email.js';

dotenv.config();

// ---------------------------------------------------------------------------
// Firestore – referências
// ---------------------------------------------------------------------------
const CONFIG_REF = db.collection('config').doc('whatsapp');

/** Verifica rapidamente se o Firestore está acessível antes de criar watchers */
async function validarConexaoFirestore() {
  try {
    await db.collection('sige_ping').doc('test').get();
    console.log('[Firestore] Conexão OK');
    return true;
  } catch (e) {
    console.error('[Firestore] Falha ao conectar:', e.message);
    return false;
  }
}

/** Atualiza o documento de estado do WhatsApp no Firestore */
async function atualizarEstado({ status, reiniciarSessao = undefined } = {}) {
  try {
    const data = {
      status,
      ultimaAtualizacao: FieldValue.serverTimestamp(),
    };
    if (reiniciarSessao !== undefined) data.reiniciarSessao = reiniciarSessao;
    await CONFIG_REF.set(data, { merge: true });
  } catch (e) {
    console.error('[Firestore] Erro ao atualizar estado:', e.message);
  }
}

// ---------------------------------------------------------------------------
// Auth local
// ---------------------------------------------------------------------------
function obterDiretorioAuth() {
  const dir = process.env.VERCEL || process.platform === 'linux'
    ? path.join(os.tmpdir(), 'sige_auth_info')
    : path.resolve(process.cwd(), 'auth_info');

  if (!fs.existsSync(dir)) {
    try { fs.mkdirSync(dir, { recursive: true }); } catch (_) {}
  }
  return dir;
}

async function limparAuthLocal() {
  const dir = obterDiretorioAuth();
  try { fs.rmSync(dir, { recursive: true, force: true }); } catch (_) {}
  console.log('[WhatsApp] auth_info removido');
}

// ---------------------------------------------------------------------------
// Estado runtime
// ---------------------------------------------------------------------------
let sock = null;
let connectionStatus = 'disconnected';
let reconectando = false;
let cacheMsgParaSolicitacao = new Map();

export function getWhatsAppState() {
  return { sock, status: connectionStatus, cacheMsgParaSolicitacao };
}

// ---------------------------------------------------------------------------
// Envio de mensagem
// ---------------------------------------------------------------------------
export async function enviarMensagemWhatsApp(destinatario, mensagem) {
  if (!sock || connectionStatus !== 'connected') {
    console.warn('[WhatsApp] Tentativa de envio sem conexão ativa');
    return { sucesso: false, erro: 'WhatsApp não está conectado' };
  }

  let jid = destinatario;
  if (!jid) {
    const tel = (process.env.TELEFONE_CHEFE || '').trim().replace(/['"]+/g, '');
    const digitos = tel.replace(/\D/g, '');
    jid = digitos ? `${digitos}@s.whatsapp.net` : null;
  } else if (!jid.endsWith('@s.whatsapp.net') && !jid.endsWith('@lid')) {
    const digitos = jid.replace(/\D/g, '');
    const numero = (digitos.length === 10 || digitos.length === 11)
      ? `55${digitos}` : digitos;
    jid = `${numero}@s.whatsapp.net`;
  }

  if (!jid) return { sucesso: false, erro: 'Destinatário inválido' };

  try {
    const sent = await sock.sendMessage(jid, { text: mensagem });
    console.log(`[WhatsApp] Mensagem enviada para ${jid}`);
    return { sucesso: true, messageId: sent?.key?.id };
  } catch (e) {
    console.error(`[WhatsApp] Falha ao enviar para ${jid}:`, e?.message || e);
    return { sucesso: false, erro: e?.message || String(e) };
  }
}

// ---------------------------------------------------------------------------
// Desconexão
// ---------------------------------------------------------------------------
async function desconectarCliente() {
  if (sock) {
    try { await sock.logout(); } catch (_) {}
    sock = null;
  }
  connectionStatus = 'disconnected';
  await atualizarEstado({ status: 'desconectado' });
}

// ---------------------------------------------------------------------------
// Conexão principal
// ---------------------------------------------------------------------------
export async function conectarCliente() {
  if (reconectando) return;
  reconectando = true;

  try {
    const authFolder = obterDiretorioAuth();
    const { state, saveCreds } = await useMultiFileAuthState(authFolder);

    sock = makeWASocket({
      auth: state,
      logger: pino({ level: 'silent' }),
      browser: Browsers.windows('Desktop'),
      syncFullHistory: false,
      defaultQueryTimeoutMs: 60_000,
      keepAliveIntervalMs: 25_000,
      connectTimeoutMs: 60_000,
    });

    // ── Eventos de conexão ──────────────────────────────────────────────
    sock.ev.on('connection.update', async (update) => {
      const { connection, lastDisconnect, qr } = update;

      if (qr) {
        connectionStatus = 'waiting_qr';
        await atualizarEstado({ status: 'aguardando_qr' });
        console.log('\n====================================================');
        console.log('📱 ESCANEIE O QR CODE ABAIXO COM SEU WHATSAPP:');
        console.log('====================================================');
        qrcodeTerminal.generate(qr, { small: true });
        console.log('====================================================\n');
      }

      if (connection === 'open') {
        connectionStatus = 'connected';
        reconectando = false;
        await atualizarEstado({ status: 'conectado' });
        console.log('[WhatsApp] ✅ Conectado ao WhatsApp');

        // Notifica o chefe sobre a inicialização do bot
        try {
          const agora = new Date().toLocaleString('pt-BR', { timeZone: 'America/Sao_Paulo' });
          const msgBoasVindas = `🟢 *SIGE INDUSTRIAL - BOT ONLINE*\n\n` +
                                `Olá! O bot do WhatsApp foi conectado e está 100% operacional.\n` +
                                `📅 *Data/Hora:* ${agora}\n` +
                                `⚙️ *Status:* Monitoramento de solicitações, aprovações e máquinas ativo!`;
          await enviarMensagemWhatsApp(process.env.TELEFONE_CHEFE, msgBoasVindas);
        } catch (errNotif) {
          console.error('[WhatsApp] Falha ao enviar aviso de conexão para o chefe:', errNotif?.message || errNotif);
        }
      }

      if (connection === 'close') {
        const statusCode = lastDisconnect?.error?.output?.statusCode;
        const badMac = lastDisconnect?.error?.message?.includes('Bad MAC');
        const loggedOut = statusCode === DisconnectReason.loggedOut;

        connectionStatus = 'disconnected';
        reconectando = false;
        await atualizarEstado({ status: 'desconectado' });
        console.warn(`[WhatsApp] Conexão encerrada – código: ${statusCode}`);

        if (badMac || loggedOut) {
          // Sessão corrompida ou deslogado: limpa auth e reconecta do zero
          console.warn('[WhatsApp] Limpando sessão e reconectando...');
          await limparAuthLocal();
          setTimeout(conectarCliente, 3_000);
        } else {
          // Queda temporária: tenta reconectar
          setTimeout(conectarCliente, 5_000);
        }
      }
    });

    // ── Mensagens e Reações recebidas ─────────────────────────────────
    sock.ev.on('messages.upsert', async ({ messages }) => {
      for (const m of messages) {
        if (!m.message || m.key.fromMe) continue;
        const de = m.key.remoteJid;
        const texto =
          m.message?.conversation ??
          m.message?.extendedTextMessage?.text ??
          '';

        // Trata reação recebida (ex: 👍, ✅, 👎, ❌)
        const reacao = m.message?.reactionMessage;

        // 1. Salva na coleção 'mensagens' (espelho Firestore)
        try {
          await db.collection('mensagens').add({
            de,
            texto: texto || (reacao ? `[Reação: ${reacao.text}]` : '[mídia ou não-texto]'),
            timestamp: FieldValue.serverTimestamp(),
          });
        } catch (e) {
          console.error('[Firestore] Erro ao salvar mensagem:', e.message);
        }

        const telefoneChefeConfig = (process.env.TELEFONE_CHEFE || '').trim().replace(/\D/g, '');
        const deChefe = de && telefoneChefeConfig && de.includes(telefoneChefeConfig);
        if (!deChefe) continue;

        // 2.A. Decisão por REAÇÃO direta na mensagem do bot
        if (reacao && reacao.text) {
          const emoji = reacao.text.trim();
          const targetMsgId = reacao.key?.id;

          const emojiAprova = ['👍', '✅', '👌', '👏', '🟢'].includes(emoji);
          const emojiRejeita = ['👎', '❌', '🚫', '🛑', '🔴'].includes(emoji);

          if (emojiAprova || emojiRejeita) {
            try {
              let idSolicitacao = null;

              // Tenta achar pelo whatsappMsgId vinculado à mensagem reagida
              if (targetMsgId) {
                const snapMsg = await db.collection('solicitacoes_login')
                  .where('whatsappMsgId', '==', targetMsgId)
                  .where('status', 'in', ['pendente', 'aguardando'])
                  .limit(1)
                  .get();

                if (!snapMsg.empty) {
                  idSolicitacao = snapMsg.docs[0].id;
                }
              }

              // Se não encontrou pelo ID específico, pega a pendente mais recente
              if (!idSolicitacao) {
                const snapRecente = await db.collection('solicitacoes_login')
                  .where('status', 'in', ['pendente', 'aguardando'])
                  .orderBy('criadoEm', 'desc')
                  .limit(1)
                  .get();
                if (!snapRecente.empty) {
                  idSolicitacao = snapRecente.docs[0].id;
                }
              }

              if (idSolicitacao) {
                const acao = emojiAprova ? 'aprovar' : 'rejeitar';
                console.log(`[WhatsApp Reação] Chefe reagiu ${emoji} -> Executando ${acao} na solicitação ${idSolicitacao}`);

                const { default: handlerDecidir } = await import('./decidir.js');
                const reqMock = { query: { id: idSolicitacao, acao }, headers: { accept: 'application/json' } };
                const resMock = {
                  setHeader: () => {},
                  status: () => ({ json: () => {}, send: () => {}, end: () => {} }),
                };
                await handlerDecidir(reqMock, resMock);

                const msgConfirmacao = emojiAprova
                  ? `✅ Solicitação autorizada via reação (${emoji})!`
                  : `❌ Solicitação recusada via reação (${emoji}) e removida.`;
                await enviarMensagemWhatsApp(process.env.TELEFONE_CHEFE, msgConfirmacao);
              }
            } catch (errReacao) {
              console.error('[WhatsApp Reação] Erro ao processar reação do chefe:', errReacao);
            }
          }
        }

        // 2.B. Decisão por TEXTO (ex: "aprovar", "sim", "rejeitar", "não")
        if (texto) {
          const textoLimpo = texto.trim().toLowerCase();
          const ehAprovacao = textoLimpo === 'aprovar' || textoLimpo === 'aprovado' || textoLimpo === 'sim' || textoLimpo.startsWith('aprovar');
          const ehRejeicao = textoLimpo === 'rejeitar' || textoLimpo === 'rejeitado' || textoLimpo === 'nao' || textoLimpo === 'não' || textoLimpo.startsWith('rejeitar');

          if (ehAprovacao || ehRejeicao) {
            try {
              const snap = await db.collection('solicitacoes_login')
                .where('status', 'in', ['pendente', 'aguardando'])
                .orderBy('criadoEm', 'desc')
                .limit(1)
                .get();

              if (!snap.empty) {
                const docSolicitacao = snap.docs[0];
                const idSolicitacao = docSolicitacao.id;
                const acao = ehAprovacao ? 'aprovar' : 'rejeitar';

                console.log(`[WhatsApp Decisão] Chefe respondeu "${texto}" -> Executando ${acao} no ID ${idSolicitacao}`);

                const { default: handlerDecidir } = await import('./decidir.js');
                const reqMock = { query: { id: idSolicitacao, acao }, headers: { accept: 'application/json' } };
                const resMock = {
                  setHeader: () => {},
                  status: () => ({ json: () => {}, send: () => {}, end: () => {} }),
                };
                await handlerDecidir(reqMock, resMock);

                const msgConfirmacao = ehAprovacao
                  ? `✅ Cadastro de *${docSolicitacao.data().nome || 'Colaborador'}* foi *APROVADO* com sucesso!`
                  : `❌ Solicitação de *${docSolicitacao.data().nome || 'Colaborador'}* foi *REJEITADA* e removida.`;
                await enviarMensagemWhatsApp(process.env.TELEFONE_CHEFE, msgConfirmacao);
              }
            } catch (errDecisao) {
              console.error('[WhatsApp Decisão] Erro ao processar resposta do chefe:', errDecisao);
            }
          }
        }
      }
    });

    // ── Credenciais ─────────────────────────────────────────────────────
    sock.ev.on('creds.update', saveCreds);

  } catch (e) {
    reconectando = false;
    console.error('[WhatsApp] Erro ao conectar:', e?.message || e);
    await atualizarEstado({ status: 'desconectado' });
    setTimeout(conectarCliente, 10_000);
  }
}

// ---------------------------------------------------------------------------
// Listeners Firestore
// ---------------------------------------------------------------------------

/** Reinicia sessão quando a flag é ativada pelo Flutter */
function escutarReinicioSessao() {
  CONFIG_REF.onSnapshot(async (snap) => {
    const data = snap.data() ?? {};
    if (data.reiniciarSessao === true) {
      console.log('[WhatsApp] Flag reiniciarSessao detectada – reconectando');
      await desconectarCliente();
      await limparAuthLocal();
      await CONFIG_REF.set({ reiniciarSessao: false }, { merge: true });
      setTimeout(conectarCliente, 2_000);
    }
  }, (err) => console.error('[Firestore] Erro no listener config:', err.message));
}

/** Processa fila de mensagens a enviar */
function escutarFilaEnvio() {
  db.collection('fila_envio')
    .where('status', '==', 'pendente')
    .onSnapshot(async (snap) => {
      for (const doc of snap.docs) {
        const { para, texto } = doc.data();
        if (!texto) continue;
        try {
          await enviarMensagemWhatsApp(para, texto);
          await doc.ref.update({
            status: 'enviado',
            enviadoEm: FieldValue.serverTimestamp(),
          });
        } catch (e) {
          console.error('[WhatsApp] Erro ao processar fila_envio:', e.message);
        }
      }
    }, (err) => console.error('[Firestore] Erro no listener fila_envio:', err.message));
}

// ---------------------------------------------------------------------------
// Inicializador
// ---------------------------------------------------------------------------
export async function iniciarWhatsApp() {
  // Inicia conexão do WhatsApp imediatamente (gera QR Code no terminal sem travar se a rede demorar)
  conectarCliente().catch((err) => console.error('[WhatsApp] Erro inicial:', err?.message || err));

  // Tenta conectar ao Firestore em segundo plano para não bloquear a geração do QR Code
  (async () => {
    let conectado = false;
    while (!conectado) {
      try {
        await db.collection('sige_ping').doc('test').get();
        console.log('[Firestore] Conexão OK');
        conectado = true;
        escutarReinicioSessao();
        escutarFilaEnvio();
      } catch (e) {
        console.warn(`[Firestore] Tentando conectar... (${e?.message?.split('\n')[0] || e})`);
        await new Promise((res) => setTimeout(res, 5000));
      }
    }
  })();
}

// Compatibilidade com importações anteriores
export { conectarCliente as connectToWhatsApp };

export function onWhatsAppOpen(cb) {
  if (connectionStatus === 'connected' && sock) {
    try { cb(sock); } catch (e) { console.error(e); }
    return;
  }
  const handler = async (update) => {
    if (update?.connection === 'open' && sock) {
      try { cb(sock); } catch (e) { console.error(e); }
      sock.ev.off('connection.update', handler);
    }
  };
  sock?.ev?.on('connection.update', handler);
}
