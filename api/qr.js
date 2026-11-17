// api/qr.js
import { connectToWhatsApp, getWhatsAppState } from './whatsapp.js';
import { inicializarBot } from './index.js';

export default async function handler(req, res) {
  // Garante que o bot esteja inicializando
  try {
    await inicializarBot({ printTerminal: false });
  } catch (e) {
    console.error('[QR Handler] Erro ao inicializar bot:', e);
  }

  const state = getWhatsAppState();
  const format = req.query.format || '';
  const acceptHeader = req.headers.accept || '';

  // 1. Resposta em formato JSON
  if (format === 'json' || acceptHeader.includes('application/json')) {
    return res.status(200).json({
      status: state.status,
      connected: state.status === 'connected',
      hasQR: state.hasQR,
      qrDataUrl: state.qrDataUrl,
      lastDisconnectReason: state.lastDisconnectReason,
      timestamp: new Date().toISOString()
    });
  }

  // 2. Resposta em formato Imagem Direta PNG
  if (format === 'image' || acceptHeader.startsWith('image/')) {
    if (state.qrDataUrl) {
      const base64 = state.qrDataUrl.split(',')[1];
      const imgBuffer = Buffer.from(base64, 'base64');
      res.setHeader('Content-Type', 'image/png');
      res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
      return res.status(200).send(imgBuffer);
    } else {
      res.setHeader('Content-Type', 'application/json');
      return res.status(200).json({
        status: state.status,
        message: state.status === 'connected' ? 'WhatsApp já conectado.' : 'QR Code ainda não gerado.'
      });
    }
  }

  // 3. Resposta em Página HTML interativa e responsiva
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');

  const html = `
  <!DOCTYPE html>
  <html lang="pt-BR">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Conexão WhatsApp - SIGE</title>
    <style>
      * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
      body { background: #0f172a; color: #f8fafc; min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 20px; }
      .card { background: #1e293b; border: 1px solid #334155; border-radius: 16px; padding: 32px; max-width: 480px; width: 100%; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3); text-align: center; }
      .logo { font-size: 32px; margin-bottom: 12px; }
      h1 { font-size: 22px; font-weight: 700; margin-bottom: 8px; color: #ffffff; }
      p.subtitle { font-size: 14px; color: #94a3b8; margin-bottom: 24px; }
      .qr-box { background: #ffffff; padding: 16px; border-radius: 12px; display: inline-block; margin-bottom: 20px; box-shadow: 0 4px 12px rgba(0,0,0,0.15); min-width: 260px; min-height: 260px; display: flex; align-items: center; justify-content: center; }
      .qr-box img { width: 250px; height: 250px; display: block; }
      .badge { display: inline-block; padding: 8px 16px; border-radius: 9999px; font-size: 13px; font-weight: 600; margin-bottom: 16px; }
      .badge.connected { background: #065f46; color: #6ee7b7; border: 1px solid #059669; }
      .badge.waiting { background: #854d0e; color: #fde047; border: 1px solid #ca8a04; }
      .badge.connecting { background: #1e3a8a; color: #93c5fd; border: 1px solid #2563eb; }
      .instructions { font-size: 13px; color: #cbd5e1; text-align: left; background: #0f172a; padding: 16px; border-radius: 10px; margin-bottom: 20px; line-height: 1.6; border: 1px solid #334155; }
      .instructions ol { padding-left: 20px; }
      .btn { background: #0284c7; color: white; border: none; padding: 12px 24px; border-radius: 8px; font-size: 14px; font-weight: 600; cursor: pointer; transition: background 0.2s; width: 100%; }
      .btn:hover { background: #0369a1; }
      .auto-reload { font-size: 12px; color: #64748b; margin-top: 12px; }
    </style>
  </head>
  <body>
    <div class="card">
      <div class="logo">🏭</div>
      <h1>Conexão WhatsApp (SIGE)</h1>
      <p class="subtitle">Integração oficial de notificações do Chão de Fábrica</p>

      ${state.status === 'connected' ? `
        <div class="badge connected">✅ WhatsApp Conectado e Operando!</div>
        <p style="color: #cbd5e1; font-size: 14px; margin-bottom: 24px;">
          O bot está conectado e pronto para despachar mensagens de ocorrências, máquinas e recuperação de senha.
        </p>
        <button class="btn" onclick="location.reload()">Verificar Novamente</button>
      ` : state.hasQR ? `
        <div class="badge waiting">📷 Escaneie o QR Code abaixo</div>
        <div class="qr-box">
          <img src="${state.qrDataUrl}" alt="WhatsApp QR Code">
        </div>
        <div class="instructions">
          <strong>Como conectar:</strong>
          <ol>
            <li>Abra o <strong>WhatsApp</strong> no celular</li>
            <li>Toque em <strong>Configurações</strong> ou <strong>Menu ⋮</strong></li>
            <li>Selecione <strong>Aparelhos Conectados</strong> > <strong>Conectar um aparelho</strong></li>
            <li>Aponte a câmera para esta tela</li>
          </ol>
        </div>
        <button class="btn" onclick="location.reload()">Atualizar QR Code</button>
        <p class="auto-reload">Esta página atualiza automaticamente a cada 5 segundos...</p>
        <script>
          setTimeout(() => location.reload(), 5000);
        </script>
      ` : `
        <div class="badge connecting">⏳ Conectando socket WhatsApp...</div>
        <p style="color: #cbd5e1; font-size: 14px; margin: 24px 0;">
          Aguardando geração do QR Code pelo servidor. Por favor, aguarde alguns instantes.
        </p>
        <button class="btn" onclick="location.reload()">Atualizar Agora</button>
        <script>
          setTimeout(() => location.reload(), 3000);
        </script>
      `}
    </div>
  </body>
  </html>
  `;

  return res.status(200).send(html);
}
