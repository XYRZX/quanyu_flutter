import 'package:flutter/material.dart';

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

  /// 转换为Map用于SDK调用
  Map<String, String> toMap() => {
        'url': loginUrl,
        'appKey': appKey,
        'secretKey': secretKey,
        'gid': gid,
        'code': code,
        'extPhone': extPhone,
      };

  /// 从控制器创建实例
  factory LoginCredentials.fromControllers({
    required TextEditingController urlController,
    required TextEditingController appKeyController,
    required TextEditingController secretKeyController,
    required TextEditingController gidController,
    required TextEditingController codeController,
    required TextEditingController extPhoneController,
  }) {
    return LoginCredentials(
      loginUrl: urlController.text.trim(),
      appKey: appKeyController.text.trim(),
      secretKey: secretKeyController.text.trim(),
      gid: gidController.text.trim(),
      code: codeController.text.trim(),
      extPhone: extPhoneController.text.trim(),
    );
  }
}

/// 登录常量配置
class LoginConstants {
  // UI常量
  static const String appTitle = 'Demo';
  static const double iconSize = 80.0;
  static const double iconRadius = 15.0;
  static const double inputHeight = 45.0;
  static const double buttonHeight = 45.0;

  // 默认值常量
  // static const Map<String, String> defaultValues = {
  //   'url': 'https://ccc.qylink.com',
  //   'appKey': '5a4e4313-0638-ba89-d4d2-0ba15753d22e',
  //   'secretKey': 'c0b0ffe2-88e3-dda1-10c8-c6fc74b2e222',
  //   'gid': '61',
  //   'code': '1001',
  //   'extPhone': '11141002',
  // };
  static const Map<String, String> defaultValues = {
    'url': 'http://8.130.24.107:8000',
    'appKey': 'b4f3b8cb-b015-6051-c3da-e3d0b9d8432e',
    'secretKey': '5d5d37ac-d727-6f72-2fc4-86f63487f294',
    'gid': '61',
    'code': '3002',
    'extPhone': '10001023',
  };

  // SharedPreferences 键名常量
  static const Map<String, String> prefKeys = {
    'loginStatus': 'websocket_login',
    'url': 'login_url',
    'appKey': 'login_appKey',
    'secretKey': 'login_secretKey',
    'gid': 'login_group',
    'code': 'login_user',
    'extPhone': 'login_pwd',
  };

  // 输入字段配置
  static const List<InputFieldConfig> inputFields = [
    InputFieldConfig(
      key: 'url',
      hint: '请输入URL',
      icon: Icons.link,
    ),
    InputFieldConfig(
      key: 'appKey',
      hint: '请输入AppKey',
      icon: Icons.key,
    ),
    InputFieldConfig(
      key: 'secretKey',
      hint: '请输入SecretKey',
      icon: Icons.security,
    ),
    InputFieldConfig(
      key: 'gid',
      hint: '请输入技能',
      icon: Icons.person,
      keyboardType: TextInputType.number,
    ),
    InputFieldConfig(
      key: 'code',
      hint: '请输入工号',
      icon: Icons.badge,
    ),
    InputFieldConfig(
      key: 'extPhone',
      hint: '请输入分机号',
      icon: Icons.phone_in_talk,
    ),
  ];
}

/// 输入字段配置
class InputFieldConfig {
  final String key;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;

  const InputFieldConfig({
    required this.key,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });
}

/// 登录状态枚举
enum LoginState {
  idle,
  loading,
  success,
  error,
}
