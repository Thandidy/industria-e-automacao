// api/index.js
import { db } from './firebase.js';
import {
  connectToWhatsApp,
  enviarMensagemWhatsApp,
  onWhatsAppOpen,
  getWhatsAppState
} from './whatsapp.js';
import { observarOcorrencias } from './mensagens.js';
import { observarRecuperacoesSenha } from './recuperacao.js';
import dotenv from 'dotenv';

dotenv.config();

const TELEFONE_CHEFE_CONFIG = (process.env.TELEFONE_CHEFE || '').trim().replace(/['"]/g, '');
const CHEFE_DIGITOS = TELEFONE_CHEFE_CONFIG.replace(/\D/g, '');
const TELEFONE_CHEFE_JID = CHEFE_DIGITOS ? CHEFE_DIGITOS + '@s.whatsapp.net' : '';

let observadorSolicitacoesIniciado = false;
let observadorOcorrenciasIniciado = false;
let observadorRecuperacoesIniciado = false;

// Observador de novas solicitações de login
export function iniciarObservadorSolicitacoes() {
  if (observadorSolicitacoesIniciado) return;
  observadorSolicitacoesIniciado = true;

  console.log('[Firestore] Ouvindo novas solicitações de login em tempo real...');

  const { cacheMsgParaSolicitacao } = getWhatsAppState();

  db.collection('solicitacoes_login')
    .where('status', '==', 'pendente')
    .onSnapshot((snapshot) => {
      snapshot.docChanges().forEach(async (change) => {
        if (change.type === 'added') {
          const id = change.doc.id;
          const dados = change.doc.data();

          if (dados.notificado === true) return;

          console.log(`[Novo Cadastro] Enviando notificação para o chefe... ID: ${id}`);

          const mensagem = `🔔 *Nova Solicitação de Acesso (SIGE)*\n\n` +
                           `👤 *Nome:* ${dados.nome || dados.nomeFuncionario}\n` +
                           `📧 *E-mail:* ${dados.email}\n` +
                           (dados.telefone ? `📱 *Telefone/WhatsApp:* ${dados.telefone}\n` : '') +
                           `🏷️ *Perfil:* ${dados.perfil || 'operador'}\n` +
                           `🆔 *ID:* \`${id}\`\n\n` +
                           `👉 *Como decidir:*\n` +
                           `• Reaja com 👍 ou ✅ nesta mensagem para *Aprovar*\n` +
                           `• Reaja com 👎 ou ❌ nesta mensagem para *Rejeitar*\n\n` +
                           `_Ou responda citando esta mensagem com "aprovar" ou "rejeitar"_`;

          try {
            const { sock } = getWhatsAppState();
            if (sock && TELEFONE_CHEFE_JID) {
              const sentMsg = await sock.sendMessage(TELEFONE_CHEFE_JID, { text: mensagem });
              const msgId = sentMsg?.key?.id;

              if (msgId) {
                if (cacheMsgParaSolicitacao) cacheMsgParaSolicitacao.set(msgId, id);
                await db.collection('solicitacoes_login').doc(id).update({
                  notificado: true,
                  whatsappMsgId: msgId
                });
                console.log(`[Notificação Enviada] Msg ID ${msgId} vinculada ao cadastro ${id}`);
              } else {
                await db.collection('solicitacoes_login').doc(id).update({ notificado: true });
              }
            }
          } catch (error) {
            console.error('Falha ao enviar mensagem de WhatsApp:', error);
          }
        }
      });
    });
}

// Inicia os observadores de ocorrências e máquinas
export function iniciarObservadorOcorrencias() {
  if (observadorOcorrenciasIniciado) return;
  observadorOcorrenciasIniciado = true;

  observarOcorrencias({
    db,
    enviarMensagem: enviarMensagemWhatsApp,
    telefoneChefe: TELEFONE_CHEFE_CONFIG
  });

  console.log('[Firestore] Ouvindo alterações em ocorrencias e máquinas...');
}

// Inicia observador de códigos OTP
export function iniciarObservadorRecuperacoes() {
  if (observadorRecuperacoesIniciado) return;
  observadorRecuperacoesIniciado = true;

  observarRecuperacoesSenha({
    db,
    enviarMensagem: enviarMensagemWhatsApp
  });

  console.log('[Firestore] Observador de recuperações de senha pronto para despachos.');
}

// Inicializador principal
export async function inicializarBot({ printTerminal = false } = {}) {
  onWhatsAppOpen(() => {
    iniciarObservadorSolicitacoes();
    iniciarObservadorOcorrencias();
    iniciarObservadorRecuperacoes();
  });

  return await connectToWhatsApp({ printTerminal });
}

// Serverless Handler para /api ou /api/index
export default async function handler(req, res) {
  // Inicializa o bot se ainda não estiver inicializado
  inicializarBot({ printTerminal: false }).catch(console.error);
  const state = getWhatsAppState();

  return res.status(200).json({
    status: 'ok',
    whatsapp: {
      connection: state.status,
      hasQR: state.hasQR,
      telefoneChefe: state.telefoneChefe ? 'configurado' : 'não configurado'
    },
    servicos: {
      solicitacoesLogin: observadorSolicitacoesIniciado,
      ocorrenciasMaquinas: observadorOcorrenciasIniciado,
      recuperacaoSenha: observadorRecuperacoesIniciado
    },
    timestamp: new Date().toISOString()
  });
}
