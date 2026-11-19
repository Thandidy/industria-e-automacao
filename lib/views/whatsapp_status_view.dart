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
          stream: FirebaseFirestore.instance.collection('config').doc('whatsapp').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final status = data['status'] as String? ?? 'desconhecido';
            final qrDataUrl = data['qrDataUrl'] as String?;
            final conectado = status == 'conectado';

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: conectado ? Colors.green.withAlpha(25) : Colors.orange.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        conectado ? Icons.check_circle : Icons.qr_code_scanner,
                        color: conectado ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Status da Integração WhatsApp',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),
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
                            'WhatsApp conectado e operando!\nNotificações de máquinas e aprovações ativas.',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Todas as notificações de parada de máquina, falta de material, e solicitações de novos logins estão sendo direcionadas ao WhatsApp do Gestor.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ] else if (qrDataUrl != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Image.memory(
                      // Decode base64 Data URL
                      base64Decode(qrDataUrl.split(',').last),
                      width: 240,
                      height: 240,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Abra o WhatsApp → Aparelhos Conectados → Conectar um aparelho e aponte a câmera para o QR Code acima.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  const Icon(Icons.sync, size: 48, color: Colors.blue),
                  const SizedBox(height: 12),
                  Text(
                    status == 'aguardando_qr' ? 'Aguardando leitura do QR Code' : 'Conectando socket…',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Aguardando o servidor gerar o código de conexão...',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
