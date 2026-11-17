import { initializeApp, cert, getApps, getApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

let firestoreInstance = null;
let appInstance = null;

export function getFirebaseAdmin() {
  if (firestoreInstance && appInstance) {
    return { app: appInstance, db: firestoreInstance, FieldValue };
  }

  if (getApps().length > 0) {
    appInstance = getApp();
    firestoreInstance = getFirestore(appInstance);
    return { app: appInstance, db: firestoreInstance, FieldValue };
  }

  let serviceAccount = null;

  // 1. Prioridade: Variável de ambiente (ideal para deploy público no Vercel)
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    try {
      const rawEnv = process.env.FIREBASE_SERVICE_ACCOUNT.trim();
      if (rawEnv.startsWith('{')) {
        serviceAccount = JSON.parse(rawEnv);
      } else {
        // Se estiver em base64
        const decoded = Buffer.from(rawEnv, 'base64').toString('utf8');
        serviceAccount = JSON.parse(decoded);
      }
    } catch (e) {
      console.error('[Firebase] Erro ao parsear FIREBASE_SERVICE_ACCOUNT:', e.message);
    }
  }

  // 2. Fallback: Arquivo firebase-key.json local
  if (!serviceAccount) {
    const possíveisCaminhos = [
      path.resolve(process.cwd(), 'firebase-key.json'),
      path.resolve(__dirname, '..', 'firebase-key.json'),
      path.resolve(__dirname, 'firebase-key.json'),
      './firebase-key.json'
    ];

    for (const caminho of possíveisCaminhos) {
      if (fs.existsSync(caminho)) {
        try {
          const raw = fs.readFileSync(caminho, 'utf8');
          serviceAccount = JSON.parse(raw);
          break;
        } catch (_) {}
      }
    }
  }

  if (!serviceAccount) {
    console.warn('[Firebase] ⚠️ Nenhuma credencial encontrada em firebase-key.json ou FIREBASE_SERVICE_ACCOUNT.');
  }

  appInstance = initializeApp({
    credential: serviceAccount ? cert(serviceAccount) : undefined
  });
  firestoreInstance = getFirestore(appInstance);

  return { app: appInstance, db: firestoreInstance, FieldValue };
}

export const { app, db } = getFirebaseAdmin();
export { FieldValue };
export default db;
