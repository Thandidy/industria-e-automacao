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

  // 1. Resposta JSON (usado pelo aplicativo Flutter na Dashboard do Gestor)
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

  // 3. Acesso direto via navegador redireciona para a Dashboard
  // A conexão do WhatsApp é realizada exclusivamente dentro da Dashboard pelo Perfil Gestor
  res.setHeader('Location', '/#/dashboard');
  return res.status(302).send(`
    <!DOCTYPE html>
    <html>
      <head>
        <meta http-equiv="refresh" content="0; url=/#/dashboard" />
        <title>Redirecionando...</title>
      </head>
      <body>
        <p>A conexão com o WhatsApp agora é realizada exclusivamente através da Dashboard pelo Gestor. Redirecionando...</p>
      </body>
    </html>
  `);
}
