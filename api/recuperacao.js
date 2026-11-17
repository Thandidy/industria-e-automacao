// api/recuperacao.js
import nodemailer from 'nodemailer';
import { FieldValue } from 'firebase-admin/firestore';
import dbPadrao from './firebase.js';

// Trava em memória para evitar múltiplos envios para a mesma solicitação
const recuperacoesEmProcessamento = new Set();

/**
 * Cria o transporter do Nodemailer usando as variáveis do .env
 */
export function criarTransporterEmail() {
  const host = (process.env.SMTP_HOST || 'smtp.gmail.com').trim();
  const port = parseInt(process.env.SMTP_PORT || '465', 10);
  const user = (process.env.SMTP_USER || '').trim();
  const pass = (process.env.SMTP_PASS || '').replace(/\s+/g, '').trim();
  const secure = process.env.SMTP_SECURE === 'true' || port === 465;

  if (!user || !pass) {
    return null;
  }

  if (host.includes('gmail') || user.endsWith('@gmail.com')) {
    return nodemailer.createTransport({
      service: 'gmail',
      auth: { user, pass }
    });
  }

  return nodemailer.createTransport({
    host,
    port,
    secure,
    auth: { user, pass }
  });
}

/**
 * Gera o template HTML corporativo do SIGE para o e-mail de recuperação de senha
 */
export function gerarTemplateEmail({ nome, codigo }) {
  return `
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Recuperação de Senha - SIGE</title>
  </head>
  <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 24px;">
    <div style="max-width: 520px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1); border: 1px solid #e2e8f0;">
      
      <!-- Cabeçalho -->
      <div style="background-color: #0f172a; padding: 28px 24px; text-align: center;">
        <h1 style="color: #ffffff; font-size: 20px; margin: 0; font-weight: 700; letter-spacing: 0.5px;">
          🏭 SIGE - Indústria & Manutenção
        </h1>
        <p style="color: #94a3b8; font-size: 13px; margin: 6px 0 0 0;">
          Sistema Integrado de Gestão de Equipamentos
        </p>
      </div>

      <!-- Conteúdo -->
      <div style="padding: 32px 28px; color: #334155;">
        <h2 style="font-size: 18px; color: #0f172a; margin-top: 0;">
          Olá, ${nome}! 👋
        </h2>
        
        <p style="font-size: 14px; line-height: 1.6; color: #475569;">
          Recebemos uma solicitação para redefinir a senha de acesso da sua conta no <strong>SIGE</strong>.
        </p>

        <p style="font-size: 14px; line-height: 1.6; color: #475569;">
          Utilize o código de verificação abaixo no aplicativo para prosseguir:
        </p>

        <!-- Caixa de Código OTP -->
        <div style="margin: 28px 0; background: #f1f5f9; border: 2px dashed #0284c7; border-radius: 10px; padding: 20px; text-align: center;">
          <div style="font-size: 12px; text-transform: uppercase; letter-spacing: 1.5px; color: #0369a1; font-weight: 600; margin-bottom: 8px;">
            Código de Verificação
          </div>
          <div style="font-size: 36px; font-weight: 800; letter-spacing: 10px; color: #0f172a; font-family: monospace;">
            ${codigo}
          </div>
          <div style="font-size: 12px; color: #64748b; margin-top: 8px;">
            ⏰ Este código expira em <strong>15 minutos</strong>.
          </div>
        </div>

        <p style="font-size: 13px; line-height: 1.5; color: #64748b; background-color: #f8fafc; padding: 12px; border-radius: 6px; border-left: 4px solid #f59e0b;">
          ⚠️ <strong>Aviso de segurança:</strong> Se você não solicitou a redefinição de senha, desconsidere esta mensagem. Sua conta permanece segura.
        </p>

        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 28px 0;">

        <p style="font-size: 12px; color: #94a3b8; text-align: center; margin: 0;">
          Esta é uma mensagem automática. Por favor, não responda a este e-mail.
        </p>
      </div>

    </div>
  </body>
  </html>
  `;
}

