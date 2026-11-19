// api/status.js
import { getWhatsAppState } from './whatsapp.js';
import { db } from './firebase.js';

export default async function handler(req, res) {
  let firestoreOk = false;
  let firestoreError = null;
  let botRemotoData = null;

  try {
    const waDoc = await db.collection('sistema').doc('whatsapp').get().catch(() => null);
    if (waDoc && waDoc.exists) {
      botRemotoData = waDoc.data();
    }
    firestoreOk = true;
  } catch (err) {
    firestoreError = err.message;
  }

  const waState = getWhatsAppState();
  const estaConectadoLocalOuRemoto = waState.status === 'connected' || botRemotoData?.conectado === true;

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
        status: estaConectadoLocalOuRemoto ? 'connected' : waState.status,
        conectado: estaConectadoLocalOuRemoto,
        aguardandoQR: waState.hasQR,
        telefoneChefeConfigurado: !!(waState.telefoneChefe || botRemotoData?.telefoneChefe),
        lidChefeConfigurado: !!(waState.lidChefe || botRemotoData?.lidChefeRecente),
        modoExecucao: botRemotoData?.conectado ? 'bot_local_ativo' : 'serverless',
        ultimoLidDetectado: botRemotoData?.lidChefeRecente || null
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
