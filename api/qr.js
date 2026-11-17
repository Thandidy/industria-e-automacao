// api/qr.js
import {
  connectToWhatsApp,
  getWhatsAppState,
  aguardarQRouConexao,
  obterDiretorioAuth
} from './whatsapp.js';
import { inicializarBot } from './index.js';
import fs from 'fs';

export default async function handler(req, res) {
  // Ação especial: resetar sessão para gerar novo QR Code
  if (req.query.action === 'reset') {
    const authFolder = obterDiretorioAuth();
    if (fs.existsSync(authFolder)) {
      try { fs.rmSync(authFolder, { recursive: true, force: true }); } catch (_) {}
    }
    const state = getWhatsAppState();
    if (state.sock) {
      try {
        state.sock.ev.removeAllListeners();
        state.sock.end?.();
      } catch (_) {}
    }
  }

  // Dispara inicialização do bot
  try {
    inicializarBot({ printTerminal: false }).catch(() => {});
  } catch (_) {}

  // Aguarda até o QR ser gerado ou até 8 segundos para responder já com o QR
  const state = await aguardarQRouConexao(8000);
  const format = req.query.format || '';
  const acceptHeader = req.headers.accept || '';

  // 1. Resposta JSON
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

  // 2. Resposta PNG direta
  if (format === 'image' || acceptHeader.startsWith('image/')) {
    if (state.qrDataUrl) {
      const base64 = state.qrDataUrl.split(',')[1];
      const imgBuffer = Buffer.from(base64, 'base64');
      res.setHeader('Content-Type', 'image/png');
      res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
      return res.status(200).send(imgBuffer);
    } else {
      return res.status(200).json({
        status: state.status,
        message: state.status === 'connected' ? 'WhatsApp já conectado.' : 'QR Code ainda não emitido.'
      });
    }
  }

  // 3. Página HTML com Auto-Refresh dinâmico
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
      .qr-box { background: #ffffff; padding: 16px; border-radius: 12px; margin: 0 auto 20px auto; box-shadow: 0 4px 12px rgba(0,0,0,0.15); width: 270px; height: 270px; display: flex; align-items: center; justify-content: center; }
      .qr-box img { width: 240px; height: 240px; display: block; border-radius: 8px; }
      .badge { display: inline-block; padding: 8px 16px; border-radius: 9999px; font-size: 13px; font-weight: 600; margin-bottom: 16px; }
      .badge.connected { background: #065f46; color: #6ee7b7; border: 1px solid #059669; }
      .badge.waiting { background: #854d0e; color: #fde047; border: 1px solid #ca8a04; }
      .badge.connecting { background: #1e3a8a; color: #93c5fd; border: 1px solid #2563eb; }
      .instructions { font-size: 13px; color: #cbd5e1; text-align: left; background: #0f172a; padding: 16px; border-radius: 10px; margin-bottom: 20px; line-height: 1.6; border: 1px solid #334155; }
      .instructions ol { padding-left: 20px; }
      .btn { background: #0284c7; color: white; border: none; padding: 12px 24px; border-radius: 8px; font-size: 14px; font-weight: 600; cursor: pointer; transition: background 0.2s; width: 100%; margin-top: 8px; }
      .btn:hover { background: #0369a1; }
      .btn-outline { background: transparent; border: 1px solid #475569; color: #cbd5e1; margin-top: 8px; }
      .btn-outline:hover { background: #334155; }
      .auto-reload { font-size: 12px; color: #64748b; margin-top: 14px; }
      .spinner { border: 3px solid rgba(255,255,255,0.1); border-top: 3px solid #38bdf8; border-radius: 50%; width: 40px; height: 40px; animation: spin 1s linear infinite; margin: 20px auto; }
      @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
    </style>
  </head>
  <body>
    <div class="card">
      <div class="logo">🏭</div>
      <h1>Conexão WhatsApp (SIGE)</h1>
      <p class="subtitle">Integração oficial de notificações do Chão de Fábrica</p>

      <div id="content-area">
        ${state.status === 'connected' ? `
          <div class="badge connected">✅ WhatsApp Conectado e Operando!</div>
          <p style="color: #cbd5e1; font-size: 14px; margin-bottom: 24px;">
            O bot está conectado e pronto para despachar mensagens de ocorrências, máquinas e recuperação de senha.
          </p>
          <button class="btn btn-outline" onclick="resetarConexao()">Desconectar / Trocar de WhatsApp</button>
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
        ` : `
          <div class="badge connecting">⏳ Estabelecendo conexão com o WhatsApp...</div>
          <div class="spinner"></div>
          <p style="color: #cbd5e1; font-size: 14px; margin: 16px 0;">
            O servidor está gerando a sessão do socket. O QR Code aparecerá automaticamente em instantes...
          </p>
        `}
      </div>

      <button class="btn" onclick="location.reload()">Atualizar Status</button>
      <p class="auto-reload" id="poll-status">Verificando atualizações em segundo plano...</p>
    </div>

    <script>
      let pollingAtivo = true;

      function resetarConexao() {
        if (confirm("Deseja realmente desconectar a sessão atual para gerar um novo QR Code?")) {
          location.href = "/api/qr?action=reset";
        }
      }

      async function checarStatus() {
        if (!pollingAtivo) return;
        try {
          const res = await fetch('/api/qr?format=json');
          if (res.ok) {
            const data = await res.json();
            if (data.connected) {
              document.getElementById('poll-status').innerText = '✅ Conectado!';
              location.reload();
              return;
            } else if (data.hasQR && data.qrDataUrl) {
              const currentImg = document.querySelector('.qr-box img');
              if (!currentImg || currentImg.src !== data.qrDataUrl) {
                location.reload();
                return;
              }
            }
          }
        } catch (_) {}
        setTimeout(checarStatus, 2500);
      }

      setTimeout(checarStatus, 2000);
    </script>
  </body>
  </html>
  `;

  return res.status(200).send(html);
}