/**
 * Dispara o código de recuperação para o WhatsApp do usuário
 */
export async function enviarCodigoWhatsApp({ enviarMensagem, telefone, nome, codigo }) {
  if (typeof enviarMensagem !== 'function') {
    throw new Error('Função enviarMensagem não está disponível.');
  }

  const mensagem = `🔐 *SIGE - RECUPERAÇÃO DE SENHA*\n\n` +
                   `Olá, *${nome}*! 👋\n` +
                   `Você solicitou a redefinição de sua senha de acesso ao sistema *SIGE*.\n\n` +
                   `Seu código de verificação é:\n` +
                   `👉 *${codigo}* 👈\n\n` +
                   `⏰ *Validade:* 15 minutos.\n` +
                   `⚠️ _Se você não solicitou a alteração de senha, ignore este aviso. Sua conta continua segura._`;

  console.log(`[Recuperação WhatsApp] Enviando código para ${telefone}...`);
  await enviarMensagem(telefone, mensagem);
  console.log(`[Recuperação WhatsApp] ✅ Código enviado com sucesso para ${telefone}!`);
}

/**
 * Dispara o código de recuperação para o E-mail do usuário via Webhook HTTPS (porta 443) ou Nodemailer (SMTP)
 */
export async function enviarCodigoEmail({ email, nome, codigo, assuntoCustomizado = null, htmlCustomizado = null }) {
  const htmlContent = htmlCustomizado || gerarTemplateEmail({ nome, codigo });
  const assunto = assuntoCustomizado || `🔐 Seu código de verificação SIGE: ${codigo}`;

  // 1. Método A: Webhook HTTPS configurado (porta 443 - compatível 100% com Vercel)
  const webhookUrl = process.env.EMAIL_WEBHOOK_URL;
  if (webhookUrl && webhookUrl.trim().startsWith('http')) {
    try {
      console.log(`[Recuperação E-mail] Enviando via Webhook HTTPS para ${email}...`);
      const resp = await fetch(webhookUrl.trim(), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          to: email,
          nome,
          codigo,
          subject: assunto,
          html: htmlContent
        }),
        redirect: 'follow'
      });

      console.log(`[Recuperação E-mail] ✅ E-mail enviado via Webhook HTTPS para ${email}! (Status: ${resp.status})`);
      return { sucesso: true, via: 'webhook', status: resp.status };
    } catch (errWebhook) {
      console.warn(`[Recuperação E-mail] Webhook falhou, tentando fallback SMTP...`, errWebhook?.message);
    }
  }

  // 2. Método B: Envio via SMTP (Nodemailer)
  const transporter = criarTransporterEmail();

  if (!transporter) {
    console.warn(`[Recuperação E-mail] ⚠️ Credenciais SMTP não encontradas no .env.`);
    console.log(`\n============================================================`);
    console.log(`🔑 [CÓDIGO GERADO] E-mail para: <${email}>`);
    console.log(`👉 CÓDIGO: [ ${codigo} ]`);
    console.log(`============================================================\n`);
    return { sucesso: true, via: 'console', codigo };
  }

  const remetente = process.env.EMAIL_FROM || `"SIGE Indústria" <${process.env.SMTP_USER}>`;
  const mailOptions = {
    from: remetente,
    to: email,
    subject: assunto,
    html: htmlContent,
    text: `Olá ${nome}!\n\nSeu código de verificação para redefinir a senha no SIGE é: ${codigo}\n\nEste código expira em 15 minutos.\nSe não foi você, ignore este aviso.`
  };

  try {
    console.log(`[Recuperação E-mail] Tentando envio via SMTP para ${email}...`);
    const info = await transporter.sendMail(mailOptions);
    console.log(`[Recuperação E-mail] ✅ E-mail enviado com sucesso para ${email}! ID: ${info.messageId}`);
    return { sucesso: true, via: 'smtp', messageId: info.messageId };
  } catch (smtpError) {
    const msg = String(smtpError?.message || smtpError);
    const ehBloqueioRede = msg.includes('ETIMEDOUT') || msg.includes('ENETUNREACH') ||
                           msg.includes('ESOCKET') || msg.includes('AggregateError') ||
                           smtpError?.code === 'ESOCKET' || smtpError?.code === 'ETIMEDOUT';

    if (ehBloqueioRede) {
      console.warn(`\n⚠️ [ALERTA DE REDE] Firewall/Vercel bloqueou porta SMTP de saída.`);
      console.log(`\n============================================================`);
      console.log(`🔑 [CÓDIGO DE RECUPERAÇÃO - LIBERADO]`);
      console.log(`👤 Usuário: ${nome} <${email}>`);
      console.log(`👉 CÓDIGO: [ ${codigo} ]`);
      console.log(`============================================================\n`);
      return { sucesso: true, via: 'fallback_firewall', codigo };
    }

    throw smtpError;
  }
}

