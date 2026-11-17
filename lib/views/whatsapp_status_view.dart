// lib/views/whatsapp_status_view.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class WhatsAppStatusView extends StatefulWidget {
  const WhatsAppStatusView({super.key});

  @override
  State<WhatsAppStatusView> createState() => _WhatsAppStatusViewState();
}

class _WhatsAppStatusViewState extends State<WhatsAppStatusView> {
  bool _isLoading = true;
  bool _estaConectado = false;
  String? _qrDataUrl;
  String _statusTexto = 'Verificando status...';
  Timer? _timerAtualizacao;

  @override
  void initState() {
    super.initState();
    _carregarStatus();
    // Atualiza a cada 5 segundos enquanto a tela estiver aberta
    _timerAtualizacao = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _carregarStatus(silencioso: true);
    });
  }

  @override
  void dispose() {
    _timerAtualizacao?.cancel();
    super.dispose();
  }

  Future<void> _carregarStatus({bool silencioso = false}) async {
    if (!silencioso) setState(() => _isLoading = true);

    final resultado = await ApiService.obterEstadoWhatsApp();

    if (!mounted) return;

    final conectado = resultado['connected'] == true || resultado['status'] == 'connected';
    final qr = resultado['qrDataUrl'] as String?;
    final status = (resultado['status'] ?? 'desconhecido').toString();

    setState(() {
      _estaConectado = conectado;
      _qrDataUrl = qr;
      _statusTexto = conectado
          ? 'Conectado com sucesso ao WhatsApp'
          : (qr != null ? 'Aguardando leitura do QR Code' : 'Conectando socket ($status)...');
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _estaConectado ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _estaConectado ? Icons.check_circle : Icons.qr_code_scanner,
                    color: _estaConectado ? Colors.green : Colors.orange,
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
                )
              ],
            ),
            const Divider(height: 24),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(),
              )
            else if (_estaConectado) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
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
                'Todas as notificações de parada de máquina, falta de material, e solicitação de novos logins estão sendo direcionadas ao WhatsApp do Gestor.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ] else if (_qrDataUrl != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Image.memory(
                  base64Decode(_qrDataUrl!.split(',')[1]),
                  width: 240,
                  height: 240,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Abra o WhatsApp > Aparelhos Conectados > Conectar um aparelho e aponte a câmera para o QR Code acima.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const Icon(Icons.sync, size: 48, color: Colors.blue),
              const SizedBox(height: 12),
              Text(
                _statusTexto,
                style: const TextStyle(fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Aguardando o servidor gerar o código de conexão...',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _carregarStatus(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Atualizar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fechar'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
