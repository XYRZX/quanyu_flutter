import 'package:flutter/material.dart';
import 'package:quanyu_sdk_example/model/loginCredentials.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quanyu_sdk/quanyu_sdk.dart';
import 'login_page.dart';
import 'home_page.dart';

/// 常量定义
class _StartPageConstants {
  static const Duration splashDuration = Duration(seconds: 2);
  static const String loginStatusKey = 'websocket_login';
}

class StartPage extends StatefulWidget {
  const StartPage({Key? key}) : super(key: key);

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// 初始化应用，延迟后检查登录状态
  void _initializeApp() {
    Timer(_StartPageConstants.splashDuration, _checkLoginStatus);
  }

  /// 检查登录状态并导航到相应页面
  Future<void> _checkLoginStatus() async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isLogin =
          prefs.getBool(_StartPageConstants.loginStatusKey) ?? false;

      if (isLogin) {
        await _attemptAutoLogin(prefs);
      } else {
        _navigateToLoginPage();
      }
    } catch (e) {
      _handleError('检查登录状态失败', e);
    }
  }

  /// 尝试自动登录
  Future<void> _attemptAutoLogin(SharedPreferences prefs) async {
    try {
      // 并行加载凭据
      final credentials = await LoginCredentials.fromPreferences(prefs);

      if (credentials == null) {
        debugPrint('Login credentials are incomplete or invalid');
        _navigateToLoginPage();
        return;
      }

      // 尝试登录
      final result = await _performLogin(credentials);

      if (result['success'] == true) {
        _navigateToHomePage();
      } else {
        await _clearLoginStatus(prefs);
        _navigateToLoginPage();
      }
    } catch (e) {
      await _clearLoginStatus(prefs);
      _handleError('自动登录失败', e);
    }
  }

  /// 执行登录操作
  Future<Map<String, dynamic>> _performLogin(
      LoginCredentials credentials) async {
    final prefs = await SharedPreferences.getInstance();
    final busy = prefs.getBool('login_busy') ?? false;
    return await QuanyuSdk().login(
      loginUrl: credentials.loginUrl,
      appKey: credentials.appKey,
      secretKey: credentials.secretKey,
      gid: credentials.gid,
      code: credentials.code,
      extPhone: credentials.extPhone,
      busy: busy,
    );
  }

  /// 清除登录状态
  Future<void> _clearLoginStatus(SharedPreferences prefs) async {
    try {
      await prefs.setBool(_StartPageConstants.loginStatusKey, false);
    } catch (e) {
      debugPrint('Error clearing login status: $e');
    }
  }

  /// 处理错误
  void _handleError(String message, dynamic error) {
    debugPrint('$message: $error');
    if (mounted) {
      setState(() {
        _errorMessage = message;
      });

      // 3秒后自动跳转到登录页
      Timer(const Duration(seconds: 3), _navigateToLoginPage);
    }
  }

  /// 导航到登录页面
  void _navigateToLoginPage() {
    _navigateToPage(const LoginPage());
  }

  /// 导航到主页面
  void _navigateToHomePage() {
    _navigateToPage(const HomePage());
  }

  /// 导航到指定页面
  void _navigateToPage(Widget page) {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _buildContent(),
      ),
    );
  }

  /// 构建页面内容
  Widget _buildContent() {
    if (_errorMessage != null) {
      return _buildErrorContent();
    }

    return const _SplashContent();
  }

  /// 构建错误内容
  Widget _buildErrorContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _SplashContent(),
        const SizedBox(height: 40),
        Icon(
          Icons.error_outline,
          size: 48,
          color: Colors.red[400],
        ),
        const SizedBox(height: 16),
        Text(
          _errorMessage!,
          style: TextStyle(
            fontSize: 16,
            color: Colors.red[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '即将跳转到登录页面...',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

/// 启动页面内容组件
class _SplashContent extends StatelessWidget {
  const _SplashContent();

  static const double _iconSize = 120.0;
  static const double _iconRadius = 20.0;
  static const double _phoneIconSize = 60.0;
  static const double _spacing = 20.0;
  static const String _appTitle = 'Demo';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAppIcon(),
        const SizedBox(height: _spacing),
        _buildAppTitle(),
        const SizedBox(height: 40),
        _buildLoadingIndicator(),
      ],
    );
  }

  /// 构建应用图标
  Widget _buildAppIcon() {
    return Container(
      width: _iconSize,
      height: _iconSize,
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(_iconRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.phone,
        size: _phoneIconSize,
        color: Colors.white,
      ),
    );
  }

  /// 构建应用标题
  Widget _buildAppTitle() {
    return const Text(
      _appTitle,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  /// 构建加载指示器
  Widget _buildLoadingIndicator() {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
      ),
    );
  }
}
