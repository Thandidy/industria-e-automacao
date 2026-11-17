// bot/start.js
import { inicializarBot } from '../api/index.js';
import dotenv from 'dotenv';

dotenv.config();

console.log('====================================================');
console.log('🏭 SIGE INDUSTRIAL - BOT WHATSAPP & INTEGRAÇÕES');
console.log('====================================================');
console.log('Iniciando conexão Baileys e ouvintes do Firestore...\n');

inicializarBot({ printTerminal: true })
  .then(() => {
    console.log('🚀 Serviço em execução contínua.');
  })
  .catch((err) => {
    console.error('❌ Erro fatal ao iniciar o bot:', err);
    process.exit(1);
  });
