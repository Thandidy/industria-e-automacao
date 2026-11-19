// lib/services/api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Se estiver na Web, usa caminhos relativos ao próprio domínio hospedado no Vercel
  // Se estiver em desenvolvimento local ou mobile, pode apontar para localhost:3000 ou sua URL Vercel
  static String get baseUrl {
    if (kIsWeb) {
      return ''; // Relativo: funciona em localhost e na URL de produção do Vercel
    }
    return 'http://localhost:3000';
  }

  /// Retorna a URL completa para visualização do QR Code do WhatsApp
  static String get qrCodeUrl => '$baseUrl/api/qr';

  /// Obtém o status dos serviços (WhatsApp, Firebase, Email) via API REST
  static Future<Map<String, dynamic>> obterStatus() async {
    try {
      final url = Uri.parse('$baseUrl/api/status');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'erro': 'Servidor respondeu com código ${response.statusCode}',
          'status': 'indisponivel'
        };
      }
    } catch (e) {
      return {
        'erro': e.toString(),
        'status': 'offline'
      };
    }
  }

  /// Obtém o estado atual da conexão do WhatsApp e o QR Code em Base64
  static Future<Map<String, dynamic>> obterEstadoWhatsApp() async {
    try {
      final url = Uri.parse('$baseUrl/api/qr?format=json');
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'connected': false, 'hasQR': false};
    } catch (e) {
      return {'connected': false, 'hasQR': false, 'erro': e.toString()};
    }
  }

  /// Solicita reset ou desconexão da sessão do WhatsApp
  static Future<bool> resetarSessaoWhatsApp() async {
    try {
      final url = Uri.parse('$baseUrl/api/qr?action=reset&format=json');
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Dispara envio direto de mensagem WhatsApp via endpoint HTTP
  static Future<bool> enviarMensagemWhatsApp({
    required String telefone,
    required String mensagem,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/send-message');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'telefone': telefone,
          'mensagem': mensagem,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['sucesso'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Dispara envio direto de e-mail com código OTP via endpoint HTTP
  static Future<bool> enviarEmailOtp({
    required String email,
    required String nome,
    required String codigo,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/send-email');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'nome': nome,
          'codigo': codigo,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['sucesso'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
