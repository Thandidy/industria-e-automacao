// api/send-message.js
import { enviarMensagemWhatsApp, getWhatsAppState, connectToWhatsApp } from './whatsapp.js';

export default async function handler(req, res) {
  // Configura CORS para permitir chamadas do Flutter Web hospedado
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ erro: 'Método não permitido. Utilize POST.' });
  }

  const { telefone, mensagem } = req.body || {};

  if (!mensagem || typeof mensagem !== 'string') {
    return res.status(400).json({ erro: 'Campo "mensagem" é obrigatório e deve ser uma string.' });
  }

  const state = getWhatsAppState();
  if (state.status !== 'connected') {
    // Tenta conectar se ainda não estiver
    connectToWhatsApp().catch(console.error);
    return res.status(503).json({
      erro: 'WhatsApp não está conectado no momento.',
      status: state.status,
      qrUrl: '/api/qr'
    });
  }

  try {
    const resultado = await enviarMensagemWhatsApp(telefone, mensagem);
    if (resultado.sucesso) {
      return res.status(200).json({
        sucesso: true,
        messageId: resultado.messageId,
        destinatario: telefone || 'chefe'
      });
    } else {
      return res.status(500).json({
        sucesso: false,
        erro: resultado.erro
      });
    }
  } catch (err) {
    return res.status(500).json({
      sucesso: false,
      erro: err?.message || String(err)
    });
  }
}