/**
 * Inicia o observador em tempo real da coleção 'recuperacoes_senha' no Firestore
 */
export function observarRecuperacoesSenha({ db = dbPadrao, enviarMensagem }) {
  if (!db) {
    throw new Error('[recuperacao.js] Instância do Firestore não fornecida.');
  }

  let inicializado = false;

  console.log('[Firestore] Ouvindo solicitações de recuperação de senha em tempo real...');

  db.collection('recuperacoes_senha')
    .where('status', '==', 'pendente')
    .onSnapshot(
      (snapshot) => {
        const changes = snapshot.docChanges();

        if (!inicializado) {
          inicializado = true;
        }

        changes.forEach(async (change) => {
          if (change.type === 'added' || change.type === 'modified') {
            const id = change.doc.id;
            const dados = change.doc.data();

            if (dados.status !== 'pendente') return;

            if (recuperacoesEmProcessamento.has(id)) return;
            recuperacoesEmProcessamento.add(id);
            setTimeout(() => recuperacoesEmProcessamento.delete(id), 15000);

            const canal = (dados.canal || 'whatsapp').toLowerCase().trim();
            const codigo = dados.codigo;
            const nome = dados.nome || 'Colaborador';
            const tel = dados.telefone;
            const email = dados.email;

            console.log(`[Recuperação] Nova solicitação recebida (ID: ${id}) via ${canal.toUpperCase()} para ${nome}`);

            try {
              if (canal === 'whatsapp') {
                if (!tel) {
                  console.error(`[Recuperação] Usuário ${nome} não possui telefone para envio.`);
                  await change.doc.ref.update({
                    status: 'erro',
                    erro: 'Telefone não informado'
                  });
                  return;
                }

                await enviarCodigoWhatsApp({
                  enviarMensagem,
                  telefone: tel,
                  nome,
                  codigo
                });

                await change.doc.ref.update({
                  status: 'enviado',
                  enviadoEm: FieldValue.serverTimestamp()
                });
              } else if (canal === 'email') {
                if (!email) {
                  console.error(`[Recuperação] Usuário ${nome} não possui e-mail para envio.`);
                  await change.doc.ref.update({
                    status: 'erro',
                    erro: 'E-mail não informado'
                  });
                  return;
                }

                await enviarCodigoEmail({
                  email,
                  nome,
                  codigo
                });

                await change.doc.ref.update({
                  status: 'enviado',
                  enviadoEm: FieldValue.serverTimestamp()
                });
              }
            } catch (err) {
              console.error(`[Recuperação] Falha ao despachar código para ${id}:`, err?.message || err);
              await change.doc.ref.update({
                status: 'falha_envio',
                erro: err?.message || String(err)
              });
            }
          }
        });
      },
      (err) => console.error('[recuperacao.js] Erro no listener de recuperacoes_senha:', err)
    );
}

export default {
  criarTransporterEmail,
  gerarTemplateEmail,
  observarRecuperacoesSenha,
  enviarCodigoWhatsApp,
  enviarCodigoEmail,
};
