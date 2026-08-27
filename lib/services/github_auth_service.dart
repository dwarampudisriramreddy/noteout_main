import 'dart:convert';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:http/http.dart' as http;
import 'settings_service.dart';

enum TokenStatus { valid, expired, invalid, empty }

class GitHubAuthService {
  static const _apiBase = 'https://api.github.com';
  static final ValueNotifier<bool> isLoggedInNotifier =
      ValueNotifier<bool>(false);
  static final ValueNotifier<TokenStatus> tokenStatusNotifier =
      ValueNotifier<TokenStatus>(TokenStatus.empty);

  static bool get isLoggedIn => SettingsService.githubToken.isNotEmpty;
  static String get username => SettingsService.githubUsername;
  static String get token => SettingsService.githubToken;
  static TokenStatus get tokenStatus => tokenStatusNotifier.value;

  static Future<void> init() async {
    if (isLoggedIn) {
      final status = await validateToken();
      if (status == TokenStatus.valid) {
        isLoggedInNotifier.value = true;
        tokenStatusNotifier.value = TokenStatus.valid;
      } else {
        SettingsService.githubToken = '';
        SettingsService.githubUsername = '';
        isLoggedInNotifier.value = false;
        tokenStatusNotifier.value = status;
      }
    }
  }

  static Future<TokenStatus> validateToken() async {
    if (token.isEmpty) return TokenStatus.empty;
    try {
      final response = await http.get(
        Uri.parse('$_apiBase/user'),
        headers: {
          'Authorization': 'Bearer ${token.trim()}',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final login = data['login'] as String? ?? '';
        if (login.isNotEmpty) {
          SettingsService.githubUsername = login;
          return TokenStatus.valid;
        }
      }
      if (response.statusCode == 401) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final msg = body['message'] as String? ?? '';
        if (msg.toLowerCase().contains('expired')) {
          return TokenStatus.expired;
        }
      }
      return TokenStatus.invalid;
    } catch (_) {
      return TokenStatus.invalid;
    }
  }

  static Future<bool> signIn(String pat) async {
    SettingsService.githubToken = pat.trim();
    final status = await validateToken();
    if (status == TokenStatus.valid) {
      isLoggedInNotifier.value = true;
      tokenStatusNotifier.value = TokenStatus.valid;
      return true;
    }
    SettingsService.githubToken = '';
    SettingsService.githubUsername = '';
    isLoggedInNotifier.value = false;
    tokenStatusNotifier.value = status;
    return false;
  }

  static void logout() {
    SettingsService.githubToken = '';
    SettingsService.githubUsername = '';
    isLoggedInNotifier.value = false;
    tokenStatusNotifier.value = TokenStatus.empty;
  }
}
