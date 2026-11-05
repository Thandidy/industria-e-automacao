// lib/providers/auth_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/usuario.dart';
import '../utils/constants.dart';

class AuthProvider extends ChangeNotifier {
  PerfilUsuario? _perfil;
  String? _userId;
  String? _nome;
  String? _email;
  bool _autenticado = false;

  PerfilUsuario? get perfil => _perfil;
  String? get userId => _userId;
  String? get nome => _nome;
  String? get email => _email;
  bool get autenticado => _autenticado;

  Usuario? get usuario => _autenticado && _perfil != null
      ? Usuario(
          id: _userId ?? '',
          nome: _nome ?? 'Usuário',
          email: _email ?? '${_userId ?? "usuario"}@empresa.com',
          senha: '',
          perfil: _perfil!,
        )
      : null;

  Future<void> login(String userId, String password, [PerfilUsuario? perfilSelecionado]) async {
    final termo = userId.trim();

    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Busca na coleção 'usuarios' (usuários aprovados via WhatsApp / index.js)
      // Formato dos campos no documento da imagem do Firestore:
      // - criadoEm: Timestamp
      // - email: String (ex: "teste@gmail.com")
      // - nome: String (ex: "teste")
      // - perfil: String (ex: "operador")
      // - senha: String (ex: "12345678")
      // - status: String ("aprovado")
      // - ultimoLogin: Timestamp
      DocumentSnapshot? usuarioDoc;

      // 1.1 Busca por e-mail exato
      QuerySnapshot userQuery = await firestore
          .collection('usuarios')
          .where('email', isEqualTo: termo)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        usuarioDoc = userQuery.docs.first;
      }

      // 1.2 Se não encontrou, tenta buscar por e-mail em minúsculas
      if (usuarioDoc == null) {
        final emailLower = termo.toLowerCase();
        if (emailLower != termo) {
          final queryLower = await firestore
              .collection('usuarios')
              .where('email', isEqualTo: emailLower)
              .limit(1)
              .get();
          if (queryLower.docs.isNotEmpty) {
            usuarioDoc = queryLower.docs.first;
          }
        }
      }

      // 1.3 Se não encontrou, busca por nome exato
      if (usuarioDoc == null) {
        final nameQuery = await firestore
            .collection('usuarios')
            .where('nome', isEqualTo: termo)
            .limit(1)
            .get();
        if (nameQuery.docs.isNotEmpty) {
          usuarioDoc = nameQuery.docs.first;
        }
      }

      // 1.4 Se não encontrou, busca por nome em minúsculas
      if (usuarioDoc == null) {
        final nameLower = termo.toLowerCase();
        if (nameLower != termo) {
          final nameLowerQuery = await firestore
              .collection('usuarios')
              .where('nome', isEqualTo: nameLower)
              .limit(1)
              .get();
          if (nameLowerQuery.docs.isNotEmpty) {
            usuarioDoc = nameLowerQuery.docs.first;
          }
        }
      }

      // 1.5 Se não encontrou, busca por ID direto do documento
      if (usuarioDoc == null) {
        final docById = await firestore.collection('usuarios').doc(termo).get();
        if (docById.exists) {
          usuarioDoc = docById;
        }
      }

      // 1.6 Fallback resiliente: varredura case-insensitive na coleção 'usuarios'
      if (usuarioDoc == null) {
        final todosUsuarios = await firestore.collection('usuarios').get();
        for (final doc in todosUsuarios.docs) {
          final data = doc.data();
          final emailDoc = (data['email'] ?? '').toString().trim().toLowerCase();
          final nomeDoc = (data['nome'] ?? data['nomeFuncionario'] ?? '').toString().trim().toLowerCase();
          final idDoc = doc.id.toLowerCase();
          final termoLower = termo.toLowerCase();

          if (emailDoc == termoLower || nomeDoc == termoLower || idDoc == termoLower) {
            usuarioDoc = doc;
            break;
          }
        }
      }

      // Caso usuário tenha sido encontrado na coleção 'usuarios'
      if (usuarioDoc != null && usuarioDoc.exists) {
        final userData = usuarioDoc.data() as Map<String, dynamic>;

        // Validação de status (deve estar 'aprovado')
        final status = (userData['status'] ?? 'aprovado').toString().toLowerCase().trim();
        if (status != 'aprovado') {
          if (status == 'pendente') {
            throw Exception('Seu cadastro ainda está PENDENTE de aprovação pelo WhatsApp do gestor.');
          } else if (status == 'rejeitado') {
            throw Exception('Sua solicitação de acesso foi REJEITADA pelo gestor.');
          } else {
            throw Exception('Acesso não autorizado. Status atual: $status.');
          }
        }

        // Validação de senha
        final senhaArmazenada = (userData['senha'] ?? '').toString();
        if (senhaArmazenada.isNotEmpty && senhaArmazenada != password) {
          throw Exception('Senha incorreta. Verifique os dados digitados.');
        }

        _userId = usuarioDoc.id;
        _nome = userData['nome']?.toString() ?? userData['nomeFuncionario']?.toString() ?? 'Usuário';
        _email = userData['email']?.toString() ?? termo;
        _perfil = userData['perfil'] != null
            ? _converterPerfil(userData['perfil'])
            : (perfilSelecionado ?? PerfilUsuario.operador);
        _autenticado = true;

        // Atualiza último login no Firestore como Timestamp
        try {
          await firestore.collection('usuarios').doc(_userId).update({
            'ultimoLogin': FieldValue.serverTimestamp(),
          });
        } catch (_) {}

        notifyListeners();
        return;
      }

