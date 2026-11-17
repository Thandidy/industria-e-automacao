// scripts/build.js
import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';

console.log('[Build] Verificando ambiente de build do Flutter Web...');

const buildWebDir = path.resolve(process.cwd(), 'build', 'web');

try {
  // Testa se o comando flutter está disponível
  execSync('flutter --version', { stdio: 'ignore' });
  console.log('[Build] Flutter SDK detectado! Compilando Flutter Web...');
  execSync('flutter build web --release', { stdio: 'inherit' });
  console.log('[Build] ✅ Flutter Web compilado com sucesso em build/web!');
} catch (e) {
  console.log('[Build] ⚠️ Flutter SDK não encontrado no PATH do sistema de build.');
  if (fs.existsSync(path.join(buildWebDir, 'index.html'))) {
    console.log('[Build] ℹ️ Pasta build/web existente detectada! Servindo arquivos pré-compilados.');
  } else {
    console.warn('[Build] ⚠️ Dica: Compile seu Flutter Web localmente com "flutter build web --release" antes de subir, ou configure a Action de CI/CD do GitHub.');
  }
}
