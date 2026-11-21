// api/decidir.js
import { db, FieldValue } from './firebase.js';
import { enviarEmail, gerarTemplateNotificacao } from './email.js';
import { enviarMensagemWhatsApp, getWhatsAppState } from './whatsapp.js';

export default async function handler(req, res) {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const id = req.query.id || req.body?.id;
  const acao = (req.query.acao || req.body?.acao || '').toLowerCase().trim();

  if (!id || (acao !== 'aprovar' && acao !== 'rejeitar')) {
    return res.status(400).send(`
      <!DOCTYPE html>
      <html>
      <head><meta charset="utf-8"><title>SIGE - Erro</title></head>
      <body style="font-family: sans-serif; text-align: center; padding: 40px; background: #0f172a; color: #fff;">
        <h2>❌ Requisição Inválida</h2>
        <p>Parâmetros 'id' e 'acao' (aprovar/rejeitar) são obrigatórios.</p>
      </body>
      </html>
    `);
  }

  try {
    const docRef = db.collection('solicitacoes_login').doc(id);
    const snap = await docRef.get();

    if (!snap.exists) {
      return res.status(404).send(`
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"><title>SIGE - Não Encontrado</title></head>
        <body style="font-family: sans-serif; text-align: center; padding: 40px; background: #0f172a; color: #fff;">
          <h2>❌ Solicitação não encontrada</h2>
          <p>O cadastro com ID <code>${id}</code> não existe ou já foi excluído.</p>
        </body>
        </html>
      `);
    }

    const dados = snap.data();
    const nome = dados.nome || dados.nomeFuncionario || 'Colaborador';

    if (dados.status !== 'pendente' && dados.status !== 'aguardando') {
      const corJaDecidido = (dados.status === 'aprovado' || dados.status === 'aprovada') ? '#16a34a' : '#dc2626';
      return res.status(200).send(`
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"><title>SIGE - Status</title></head>
        <body style="font-family: sans-serif; text-align: center; padding: 50px; background: #0f172a; color: #fff;">
          <div style="max-width: 480px; margin: 0 auto; background: #1e293b; padding: 32px; border-radius: 16px; border: 1px solid #334155;">
            <h2 style="color: ${corJaDecidido}; margin-bottom: 12px;">ℹ️ Solicitação já processada</h2>
            <p style="color: #cbd5e1; font-size: 16px;">O cadastro de <b>${nome}</b> já foi <b>${dados.status.toUpperCase()}</b> anteriormente.</p>
          </div>
        </body>
        </html>
      `);
    }

    const novoStatus = acao === 'aprovar' ? 'aprovado' : 'rejeitado';

    // 1. Atualiza a solicitação no Firestore
    await docRef.update({
      status: novoStatus,
      respondidoEm: FieldValue.serverTimestamp()
    });

    // 2. Se aprovado, insere o usuário ativo na coleção 'usuarios'
    if (novoStatus === 'aprovado') {
      await db.collection('usuarios').doc(id).set({
        nome: nome,
        email: dados.email,
        telefone: dados.telefone || '',
        perfil: dados.perfil || 'operador',
        senha: dados.senha,
        status: 'aprovado',
        criadoEm: dados.criadoEm || new Date().toISOString(),
        ultimoLogin: new Date().toISOString()
      }, { merge: true });

      // Notifica o funcionário por WhatsApp se bot local estiver ativo
      if (dados.telefone) {
        const msgWa = `🎉 *ACESSO APROVADO - SIGE INDUSTRIAL*\n\n` +
                      `Olá, *${nome}*! 👋\n` +
                      `Sua solicitação de acesso ao sistema *SIGE* foi *APROVADA* com sucesso pelo gestor!\n\n` +
                      `🏷️ *Perfil Autorizado:* ${(dados.perfil || 'operador').toUpperCase()}\n` +
                      `📧 *Login:* ${dados.email}\n\n` +
                      `👉 Você já pode abrir o aplicativo e fazer login com sua senha cadastrada. Bom trabalho!`;

        const waState = getWhatsAppState();
        if (waState.status === 'connected') {
          enviarMensagemWhatsApp(dados.telefone, msgWa).catch(() => {});
        }
      }

      // Notifica o funcionário por E-mail (se e-mail for válido)
      const emailFuncionario = (dados.email || '').trim();
      if (emailFuncionario && emailFuncionario.includes('@')) {
        const htmlAprovado = gerarTemplateNotificacao({
          titulo: '🎉 Seu Acesso foi Aprovado!',
          subtitulo: 'Bem-vindo ao SIGE - Indústria & Manutenção',
          corHeader: '#16a34a',
          itens: [
            { label: 'Colaborador', valor: nome },
            { label: 'Login / E-mail', valor: emailFuncionario },
            { label: 'Perfil Concedido', valor: (dados.perfil || 'operador').toUpperCase() },
            { label: 'Status', valor: '🟢 Ativo e Liberado' }
          ],
          rodape: '👉 Você já pode abrir o aplicativo e fazer login com suas credenciais cadastradas.'
        });

        enviarEmail({
          to: emailFuncionario,
          subject: '🎉 [SIGE] Seu cadastro foi aprovado com sucesso!',
          html: htmlAprovado,
          text: `Olá ${nome}! Sua solicitação de acesso ao SIGE foi aprovada pelo gestor. Seu login: ${emailFuncionario}.`
        }).catch(() => {});
      }

      // O documento é mantido com status 'aprovado' para que o Flutter reaja em tempo real.
      // Após 60 s, exclui para manter a coleção limpa.
      setTimeout(async () => {
        try { await docRef.delete(); } catch (_) {}
        console.log(`[decidir.js] Solicitação ${id} aprovada e removida após delay.`);
      }, 60_000);

    } else {
      // Se rejeitado, notifica o funcionário
      if (dados.telefone) {
        const msgRejeitado = `❌ *SOLICITAÇÃO DE ACESSO - SIGE*\n\n` +
                             `Olá, *${nome}*.\n` +
                             `Informamos que sua solicitação de acesso ao sistema SIGE foi analisada e *rejeitada* pela gestão.\n` +
                             `Em caso de dúvidas, procure o seu supervisor imediato.`;
        const waState = getWhatsAppState();
        if (waState.status === 'connected') {
          enviarMensagemWhatsApp(dados.telefone, msgRejeitado).catch(() => {});
        }
      }

      if (dados.email) {
        const htmlRejeitado = gerarTemplateNotificacao({
          titulo: 'Solicitação de Acesso Não Aprovada',
          subtitulo: 'SIGE - Indústria & Manutenção',
          corHeader: '#dc2626',
          itens: [
            { label: 'Colaborador', valor: nome },
            { label: 'E-mail', valor: dados.email },
            { label: 'Status', valor: '❌ Rejeitado' }
          ],
          rodape: 'Informamos que seu pedido de cadastro foi analisado e não foi aprovado pela gestão.'
        });

        enviarEmail({
          to: dados.email,
          subject: '❌ [SIGE] Solicitação de Acesso',
          html: htmlRejeitado,
          text: `Olá ${nome}. Sua solicitação de acesso ao SIGE foi rejeitada pela gestão.`
        }).catch(() => {});
      }

      // Exclui o documento para manter a coleção limpa após rejeição
      await docRef.delete();
      console.log(`[decidir.js] Solicitação ${id} rejeitada e removida da coleção.`);
    }

    // Se a requisição veio em formato JSON
    if (req.headers.accept?.includes('application/json')) {
      return res.status(200).json({ sucesso: true, status: novoStatus, id, nome });
    }

    // Resposta visual para o gestor que clicou no link do E-mail ou WhatsApp
    const corResultado = novoStatus === 'aprovado' ? '#16a34a' : '#dc2626';
    const tituloResultado = novoStatus === 'aprovado' ? '✅ Cadastro Aprovado com Sucesso!' : '❌ Cadastro Rejeitado';
    const msgResultado = novoStatus === 'aprovado'
      ? `O acesso de <b>${nome}</b> foi liberado! O sistema atualizou a tela do colaborador instantaneamente e enviou a confirmação por e-mail e WhatsApp.`
      : `A solicitação de <b>${nome}</b> foi recusada. O aviso foi registrado no sistema.`;

    return res.status(200).send(`
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>SIGE - Decisão Registrada</title>
      </head>
      <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0f172a; color: #f8fafc; min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 20px; margin: 0;">
        <div style="background-color: #1e293b; border: 1px solid #334155; border-radius: 16px; padding: 36px; max-width: 480px; width: 100%; text-align: center; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);">
          <div style="font-size: 48px; margin-bottom: 16px;">${novoStatus === 'aprovado' ? '🎉' : '🚫'}</div>
          <h1 style="color: ${corResultado}; font-size: 22px; margin-bottom: 12px;">${tituloResultado}</h1>
          <p style="color: #cbd5e1; font-size: 15px; line-height: 1.6; margin-bottom: 24px;">${msgResultado}</p>
          <div style="background-color: #0f172a; padding: 12px; border-radius: 8px; font-size: 13px; color: #94a3b8; border: 1px solid #334155;">
            Protocolo: <code>${id}</code>
          </div>
        </div>
      </body>
      </html>
    `);
  } catch (err) {
    console.error('[decidir.js] Erro ao processar decisão:', err);
    return res.status(500).json({ sucesso: false, erro: err?.message || String(err) });
  }
}