      // 2. Se não encontrou em 'usuarios', verifica em 'solicitacoes_login' para informar status
      DocumentSnapshot? solDoc;

      // Busca solicitação por e-mail
      QuerySnapshot solQuery = await firestore
          .collection('solicitacoes_login')
          .where('email', isEqualTo: termo)
          .limit(1)
          .get();

      if (solQuery.docs.isNotEmpty) {
        solDoc = solQuery.docs.first;
      }

      // Tenta por e-mail em minúsculas
      if (solDoc == null) {
        final emailLower = termo.toLowerCase();
        if (emailLower != termo) {
          final queryLower = await firestore
              .collection('solicitacoes_login')
              .where('email', isEqualTo: emailLower)
              .limit(1)
              .get();
          if (queryLower.docs.isNotEmpty) {
            solDoc = queryLower.docs.first;
          }
        }
      }

      // Tenta por nome na solicitação
      if (solDoc == null) {
        final queryNome = await firestore
            .collection('solicitacoes_login')
            .where('nome', isEqualTo: termo)
            .limit(1)
            .get();
        if (queryNome.docs.isNotEmpty) {
          solDoc = queryNome.docs.first;
        }
      }

      // Tenta por ID na solicitação
      if (solDoc == null) {
        final docById = await firestore.collection('solicitacoes_login').doc(termo).get();
        if (docById.exists) {
          solDoc = docById;
        }
      }

      // Fallback em solicitacoes_login case-insensitive
      if (solDoc == null) {
        final todasSols = await firestore.collection('solicitacoes_login').get();
        for (final doc in todasSols.docs) {
          final data = doc.data();
          final emailSol = (data['email'] ?? '').toString().trim().toLowerCase();
          final nomeSol = (data['nome'] ?? data['nomeFuncionario'] ?? '').toString().trim().toLowerCase();
          final idSol = doc.id.toLowerCase();
          final termoLower = termo.toLowerCase();

          if (emailSol == termoLower || nomeSol == termoLower || idSol == termoLower) {
            solDoc = doc;
            break;
          }
        }
      }

      if (solDoc != null && solDoc.exists) {
        final solData = solDoc.data() as Map<String, dynamic>;
        final status = (solData['status'] ?? 'pendente').toString().toLowerCase().trim();

        if (status == 'pendente') {
          throw Exception('Seu cadastro ainda está PENDENTE de aprovação pelo WhatsApp do gestor.');
        } else if (status == 'rejeitado') {
          throw Exception('Sua solicitação de acesso foi REJEITADA pelo gestor.');
        } else if (status == 'aprovado') {
          throw Exception('Seu cadastro já foi aprovado. Tente novamente em instantes.');
        }
      }

      throw Exception('Usuário não encontrado. Clique em "Solicitar cadastro" para criar um acesso.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Erro de conexão ao autenticar: $e');
    }
  }

  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _userId = null;
    _perfil = null;
    _nome = null;
    _email = null;
    _autenticado = false;
    notifyListeners();
  }

  PerfilUsuario _converterPerfil(dynamic perfilRaw) {
    if (perfilRaw == null) return PerfilUsuario.operador;
    if (perfilRaw is int) {
      if (perfilRaw >= 0 && perfilRaw < PerfilUsuario.values.length) {
        return PerfilUsuario.values[perfilRaw];
      }
    }
    final str = perfilRaw.toString().toLowerCase().trim();
    if (str == '0') return PerfilUsuario.operador;
    if (str == '1') return PerfilUsuario.tecnico;
    if (str == '2') return PerfilUsuario.supervisor;
    if (str == '3') return PerfilUsuario.gestor;
    if (str.contains('gestor') || str.contains('admin')) return PerfilUsuario.gestor;
    if (str.contains('supervis')) return PerfilUsuario.supervisor;
    if (str.contains('tecnic') || str.contains('técnic')) return PerfilUsuario.tecnico;
    return PerfilUsuario.operador;
  }

  bool temAcesso(PerfilUsuario perfilNecessario) {
    if (!_autenticado) return false;
    // Gestor tem acesso a tudo
    if (_perfil == PerfilUsuario.gestor) return true;
    return _perfil == perfilNecessario;
  }
}
