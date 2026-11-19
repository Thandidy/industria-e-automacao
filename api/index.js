// api/index.js
import { db, FieldValue } from './firebase.js';
import {
  enviarMensagemWhatsApp,
  onWhatsAppOpen,
  getWhatsAppState,
  iniciarWhatsApp,
} from './whatsapp.js';
import { observarOcorrencias } from './mensagens.js';
import { observarRecuperacoesSenha } from './recuperacao.js';
import { enviarEmail } from './email.js';
import dotenv from 'dotenv';

dotenv.config();

// ---------------------------------------------------------------------------
// Configurações do chefe
// ---------------------------------------------------------------------------
const TELEFONE_CHEFE = (process.env.TELEFONE_CHEFE || '').trim().replace(/['"]/g, '');
const EMAIL_CHEFE    = (process.env.EMAIL_CHEFE    || '').trim();

const BASE_URL = process.env.VERCEL_PROJECT_PRODUCTION_URL
  ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`
  : process.env.VERCEL_URL
    ? `https://${process.env.VERCEL_URL}`
    : 'https://sige-industria-e-automacao.vercel.app';

// ---------------------------------------------------------------------------
// Flags de controle (evita múltiplos listeners)
// ---------------------------------------------------------------------------
let observadorSolicitacoesIniciado = false;
let observadorOcorrenciasIniciado  = false;
let observadorRecuperacoesIniciado = false;

// ---------------------------------------------------------------------------
// Observador de novas solicitações de login
// ---------------------------------------------------------------------------
export function iniciarObservadorSolicitacoes() {
  if (observadorSolicitacoesIniciado) return;
  observadorSolicitacoesIniciado = true;

  console.log('[Firestore] Ouvindo novas solicitações de login em tempo real...');

  db.collection('solicitacoes_login')
    .where('status', 'in', ['pendente', 'aguardando'])
    .onSnapshot(
      (snapshot) => {
        snapshot.docChanges().forEach(async (change) => {
          if (change.type !== 'added') return;

          const id    = change.doc.id;
          const dados = change.doc.data();

          // Já foi notificado em execução anterior
          if (dados.notificado === true) return;

          const nome   = dados.nome || dados.nomeFuncionario || 'Colaborador';
          const perfil = dados.perfil || 'operador';

          console.log(`[Novo Cadastro] Solicitação recebida – ID: ${id} | Nome: ${nome}`);

          const linkAprovar  = `${BASE_URL}/api/decidir?id=${id}&acao=aprovar`;
          const linkRejeitar = `${BASE_URL}/api/decidir?id=${id}&acao=rejeitar`;

          // ── 1. Notifica por WhatsApp ──────────────────────────────────────
          const msgWa =
            `🔔 *Nova Solicitação de Acesso – SIGE*\n\n` +
            `👤 *Nome:* ${nome}\n` +
            `📧 *E-mail:* ${dados.email}\n` +
            (dados.telefone ? `📱 *Telefone:* ${dados.telefone}\n` : '') +
            `🏷️ *Perfil:* ${perfil}\n` +
            `🆔 *ID:* \`${id}\`\n\n` +
            `👉 *Como decidir:*\n` +
            `• Responda *APROVAR* para liberar o acesso\n` +
            `• Responda *REJEITAR* para recusar\n\n` +
            `🔗 Ou use os links diretos:\n` +
            `✅ Aprovar: ${linkAprovar}\n` +
            `❌ Rejeitar: ${linkRejeitar}`;

          try {
            const resultado = await enviarMensagemWhatsApp(TELEFONE_CHEFE, msgWa);
            if (resultado?.sucesso && resultado?.messageId) {
              // Registra o msgId para rastrear reações/respostas futuras
              const { cacheMsgParaSolicitacao } = getWhatsAppState();
              if (cacheMsgParaSolicitacao) {
                cacheMsgParaSolicitacao.set(resultado.messageId, id);
              }
              await db.collection('solicitacoes_login').doc(id).update({
                notificado: true,
                whatsappMsgId: resultado.messageId,
              });
              console.log(`[WhatsApp] Chefe notificado – MsgId: ${resultado.messageId}`);
            } else {
              // WhatsApp offline: marca como notificado apenas se e-mail for enviado
              console.warn('[WhatsApp] Falha ao enviar WhatsApp – será tentado pelo e-mail');
            }
          } catch (errWa) {
            console.error('[WhatsApp] Erro ao notificar chefe:', errWa?.message || errWa);
          }

          // ── 2. Notifica por E-mail ────────────────────────────────────────
          if (EMAIL_CHEFE) {
            const htmlEmail = `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;background:#f8fafc;margin:0;padding:24px;">
  <div style="max-width:580px;margin:0 auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 4px 6px rgba(0,0,0,.05);border:1px solid #e2e8f0;">
    <div style="background:#0284c7;padding:24px 32px;text-align:center;">
      <h1 style="color:#fff;margin:0;font-size:20px;font-weight:700;">🔔 Nova Solicitação de Acesso – SIGE</h1>
      <p style="color:rgba(255,255,255,.9);margin:6px 0 0;font-size:13px;">Um novo colaborador solicitou cadastro no sistema</p>
    </div>
    <div style="padding:28px 32px;">
      <table style="width:100%;border-collapse:collapse;font-size:14px;">
        <tr><td style="padding:10px 12px;border-bottom:1px solid #e2e8f0;font-weight:600;color:#475569;width:35%;">Nome:</td><td style="padding:10px 12px;border-bottom:1px solid #e2e8f0;color:#1e293b;">${nome}</td></tr>
        <tr><td style="padding:10px 12px;border-bottom:1px solid #e2e8f0;font-weight:600;color:#475569;">E-mail:</td><td style="padding:10px 12px;border-bottom:1px solid #e2e8f0;color:#1e293b;">${dados.email || '—'}</td></tr>
        <tr><td style="padding:10px 12px;border-bottom:1px solid #e2e8f0;font-weight:600;color:#475569;">Telefone:</td><td style="padding:10px 12px;border-bottom:1px solid #e2e8f0;color:#1e293b;">${dados.telefone || '—'}</td></tr>
        <tr><td style="padding:10px 12px;border-bottom:1px solid #e2e8f0;font-weight:600;color:#475569;">Perfil:</td><td style="padding:10px 12px;border-bottom:1px solid #e2e8f0;color:#1e293b;"><b>${perfil.toUpperCase()}</b></td></tr>
        <tr><td style="padding:10px 12px;font-weight:600;color:#475569;">Protocolo:</td><td style="padding:10px 12px;color:#64748b;"><code>${id}</code></td></tr>
      </table>
      <div style="margin-top:28px;text-align:center;">
        <p style="font-weight:600;font-size:14px;color:#1e293b;margin-bottom:16px;">Clique para decidir:</p>
        <a href="${linkAprovar}" style="background:#16a34a;color:#fff;text-decoration:none;padding:12px 28px;border-radius:8px;font-weight:600;display:inline-block;margin-right:12px;font-size:14px;">✅ Aprovar Acesso</a>
        <a href="${linkRejeitar}" style="background:#dc2626;color:#fff;text-decoration:none;padding:12px 28px;border-radius:8px;font-weight:600;display:inline-block;font-size:14px;">❌ Rejeitar</a>
      </div>
    </div>
    <div style="background:#f8fafc;padding:16px;text-align:center;border-top:1px solid #e2e8f0;font-size:12px;color:#94a3b8;">
      SIGE – Sistema Integrado de Gestão de Equipamentos • Decisão Rápida 1-Click
    </div>
  </div>
</body>
</html>`;

            try {
              await enviarEmail({
                to: EMAIL_CHEFE,
                subject: `🔔 [SIGE] Novo Cadastro: ${nome} – Aprovar / Rejeitar`,
                html: htmlEmail,
                text: `Nova solicitação SIGE\nNome: ${nome}\nE-mail: ${dados.email}\nPerfil: ${perfil}\n\nAprovar: ${linkAprovar}\nRejeitar: ${linkRejeitar}`,
              });
              console.log(`[E-mail] Chefe notificado em: ${EMAIL_CHEFE}`);

              // Marca como notificado mesmo que WhatsApp tenha falhado
              await db.collection('solicitacoes_login').doc(id).update({
                notificado: true,
              }).catch(() => {});
            } catch (errEmail) {
              console.error('[E-mail] Erro ao notificar chefe:', errEmail?.message || errEmail);
            }
          }
        });
      },
      (err) => console.error('[Firestore] Erro no listener solicitacoes_login:', err.message)
    );
}

// ---------------------------------------------------------------------------
// Observador de ocorrências de máquinas
// ---------------------------------------------------------------------------
export function iniciarObservadorOcorrencias() {
  if (observadorOcorrenciasIniciado) return;
  observadorOcorrenciasIniciado = true;

  observarOcorrencias({
    db,
    enviarMensagem: enviarMensagemWhatsApp,
    telefoneChefe: TELEFONE_CHEFE,
  });

  console.log('[Firestore] Ouvindo alterações em ocorrências e máquinas...');
}

// ---------------------------------------------------------------------------
// Observador de recuperações de senha (OTP)
// ---------------------------------------------------------------------------
export function iniciarObservadorRecuperacoes() {
  if (observadorRecuperacoesIniciado) return;
  observadorRecuperacoesIniciado = true;

  observarRecuperacoesSenha({
    db,
    enviarMensagem: enviarMensagemWhatsApp,
  });

  console.log('[Firestore] Observador de recuperações de senha ativo.');
}

// ---------------------------------------------------------------------------
// Inicializador principal — chamado pelo bot/start.js
// ---------------------------------------------------------------------------
export async function inicializarBot() {
  // 1. Inicia os observadores do Firestore imediatamente (independente de WhatsApp estar pronto ou não)
  iniciarObservadorSolicitacoes();
  iniciarObservadorOcorrencias();
  iniciarObservadorRecuperacoes();

  // 2. Inicia WhatsApp + listeners Firestore (fila_envio, reiniciarSessao)
  await iniciarWhatsApp();
}

// ---------------------------------------------------------------------------
// Serverless handler para /api (Vercel)
// ---------------------------------------------------------------------------
export default async function handler(req, res) {
  inicializarBot().catch(console.error);

  const state = getWhatsAppState();

  return res.status(200).json({
    status: 'ok',
    whatsapp: {
      connection: state.status,
      telefoneChefe: TELEFONE_CHEFE ? 'configurado' : 'não configurado',
    },
    servicos: {
      solicitacoesLogin: observadorSolicitacoesIniciado,
      ocorrenciasMaquinas: observadorOcorrenciasIniciado,
      recuperacaoSenha: observadorRecuperacoesIniciado,
    },
    timestamp: new Date().toISOString(),
  });
}
