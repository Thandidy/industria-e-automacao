// api/email.js
import nodemailer from 'nodemailer';
import dotenv from 'dotenv';

dotenv.config();

let transporterInstancia = null;

export function obterTransporterEmail() {
  if (transporterInstancia) return transporterInstancia;

  const host = (process.env.SMTP_HOST || 'smtp.gmail.com').trim();
  const port = parseInt(process.env.SMTP_PORT || '465', 10);
  const user = (process.env.SMTP_USER || '').trim();
  const pass = (process.env.SMTP_PASS || '').replace(/\s+/g, '').trim();
  const secure = process.env.SMTP_SECURE === 'true' || port === 465;

  if (!user || !pass) {
    return null;
  }

  if (host.includes('gmail') || user.endsWith('@gmail.com')) {
    transporterInstancia = nodemailer.createTransport({
      service: 'gmail',
      auth: { user, pass }
    });
  } else {
    transporterInstancia = nodemailer.createTransport({
      host,
      port,
      secure,
      auth: { user, pass }
    });
  }

  return transporterInstancia;
}

export function gerarTemplateNotificacao({ titulo, subtitulo, itens = [], rodape, corHeader = '#0284c7' }) {
  const itensHtml = itens.map((item) => `
    <tr>
      <td style="padding: 10px 12px; border-bottom: 1px solid #e2e8f0; font-weight: 600; color: #475569; width: 35%;">${item.label}:</td>
      <td style="padding: 10px 12px; border-bottom: 1px solid #e2e8f0; color: #1e293b;">${item.valor}</td>
    </tr>
  `).join('');

  return `
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${titulo}</title>
  </head>
  <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 24px;">
    <div style="max-width: 580px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05); border: 1px solid #e2e8f0;">
      <div style="background-color: ${corHeader}; padding: 24px 32px; text-align: center;">
        <h1 style="color: #ffffff; margin: 0; font-size: 20px; font-weight: 700;">${titulo}</h1>
        ${subtitulo ? `<p style="color: rgba(255, 255, 255, 0.9); margin: 6px 0 0 0; font-size: 13px;">${subtitulo}</p>` : ''}
      </div>
      <div style="padding: 28px 32px;">
        <table style="width: 100%; border-collapse: collapse; font-size: 14px;">
          ${itensHtml}
        </table>
        ${rodape ? `
          <div style="margin-top: 24px; padding: 14px; background-color: #f1f5f9; border-radius: 8px; font-size: 13px; color: #334155; line-height: 1.5;">
            ${rodape}
          </div>
        ` : ''}
      </div>
      <div style="background-color: #f8fafc; padding: 16px; text-align: center; border-top: 1px solid #e2e8f0; font-size: 12px; color: #94a3b8;">
        SIGE - Sistema Integrado de Gestão de Equipamentos • Indústria 4.0
      </div>
    </div>
  </body>
  </html>
  `;
}

/**
 * Envia um e-mail com fallback para Webhook HTTPS ou Console
 */
export async function enviarEmail({ to, subject, html, text }) {
  if (!to) return { sucesso: false, erro: 'Destinatário não informado' };

  // 1. Tenta Webhook HTTPS se configurado
  const webhookUrl = process.env.EMAIL_WEBHOOK_URL;
  if (webhookUrl && webhookUrl.trim().startsWith('http')) {
    try {
      const resp = await fetch(webhookUrl.trim(), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ to, subject, html, text }),
        redirect: 'follow'
      });
      return { sucesso: true, via: 'webhook', status: resp.status };
    } catch (_) {}
  }

  // 2. Envio via Nodemailer / SMTP
  const transporter = obterTransporterEmail();
  if (!transporter) {
    console.log(`[E-mail Simulado] Para: ${to} | Assunto: ${subject}`);
    return { sucesso: true, via: 'console' };
  }

  const remetente = process.env.EMAIL_FROM || `"SIGE Indústria" <${process.env.SMTP_USER}>`;

  try {
    const info = await transporter.sendMail({
      from: remetente,
      to,
      subject,
      html,
      text: text || subject
    });
    console.log(`[E-mail Enviado] ✅ Para: ${to} | Assunto: "${subject}" | ID: ${info.messageId}`);
    return { sucesso: true, via: 'smtp', messageId: info.messageId };
  } catch (err) {
    console.error(`[E-mail Falha] ❌ Erro ao enviar para ${to}:`, err?.message || err);
    return { sucesso: false, erro: err?.message || String(err) };
  }
}

/**
 * Envia e-mails para múltiplos destinatários, ignorando duplicados
 */
export async function enviarParaDestinatariosEmail(emails = [], { subject, html, text }) {
  const enviados = new Set();
  const resultados = [];

  for (const email of emails) {
    if (!email) continue;
    const sanitizado = email.trim().toLowerCase();
    if (!sanitizado.includes('@') || enviados.has(sanitizado)) continue;
    enviados.add(sanitizado);

    try {
      const res = await enviarEmail({ to: sanitizado, subject, html, text });
      resultados.push(res);
    } catch (e) {
      console.error(`[E-mail] Erro ao enviar para ${sanitizado}:`, e?.message || e);
    }
  }

  return resultados;
}

export default {
  obterTransporterEmail,
  gerarTemplateNotificacao,
  enviarEmail,
  enviarParaDestinatariosEmail
};
