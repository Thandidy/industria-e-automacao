/**
 * Script de diagnóstico e limpeza da coleção 'ocorrencias' no Firestore.
 * Uso: node scripts/limpar_ocorrencias.mjs [--dry-run] [--apagar-todas]
 *
 * Modos:
 *   (padrão)      → só exibe o diagnóstico, não apaga nada
 *   --dry-run     → igual ao padrão, mostra o que SERIA feito
 *   --limpar      → remove ocorrências finalizadas + duplicatas (mantém a mais recente por máquina)
 *   --apagar-todas → apaga TUDO na coleção (use com cuidado!)
 */

import { getFirebaseAdmin } from '../api/firebase.js';

const args = process.argv.slice(2);
const MODO_LIMPAR      = args.includes('--limpar');
const MODO_APAGAR_TUDO = args.includes('--apagar-todas');
const DRY_RUN          = !MODO_LIMPAR && !MODO_APAGAR_TUDO;

const { db } = getFirebaseAdmin();

// Status numéricos usados pelo Flutter (enum index)
const STATUS_MAP = {
  0: 'aberta',
  1: 'emAndamento',
  2: 'aguardandoMaterial',
  3: 'aguardandoAprovacao',
  4: 'finalizada',
};

function resolverStatus(raw) {
  if (typeof raw === 'number') return STATUS_MAP[raw] ?? `desconhecido(${raw})`;
  if (typeof raw === 'string') return raw.trim().toLowerCase() || 'vazio';
  return 'nulo';
}

function ehFinalizada(statusRaw) {
  const s = resolverStatus(statusRaw);
  return s === 'finalizada' || s === '4' || s === '3' && false;
}

