// bot/start.js
import { inicializarBot } from '../api/index.js';
import dotenv from 'dotenv';

dotenv.config();

// Filtra ruídos internos da biblioteca de criptografia do WhatsApp (libsignal / Baileys)
const silenciarPadroes = (texto) => {
  if (typeof texto !== 'string') return false;
  return (
    texto.includes('Bad MAC') ||
    texto.includes('Failed to decrypt') ||
    texto.includes('Session error') ||
    texto.includes('SessionCipher') ||
    texto.includes('Closing session') ||
    texto.includes('SessionEntry')
  );
};

// Sobrescreve console.info para calar o console.info("Closing session:", ...) do libsignal
const originalConsoleInfo = console.info.bind(console);
console.info = (...args) => {
  const msg = args.map(a => (typeof a === 'object' ? JSON.stringify(a) : String(a))).join(' ');
  if (silenciarPadroes(msg)) return;
  originalConsoleInfo(...args);
};

const originalStderrWrite = process.stderr.write.bind(process.stderr);
process.stderr.write = (chunk, encoding, callback) => {
  const str = chunk ? chunk.toString() : '';
  if (silenciarPadroes(str)) {
    if (typeof callback === 'function') callback();
    return true;
  }
  return originalStderrWrite(chunk, encoding, callback);
};

const originalStdoutWrite = process.stdout.write.bind(process.stdout);
process.stdout.write = (chunk, encoding, callback) => {
  const str = chunk ? chunk.toString() : '';
  if (silenciarPadroes(str)) {
    if (typeof callback === 'function') callback();
    return true;
  }
  return originalStdoutWrite(chunk, encoding, callback);
};

console.log('====================================================');
console.log('🏭 SIGE INDUSTRIAL - BOT WHATSAPP & INTEGRAÇÕES');
console.log('====================================================');
console.log('Iniciando conexão Baileys e ouvintes do Firestore...\n');

import http from 'http';
import handlerDecidir from '../api/decidir.js';

// Servidor HTTP local para processar decisões dos links de e-mail e web sem depender da Vercel
const PORT = process.env.PORT || 3000;
const server = http.createServer(async (req, res) => {
  const reqUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  if (reqUrl.pathname === '/api/decidir') {
    const query = Object.fromEntries(reqUrl.searchParams.entries());
    const mockReq = {
      query,
      body: {},
      method: req.method,
      headers: req.headers,
    };
    const mockRes = {
      statusCode: 200,
      setHeader: (k, v) => res.setHeader(k, v),
      status: function (code) {
        this.statusCode = code;
        return this;
      },
      json: function (data) {
        res.writeHead(this.statusCode, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify(data));
      },
      send: function (body) {
        res.writeHead(this.statusCode, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(body);
      },
      end: () => res.end(),
    };
    try {
      await handlerDecidir(mockReq, mockRes);
    } catch (e) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ sucesso: false, erro: e.message }));
    }
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
  }
});

import { spawn } from 'child_process';
import fs from 'fs';

// Função para iniciar o túnel Cloudflare automaticamente
function iniciarCloudflareTunnel(porta) {
  const possiveisCaminhos = [
    'cloudflared',
    'C:\\Program Files (x86)\\cloudflared\\cloudflared.exe',
    'C:\\Program Files\\cloudflared\\cloudflared.exe',
  ];
  const binario = possiveisCaminhos.find(p => fs.existsSync(p)) || 'cloudflared';

  try {
    const proc = spawn(binario, ['tunnel', '--url', `http://127.0.0.1:${porta}`], {
      stdio: ['ignore', 'pipe', 'pipe'],
      windowsHide: true,
    });

    const regexUrl = /https:\/\/[a-z0-9-]+\.trycloudflare\.com/i;

    const capturarUrl = (data) => {
      const texto = data.toString();
      const match = texto.match(regexUrl);
      if (match && !globalThis.__CLOUDFLARE_URL__) {
        globalThis.__CLOUDFLARE_URL__ = match[0];
        console.log('\n====================================================');
        console.log('⚡ CLOUDFLARE TUNNEL ATIVO (Mundial / 4G / Wi-Fi):');
        console.log(`🔗 ${match[0]}`);
        console.log('Os botões de e-mail agora usarão este link seguro HTTPS!');
        console.log('====================================================\n');
      }
    };

    proc.stdout.on('data', capturarUrl);
    proc.stderr.on('data', capturarUrl);

    proc.on('error', (e) => {
      console.warn('[Cloudflare Tunnel] Não foi possível iniciar automaticamente:', e.message);
    });

    process.on('exit', () => {
      try { proc.kill(); } catch (_) {}
    });
  } catch (err) {
    console.warn('[Cloudflare Tunnel] Inicialização pulada:', err.message);
  }
}

server.listen(PORT, '0.0.0.0', () => {
  console.log(`🌐 Servidor local de decisão ativo em: http://localhost:${PORT}/api/decidir`);
  iniciarCloudflareTunnel(PORT);
});

inicializarBot({ printTerminal: true })
  .then(() => {
    console.log('🚀 Serviço em execução contínua.');
  })
  .catch((err) => {
    console.error('❌ Erro fatal ao iniciar o bot:', err);
    process.exit(1);
  });
