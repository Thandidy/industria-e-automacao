/**
 * Script para resetar o status de todas as máquinas para 'operando'.
 * Uso: node scripts/resetar_maquinas.mjs [--dry-run]
 */

import { getFirebaseAdmin } from '../api/firebase.js';

const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');

const { db } = getFirebaseAdmin();

async function main() {
  console.log('\n🔍 Lendo coleção "maquinas"...\n');

  const snap = await db.collection('maquinas').get();
  if (snap.empty) {
    console.log('⚠️  Nenhuma máquina encontrada.');
    return;
  }

  const docs = snap.docs.map(d => ({ _id: d.id, ref: d.ref, ...d.data() }));
  console.log(`📦 Total de máquinas: ${docs.length}\n`);

  const paraResetar = docs.filter(d => {
    const st = String(d.status ?? '').toLowerCase();
    return st !== 'operando';
  });

  for (const d of docs) {
    const st = String(d.status ?? '').toLowerCase();
    const icon = st === 'operando' ? '✅' : '🔴';
    console.log(`  ${icon} ${d.tag ?? d._id.slice(0,8)} — status: ${d.status ?? 'nulo'} | grauCritico: ${d.grauCritico} | tecnico: ${d.tecnicoDesignado ?? '—'}`);
  }

  console.log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  console.log(`  Precisam de reset : ${paraResetar.length}`);
  console.log(`  Já em 'operando'  : ${docs.length - paraResetar.length}`);
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`);

  if (paraResetar.length === 0) {
    console.log('✅ Todas as máquinas já estão em "operando". Nada a fazer.');
    return;
  }

  if (DRY_RUN) {
    console.log('💡 Modo --dry-run: nenhuma alteração feita.');
    console.log('   Rode sem --dry-run para aplicar o reset.\n');
    return;
  }

  // Aplica em lotes de 500 (limite do Firestore batch)
  const LOTE = 500;
  for (let i = 0; i < paraResetar.length; i += LOTE) {
    const lote = paraResetar.slice(i, i + LOTE);
    const batch = db.batch();
    for (const d of lote) {
      batch.update(d.ref, {
        status: 'operando',
        grauCritico: false,
        aprovadaManutencao: false,
        solicitouMaterial: false,
        motivoParada: null,
        motivoPausaMaterial: null,
        prioridade: null,
        tecnicoDesignado: null,
        tecnicoDesignadoId: null,
        solicitarAtendimentoUrgente: false,
        ultimoAtualizacao: new Date().toISOString(),
      });
    }
    await batch.commit();
    console.log(`  ✅ Lote ${Math.floor(i / LOTE) + 1}: ${lote.length} máquina(s) resetada(s).`);
  }

  console.log(`\n🎉 ${paraResetar.length} máquina(s) resetada(s) para "operando" com sucesso!\n`);
}

main().catch(err => {
  console.error('❌ Erro:', err.message);
  process.exit(1);
});
