// api/status.js
import { getWhatsAppState } from './whatsapp.js';
import { db } from './firebase.js';

export default async function handler(req, res) {
  let firestoreOk = false;
  let firestoreError = null;

  try {
    // Teste leve no Firestore
    const testDoc = await db.collection('sistema').doc('status').get().catch(() => null);
    firestoreOk = true;
  } catch (err) {
    firestoreError = err.message;
  }

  const waState = getWhatsAppState();

  const status = {
    sistema: 'SIGE - Indústria & Manutenção',
    versao: '1.0.0',
    timestamp: new Date().toISOString(),
    servicos: {
      firebase: {
        conectado: firestoreOk,
        erro: firestoreError
      },
      whatsapp: {
        status: waState.status,
        conectado: waState.status === 'connected',
        aguardandoQR: waState.hasQR,
        telefoneChefeConfigurado: !!waState.telefoneChefe,
        lidChefeConfigurado: !!waState.lidChefe
      },
      email: {
        smtpHost: process.env.SMTP_HOST || 'não configurado',
        smtpPort: process.env.SMTP_PORT || 'não configurado',
        smtpUser: process.env.SMTP_USER ? 'configurado' : 'não configurado',
        webhookConfigurado: !!process.env.EMAIL_WEBHOOK_URL
      }
    }
  };

  return res.status(200).json(status);
}
