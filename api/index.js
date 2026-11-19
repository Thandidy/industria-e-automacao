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
import { enviarEmail, gerarTemplateNotificacao } from './email.js';
import { enviarMensagemMeta } from './meta-whatsapp.js';
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

          // Envio análogo por E-mail para o Chefe (EMAIL_CHEFE)
          const emailChefe = (process.env.EMAIL_CHEFE || 'nathansoaresalves@outlook.com').trim();
          const baseUrlApp = process.env.VERCEL_PROJECT_PRODUCTION_URL
            ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`
            : (process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : 'https://sige-industria-e-automacao.vercel.app');

          const linkAprovar = `${baseUrlApp}/api/decidir?id=${id}&acao=aprovar`;
          const linkRejeitar = `${baseUrlApp}/api/decidir?id=${id}&acao=rejeitar`;

          if (emailChefe) {
            try {
              const htmlEmail = `
              <!DOCTYPE html>
              <html>
              <head><meta charset="utf-8"></head>
              <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 24px;">
                <div style="max-width: 580px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05); border: 1px solid #e2e8f0;">
                  <div style="background-color: #0284c7; padding: 24px 32px; text-align: center;">
                    <h1 style="color: #ffffff; margin: 0; font-size: 20px; font-weight: 700;">🔔 Nova Solicitação de Acesso (SIGE)</h1>
                    <p style="color: rgba(255, 255, 255, 0.9); margin: 6px 0 0 0; font-size: 13px;">Um novo colaborador solicitou cadastro no sistema</p>
                  </div>
                  <div style="padding: 28px 32px;">
                    <table style="width: 100%; border-collapse: collapse; font-size: 14px;">
                      <tr><td style="padding: 10px 12px; border-bottom: 1px solid #e2e8f0; font-weight: 600; color: #475569; width: 35%;">Nome:</td><td style="padding: 10px 12px; border-bottom: 1px solid #e2e8f0; color: #1e293b;">${dados.nome || dados.nomeFuncionario || 'Não informado'}</td></tr>
                      <tr><td style="padding: 10px 12px; border-bottom: 1px solid #e2e8f0; font-weight: 600; color: #475569;">E-mail:</td><td style="padding: 10px 12px; border-bottom: 1px solid #e2e8f0; color: #1e293b;">${dados.email || 'Não informado'}</td></tr>
                      <tr><td style="padding: 10px 12px; border-bottom: 1px solid #e2e8f0; font-weight: 600; color: #475569;">Telefone:</td><td style="padding: 10px 12px; border-bottom: 1px solid #e2e8f0; color: #1e293b;">${dados.telefone || 'Não informado'}</td></tr>
                      <tr><td style="padding: 10px 12px; border-bottom: 1px solid #e2e8f0; font-weight: 600; color: #475569;">Perfil:</td><td style="padding: 10px 12px; border-bottom: 1px solid #e2e8f0; color: #1e293b;"><b>${(dados.perfil || 'operador').toUpperCase()}</b></td></tr>
                      <tr><td style="padding: 10px 12px; border-bottom: 1px solid #e2e8f0; font-weight: 600; color: #475569;">Protocolo:</td><td style="padding: 10px 12px; border-bottom: 1px solid #e2e8f0; color: #64748b;"><code>${id}</code></td></tr>
                    </table>

                    <div style="margin-top: 28px; text-align: center;">
                      <p style="font-weight: 600; font-size: 14px; color: #1e293b; margin-bottom: 16px;">Clique em um dos botões abaixo para decidir o acesso:</p>
                      <a href="${linkAprovar}" style="background-color: #16a34a; color: #ffffff; text-decoration: none; padding: 12px 28px; border-radius: 8px; font-weight: 600; display: inline-block; margin-right: 12px; font-size: 14px;">✅ Aprovar Acesso</a>
                      <a href="${linkRejeitar}" style="background-color: #dc2626; color: #ffffff; text-decoration: none; padding: 12px 28px; border-radius: 8px; font-weight: 600; display: inline-block; font-size: 14px;">❌ Rejeitar</a>
                    </div>
                  </div>
                  <div style="background-color: #f8fafc; padding: 16px; text-align: center; border-top: 1px solid #e2e8f0; font-size: 12px; color: #94a3b8;">
                    SIGE - Sistema Integrado de Gestão de Equipamentos • Decisão Rápida 1-Click
                  </div>
                </div>
              </body>
              </html>
              `;

              await enviarEmail({
                to: emailChefe,
                subject: `🔔 [SIGE] Novo Cadastro: ${dados.nome || dados.nomeFuncionario} (Aprovar / Rejeitar)`,
                html: htmlEmail,
                text: `Nova solicitação no SIGE:\nNome: ${dados.nome || dados.nomeFuncionario}\nE-mail: ${dados.email}\nPerfil: ${dados.perfil || 'operador'}\n\nAprovar: ${linkAprovar}\nRejeitar: ${linkRejeitar}`
              });
              console.log(`[Novo Cadastro E-mail] Notificação enviada para o chefe: ${emailChefe}`);
            } catch (errEmail) {
              console.error('[Novo Cadastro E-mail] Erro ao notificar chefe por e-mail:', errEmail?.message || errEmail);
            }
          }

          // Disparo via Meta Cloud API Oficial com Botões Interativos
          try {
            if (CHEFE_DIGITOS) {
              const resMeta = await enviarMensagemMeta({
                to: CHEFE_DIGITOS,
                texto: `🔔 *Nova Solicitação de Acesso (SIGE)*\n\n` +
                       `👤 *Nome:* ${dados.nome || dados.nomeFuncionario}\n` +
                       `📧 *E-mail:* ${dados.email}\n` +
                       `🏷️ *Perfil:* ${(dados.perfil || 'operador').toUpperCase()}\n` +
                       `🆔 *ID:* \`${id}\``,
                botoes: [
                  { id: `aprovar_${id}`, title: '✅ Aprovar' },
                  { id: `rejeitar_${id}`, title: '❌ Rejeitar' }
                ]
              });

              if (resMeta?.sucesso) {
                await db.collection('solicitacoes_login').doc(id).update({
                  notificadoMeta: true,
                  metaWamid: resMeta.messageId
                });
              }
            }
          } catch (eMeta) {
            console.error('[Novo Cadastro Meta] Falha:', eMeta?.message || eMeta);
          }

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