async function main() {
  console.log('\n🔍 Lendo coleção "ocorrencias"...\n');

  const snap = await db.collection('ocorrencias').get();
  if (snap.empty) {
    console.log('✅ Coleção está vazia. Nada a fazer.');
    return;
  }

  const docs = snap.docs.map(d => ({ _id: d.id, ref: d.ref, ...d.data() }));
  console.log(`📦 Total de documentos encontrados: ${docs.length}\n`);

  // ─── Diagnóstico ─────────────────────────────────────────────────────────────
  const porMaquina = new Map();
  const semEquipamento = [];
  const problematicos = [];

  for (const doc of docs) {
    const eqId = doc.equipamentoId || doc.equipamentoTag || null;
    const status = resolverStatus(doc.status);
    const criacao = doc.dataAbertura || doc.criadoEm || null;

    console.log(`  📄 ${doc._id}`);
    console.log(`     Equipamento : ${eqId ?? '⚠️ AUSENTE'}`);
    console.log(`     Status      : ${status}`);
    console.log(`     Prioridade  : ${doc.prioridade ?? '⚠️ AUSENTE'}`);
    console.log(`     Motivo      : ${doc.motivo ?? doc.descricao ?? '—'}`);
    console.log(`     Abertura    : ${criacao ?? '⚠️ AUSENTE'}`);
    console.log(`     Técnico     : ${doc.tecnicoDesignado ?? '—'}`);
    console.log(`     Mat. Pausa  : ${doc.motivoPausaMaterial ?? '—'}`);
    console.log('');

    if (!eqId) {
      semEquipamento.push(doc);
    }

    if (!doc.prioridade) {
      problematicos.push({ doc, problema: 'sem campo prioridade' });
    }

    if (eqId) {
      if (!porMaquina.has(eqId)) porMaquina.set(eqId, []);
      porMaquina.get(eqId).push({ doc, status, criacao });
    }
  }

  // ─── Identificar o que deve ser removido ────────────────────────────────────
  const paraRemover = new Set();

  // 1. Sem equipamento associado
  for (const doc of semEquipamento) {
    console.log(`⚠️  Sem equipamento: ${doc._id}`);
    paraRemover.add(doc._id);
  }

  // 2. Finalizadas
  for (const doc of docs) {
    if (ehFinalizada(doc.status)) {
      console.log(`🏁 Finalizada: ${doc._id} (${doc.equipamentoTag ?? doc.equipamentoId})`);
      paraRemover.add(doc._id);
    }
  }

  // 3. Duplicatas ativas por máquina (mantém a mais recente)
  for (const [eqId, lista] of porMaquina.entries()) {
    const ativas = lista.filter(({ status }) =>
      !['finalizada', '4'].includes(status)
    );
    if (ativas.length > 1) {
      // Ordena: mais recente primeiro
      ativas.sort((a, b) => {
        const ta = new Date(a.criacao ?? 0).getTime();
        const tb = new Date(b.criacao ?? 0).getTime();
        return tb - ta;
      });
      console.log(`\n🔁 Duplicatas ativas para equipamento ${eqId}:`);
      for (let i = 0; i < ativas.length; i++) {
        const { doc } = ativas[i];
        if (i === 0) {
          console.log(`   ✅ Mantém (mais recente): ${doc._id}`);
        } else {
          console.log(`   🗑️  Remove (duplicata): ${doc._id}`);
          paraRemover.add(doc._id);
        }
      }
    }
  }

  // ─── Resumo ──────────────────────────────────────────────────────────────────
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`📊 RESUMO DO DIAGNÓSTICO`);
  console.log(`   Total de documentos   : ${docs.length}`);
  console.log(`   Sem equipamento       : ${semEquipamento.length}`);
  console.log(`   Finalizadas           : ${docs.filter(d => ehFinalizada(d.status)).length}`);
  console.log(`   Duplicatas ativas     : ${paraRemover.size - semEquipamento.length - docs.filter(d => ehFinalizada(d.status)).length}`);
  console.log(`   Para remover (total)  : ${paraRemover.size}`);
  console.log(`   Serão mantidas        : ${docs.length - paraRemover.size}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  if (problematicos.length > 0) {
    console.log(`⚠️  Documentos com campos faltando (serão mantidos, mas precisam de atenção):`);
    for (const { doc, problema } of problematicos) {
      if (!paraRemover.has(doc._id)) {
        console.log(`   ${doc._id} → ${problema}`);
      }
    }
    console.log('');
  }

  // ─── Execução ────────────────────────────────────────────────────────────────
  if (MODO_APAGAR_TUDO) {
    console.log('⚠️  MODO --apagar-todas: Removendo TODOS os documentos...');
    const batch = db.batch();
    docs.forEach(d => batch.delete(d.ref));
    await batch.commit();
    console.log(`✅ ${docs.length} documentos removidos.`);
    return;
  }

  if (MODO_LIMPAR) {
    if (paraRemover.size === 0) {
      console.log('✅ Nenhum documento para remover. Coleção está limpa!');
      return;
    }
    console.log(`🗑️  MODO --limpar: Removendo ${paraRemover.size} documento(s)...`);
    const docsParaRemover = docs.filter(d => paraRemover.has(d._id));
    const batch = db.batch();
    docsParaRemover.forEach(d => batch.delete(d.ref));
    await batch.commit();
    console.log(`✅ ${paraRemover.size} documento(s) removido(s) com sucesso.`);
    console.log(`📦 Restam ${docs.length - paraRemover.size} documento(s) na coleção.`);
    return;
  }

  // Dry-run (padrão)
  if (paraRemover.size > 0) {
    console.log(`💡 Para executar a limpeza, rode:`);
    console.log(`   node scripts/limpar_ocorrencias.mjs --limpar\n`);
    console.log(`💡 Para apagar TUDO e recomeçar do zero:`);
    console.log(`   node scripts/limpar_ocorrencias.mjs --apagar-todas\n`);
  } else {
    console.log('✅ Coleção está limpa! Nenhum documento problemático encontrado.\n');
  }
}

main().catch(err => {
  console.error('❌ Erro:', err.message);
  process.exit(1);
});
