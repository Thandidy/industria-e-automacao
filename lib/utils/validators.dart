// lib/utils/validators.dart



class Validators {
  static String? nome(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nome é obrigatório';
    }
    if (value.trim().length < 3) {
      return 'Nome deve ter pelo menos 3 caracteres';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'E-mail é obrigatório';
    }
    final emailRegex = RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'E-mail inválido';
    }
    return null;
  }

  static String? senha(String? value) {
    if (value == null || value.isEmpty) {
      return 'Senha é obrigatória';
    }
    if (value.length < 6) {
      return 'Senha deve ter pelo menos 6 caracteres';
    }
    return null;
  }

  static String? campoObrigatorio(String? value, String nomeCampo) {
    if (value == null || value.trim().isEmpty) {
      return '$nomeCampo é obrigatório';
    }
    return null;
  }

  static String? descricao(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Descrição é obrigatória';
    }
    if (value.trim().length < 5) {
      return 'Descrição deve ter pelo menos 5 caracteres';
    }
    return null;
  }

  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}

extension StringValidator on String {
  bool get isValidEmail => Validators.isValidEmail(this);
  bool get isNotEmpty => trim().isNotEmpty;
}