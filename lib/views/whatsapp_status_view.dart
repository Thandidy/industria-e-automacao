// lib/views/whatsapp_status_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WhatsAppStatusView extends StatelessWidget {
  const WhatsAppStatusView({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(24),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('config')
              .doc('whatsapp')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data =
                snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final status = data['status'] as String? ?? 'desconhecido';
            final conectado = status == 'conectado';
            final aguardando = status == 'aguardando_qr';

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Cabeçalho ─────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: conectado
                            ? Colors.green.withAlpha(25)
                            : Colors.orange.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        conectado ? Icons.check_circle : Icons.sync,
                        color: conectado ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Status da Integração WhatsApp',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // ── Conectado ─────────────────────────────────────────────
                if (conectado) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(25),
                      border: Border.all(color: Colors.green.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified, color: Colors.green, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'WhatsApp conectado e operando!\n'
                            'Notificações de máquinas e aprovações ativas.',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Todas as notificações de parada de máquina, falta de '
                    'material e solicitações de novos logins estão sendo '
                    'direcionadas ao WhatsApp do Gestor.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),

                // ── Aguardando QR / reconectando ─────────────────────────
                ] else ...[
                  const Icon(Icons.sync, size: 48, color: Colors.orange),
                  const SizedBox(height: 12),
                  Text(
                    aguardando
                        ? 'Aguardando conexão do WhatsApp'
                        : 'Servidor local offline ou iniciando…',
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    aguardando
                        ? 'Escaneie o QR Code diretamente no terminal onde o '
                          'servidor está rodando (WhatsApp → Aparelhos '
                          'Conectados → Conectar um aparelho).'
                        : 'Inicie o servidor Node.js local e aguarde a '
                          'atualização automática do status.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
