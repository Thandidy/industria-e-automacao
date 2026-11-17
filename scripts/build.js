// scripts/build.js
import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';

console.log('[Build] ==========================================');
console.log('[Build] Processo de Build SIGE (Vercel & Monorepo)');
console.log('[Build] ==========================================');

const rootDir = process.cwd();
const buildWebDir = path.resolve(rootDir, 'build', 'web');
const indexExiste = fs.existsSync(path.join(buildWebDir, 'index.html'));

if (indexExiste) {
  console.log('[Build] ✅ Arquivos compilados do Flutter Web detectados em build/web!');
} else {
  console.log('[Build] ⚠️ build/web/index.html não encontrado. Tentando compilar...');

  function comandoDisponivel(cmd) {
    try {
      execSync(`${cmd} --version`, { stdio: 'ignore' });
      return true;
    } catch (_) {
      return false;
    }
  }

  let flutterBin = 'flutter';

  if (!comandoDisponivel('flutter')) {
    const localFlutter = path.resolve(rootDir, '_flutter', 'bin', 'flutter');
    if (fs.existsSync(localFlutter)) {
      flutterBin = localFlutter;
    } else if (process.env.VERCEL || process.platform === 'linux') {
      console.log('[Build] 📥 Baixando Flutter SDK portátil para a Vercel...');
      try {
        execSync('git clone --depth 1 -b stable https://github.com/flutter/flutter.git ./_flutter', {
          stdio: 'inherit'
        });
        flutterBin = path.resolve(rootDir, '_flutter', 'bin', 'flutter');
      } catch (err) {
        console.warn('[Build] ⚠️ Falha ao baixar Flutter SDK:', err.message);
      }
    }
  }

  try {
    console.log(`[Build] 🔨 Compilando Flutter Web com: ${flutterBin}...`);
    execSync(`${flutterBin} config --no-analytics`, { stdio: 'ignore' });
    execSync(`${flutterBin} build web --release --no-pub`, { stdio: 'inherit' });
    console.log('[Build] ✅ Flutter Web compilado com sucesso!');
  } catch (e) {
    console.warn('[Build] ℹ️ Não foi possível compilar no ambiente:', e.message);
  }
}

// Sincroniza para pastas aceitas pelo Vercel (public e dist)
if (fs.existsSync(buildWebDir)) {
  const destinos = [
    path.resolve(rootDir, 'public'),
    path.resolve(rootDir, 'dist')
  ];

  for (const dest of destinos) {
    try {
      fs.cpSync(buildWebDir, dest, { recursive: true, force: true });
      console.log(`[Build] 📁 Sincronizado para pasta: ${path.basename(dest)}`);
    } catch (_) {}
  }
}

console.log('[Build] 🚀 Build concluído com sucesso e pronto para o Vercel!');
