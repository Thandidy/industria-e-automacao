// api/webhook.js
import dotenv from 'dotenv';
import { db, FieldValue } from './firebase.js';
import { processarDecisao } from './whatsapp.js';
import { enviarMensagemMeta } from './meta-whatsapp.js';

dotenv.config();

const VERIFY_TOKEN = (process.env.META_VERIFY_TOKEN || 'sige_meta_verify_token_2026').trim();

export default async function handler(req, res) {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // 1. Validação do Webhook pela Meta (GET)
  if (req.method === 'GET') {
    const mode = req.query['hub.mode'];
    const token = req.query['hub.verify_token'];
    const challenge = req.query['hub.challenge'];

    if (mode === 'subscribe' && token === VERIFY_TOKEN) {
      console.log('[Meta Webhook] ✅ Webhook validado com sucesso pela Meta!');
      return res.status(200).send(challenge);
    } else {
      console.warn('[Meta Webhook] ❌ Falha na verificação de token.');
      return res.status(403).json({ erro: 'Token de verificação inválido' });
    }
  }

  // 2. Recebimento de Eventos da Meta (POST)
  if (req.method === 'POST') {
    try {
      const body = req.body;

      if (body?.object === 'whatsapp_business_account') {
        const entries = body.entry || [];
        for (const entry of entries) {
          const changes = entry.changes || [];
          for (const change of changes) {
            const value = change.value;
            const messages = value?.messages || [];

            for (const msg of messages) {
              const remetente = msg.from; // Número de quem enviou (ex: 5513996949822)
              const msgId = msg.id;

              let texto = '';
              let btnId = '';

              if (msg.type === 'text') {
                texto = msg.text?.body || '';
              } else if (msg.type === 'interactive') {
                btnId = msg.interactive?.button_reply?.id || '';
                texto = msg.interactive?.button_reply?.title || '';
              } else if (msg.type === 'button') {
                btnId = msg.button?.payload || '';
                texto = msg.button?.text || '';
              }

              console.log(`[Meta Webhook] Mensagem recebida de ${remetente}: "${texto}" (btnId: ${btnId})`);

              // Identifica se é comando de Aprovação / Rejeição
              let acao = null;
              let solicitacaoId = null;

              if (btnId) {
                // Formato padrão: aprovar_<id> ou rejeitar_<id>
                const parts = btnId.split('_');
                if (parts[0] === 'aprovar' || parts[0] === 'rejeitar') {
                  acao = parts[0];
                  solicitacaoId = parts.slice(1).join('_');
                }
              }

              if (!acao && texto) {
                const match = texto.trim().match(/^(aprovar|rejeitar)\s*(.*)$/i);
                if (match) {
                  acao = match[1].toLowerCase();
                  solicitacaoId = match[2]?.trim() || null;
                }
              }

              // Se a mensagem citou uma solicitação anterior
              const quotedMsgId = msg.context?.id;

              if (acao) {
                // Processa a decisão via módulo existente
                await processarDecisao({
                  solicitacaoId,
                  whatsappMsgId: quotedMsgId,
                  acao,
                  remetenteJid: remetente + '@s.whatsapp.net',
                  sock: {
                    sendMessage: async (jid, content) => {
                      return await enviarMensagemMeta({ to: remetente, texto: content.text });
                    }
                  }
                });
              }
            }
          }
        }

        return res.status(200).send('EVENT_RECEIVED');
      }

      return res.status(200).send('OK');
    } catch (err) {
      console.error('[Meta Webhook] Erro ao processar evento:', err);
      return res.status(500).json({ erro: err?.message || String(err) });
    }
  }

  return res.status(405).json({ erro: 'Método não permitido' });
}
