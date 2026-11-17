// api/send-email.js
import { enviarCodigoEmail } from './recuperacao.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ erro: 'Método não permitido. Utilize POST.' });
  }

  const { email, nome, codigo, assunto, html } = req.body || {};

  if (!email || !codigo) {
    return res.status(400).json({ erro: 'Campos "email" e "codigo" são obrigatórios.' });
  }

  try {
    const resultado = await enviarCodigoEmail({
      email,
      nome: nome || 'Colaborador',
      codigo,
      assuntoCustomizado: assunto,
      htmlCustomizado: html
    });

    return res.status(200).json({
      sucesso: true,
      detalhes: resultado
    });
  } catch (err) {
    console.error('[send-email.js] Erro ao enviar e-mail:', err);
    return res.status(500).json({
      sucesso: false,
      erro: err?.message || String(err)
    });
  }
}
