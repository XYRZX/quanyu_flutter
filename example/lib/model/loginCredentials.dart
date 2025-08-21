import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// 常量定义
class _StartPageConstants {
  // SharedPreferences 键名常量
  static const Map<String, String> prefKeys = {
    'url': 'login_url',
    'appKey': 'login_appKey',
    'secretKey': 'login_secretKey',
    'gid': 'login_group',
    'code': 'login_user',
    'extPhone': 'login_pwd',
  };
}

/// 登录凭据数据模型
class LoginCredentials {
  final String loginUrl;
  final String appKey;
  final String secretKey;
  final String gid;
  final String code;
  final String extPhone;

  const LoginCredentials({
    required this.loginUrl,
    required this.appKey,
    required this.secretKey,
    required this.gid,
    required this.code,
    required this.extPhone,
  });

  /// 检查所有字段是否都不为空
  bool get isValid =>
      loginUrl.isNotEmpty &&
      appKey.isNotEmpty &&
      secretKey.isNotEmpty &&
      gid.isNotEmpty &&
      code.isNotEmpty &&
      extPhone.isNotEmpty;

  /// 从 SharedPreferences 创建实例
  static Future<LoginCredentials?> fromPreferences(
      SharedPreferences prefs) async {
    try {
      final credentials = LoginCredentials(
        loginUrl: prefs.getString(_StartPageConstants.prefKeys['url']!) ?? '',
        appKey: prefs.getString(_StartPageConstants.prefKeys['appKey']!) ?? '',
        secretKey:
            prefs.getString(_StartPageConstants.prefKeys['secretKey']!) ?? '',
        gid: prefs.getString(_StartPageConstants.prefKeys['gid']!) ?? '',
        code: prefs.getString(_StartPageConstants.prefKeys['code']!) ?? '',
        extPhone:
            prefs.getString(_StartPageConstants.prefKeys['extPhone']!) ?? '',
      );

      return credentials.isValid ? credentials : null;
    } catch (e) {
      debugPrint('Error loading credentials from preferences: $e');
      return null;
    }
  }
}
