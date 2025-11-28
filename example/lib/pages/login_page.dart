import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quanyu_sdk/quanyu_sdk.dart';
import 'package:quanyu_sdk_example/model/login_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../managers/quanyu_event_manager.dart';

import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 控制器映射
  late final Map<String, TextEditingController> _controllers;

  // 状态变量
  LoginState _loginState = LoginState.idle;
  String? _errorMessage;
  bool _isLogEnabled = false; // 日志开关状态
  bool _isBusyEnabled = false;
  bool _isForceEnabled = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadSavedData();
    _loadLogSettings();
    _loadBusySettings();
    _setupEventListeners();
  }

  /// 初始化控制器
  void _initializeControllers() {
    _controllers = {
      'url': TextEditingController(),
      'appKey': TextEditingController(),
      'secretKey': TextEditingController(),
      'gid': TextEditingController(),
      'code': TextEditingController(),
      'extPhone': TextEditingController(),
    };
  }

  /// 设置事件监听器
  void _setupEventListeners() {
    final eventManager = QuanyuEventManager.instance;

    // 启动事件监听
    eventManager.startListening();

    // 注册事件处理器
    eventManager.registerEventHandler(
        'code_kicked', (eventMap) => _handleAccountKickedEvent(eventMap));
    eventManager.registerEventHandler(
        'login_success', (eventMap) => _handleLoginSuccessEvent(eventMap));
  }

  /// 处理账号被挤事件
  void _handleAccountKickedEvent(Map<String, dynamic> eventMap) {
    if (!mounted) return;

    Map<String, dynamic>? data;
    try {
      if (eventMap['data'] != null) {
        data = Map<String, dynamic>.from(eventMap['data'] as Map);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('code_kicked事件数据类型转换失败: $e');
      }
    }

    final dynamic typeDyn = data?['type'];
    final int type = typeDyn is int
        ? typeDyn
        : typeDyn is num
            ? typeDyn.toInt()
            : 0;
    final String deviceName = (data?['deviceName'] ?? '') as String;

    if (type == 1) {
      _clearLoginStatus();
      _updateLoginState(LoginState.idle);
      _showSeatConflictDialog(deviceName);
      return;
    }

    if (type == 2) {
      _clearLoginStatus();
      _updateLoginState(LoginState.idle);
      _showForcedLoginDialog(deviceName);
      return;
    }

    if (type == 3) {
      _clearLoginStatus();
      _updateLoginState(LoginState.idle);
      _showSeatLimitDialog();
      return;
    }

    final String message = (data?['message'] ?? '账号在其他设备登录') as String;
    _handleAccountKicked(message.isNotEmpty ? message : '账号在其他设备登录');
  }

  /// 处理登录成功事件
  void _handleLoginSuccessEvent(Map<String, dynamic> eventMap) {
    if (!mounted) return;

    final message = eventMap['data']?['message'] ?? '';
    if (kDebugMode) {
      debugPrint('收到登录成功事件: $message');
    }
  }

  /// 处理账号被挤事件
  void _handleAccountKicked(String message) {
    _updateLoginState(LoginState.error, message);
    _clearLoginStatus();
    if (kDebugMode) {
      debugPrint('账号被挤: $message');
    }
  }

  /// 更新登录状态
  void _updateLoginState(LoginState state, [String? errorMessage]) {
    if (mounted) {
      setState(() {
        _loginState = state;
        _errorMessage = errorMessage;
      });
    }
  }

  /// 清除登录状态
  Future<void> _clearLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(LoginConstants.prefKeys['loginStatus']!, false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('清除登录状态失败: $e');
      }
    }
  }

  /// 加载保存的登录数据
  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _controllers.forEach((key, controller) {
        controller.text = prefs.getString(LoginConstants.prefKeys[key]!) ??
            LoginConstants.defaultValues[key]!;
      });
    } catch (e) {
      _setDefaultValues();
      if (kDebugMode) {
        debugPrint('加载登录数据失败: $e');
      }
    }
  }

  /// 设置默认值
  void _setDefaultValues() {
    _controllers.forEach((key, controller) {
      controller.text = LoginConstants.defaultValues[key]!;
    });
  }

  /// 加载日志设置
  Future<void> _loadLogSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLogState = prefs.getBool('log_enabled') ?? false;

      // 从SDK获取当前日志状态
      final currentLogState = await QuanyuSdk().getLogEnabled();

      // 只有当状态真正改变时才调用setState
      if (_isLogEnabled != currentLogState) {
        setState(() {
          _isLogEnabled = currentLogState;
        });
      }

      // 如果本地保存的状态与SDK状态不一致，以SDK为准并更新本地
      if (savedLogState != currentLogState) {
        await prefs.setBool('log_enabled', currentLogState);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('加载日志设置失败: $e');
      }
    }
  }

  Future<void> _loadBusySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBusyState = prefs.getBool('login_busy') ?? false;
      if (_isBusyEnabled != savedBusyState) {
        setState(() {
          _isBusyEnabled = savedBusyState;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('加载置忙设置失败: $e');
      }
    }
  }

  /// 切换日志开关
  Future<void> _toggleLogEnabled(bool enabled) async {
    try {
      await QuanyuSdk().setLogEnabled(enabled: enabled);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('log_enabled', enabled);

      setState(() {
        _isLogEnabled = enabled;
      });

      _showMessage(
        enabled ? '日志已开启' : '日志已关闭',
        enabled ? Colors.green : Colors.orange,
      );
    } catch (e) {
      _showMessage('设置日志失败: $e', Colors.red);
      if (kDebugMode) {
        debugPrint('设置日志失败: $e');
      }
    }
  }

  Future<void> _toggleBusyEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('login_busy', enabled);
      setState(() {
        _isBusyEnabled = enabled;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('设置置忙失败: $e');
      }
    }
  }

  /// 执行登录操作
  Future<void> _login({bool? force}) async {
    final credentials = LoginCredentials.fromControllers(
      urlController: _controllers['url']!,
      appKeyController: _controllers['appKey']!,
      secretKeyController: _controllers['secretKey']!,
      gidController: _controllers['gid']!,
      codeController: _controllers['code']!,
      extPhoneController: _controllers['extPhone']!,
    );

    if (!credentials.isValid) {
      _updateLoginState(LoginState.error, '请填写所有字段');
      return;
    }

    _updateLoginState(LoginState.loading);

    try {
      final result = await _performLogin(
        credentials,
        force: force ?? (_isForceEnabled ? true : null),
      );

      if (result['success'] == true) {
        await _saveLoginData(credentials);
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('login_busy', _isBusyEnabled);
          // 同步重置本地坐席缓存，避免主页根据旧缓存自动置忙
          await prefs.setInt('agent_state', _isBusyEnabled ? 2 : 1);
        } catch (_) {}
        _updateLoginState(LoginState.success);
        _showSuccessMessage(result['message'] ?? '登录成功');
        _navigateToHomePage();
      } else {
        _updateLoginState(LoginState.error, result['message'] ?? '登录失败');
      }
    } catch (e) {
      _updateLoginState(LoginState.error, '登录失败: $e');
    }
  }

  /// 执行SDK登录
  Future<Map<String, dynamic>> _performLogin(LoginCredentials credentials,
      {bool? force}) async {
    return await QuanyuSdk().login(
      loginUrl: credentials.loginUrl,
      appKey: credentials.appKey,
      secretKey: credentials.secretKey,
      gid: credentials.gid,
      code: credentials.code,
      extPhone: credentials.extPhone,
      busy: _isBusyEnabled,
      force: force,
    );
  }

  /// 显示成功消息
  void _showSuccessMessage(String message) {
    _showMessage(message, Colors.green);
  }

  /// 显示消息
  void _showMessage(String message, Color backgroundColor) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _showSeatConflictDialog(String deviceName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示'),
          content: Text(
              '当前账号正在哪一台设备上面登录：${deviceName.isNotEmpty ? deviceName : '其他设备'}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  void _showSeatLimitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示'),
          content: const Text('授权坐席超限'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  void _showForcedLoginDialog(String deviceName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('强制登录'),
          content:
              Text('当前设备被${deviceName.isNotEmpty ? deviceName : '其他设备'}登录了'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  /// 导航到主页
  void _navigateToHomePage() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  /// 保存登录数据到本地存储
  Future<void> _saveLoginData(LoginCredentials credentials) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 保存登录状态
      await prefs.setBool(LoginConstants.prefKeys['loginStatus']!, true);

      // 保存登录数据
      final credentialsMap = credentials.toMap();
      for (final entry in credentialsMap.entries) {
        final prefKey = LoginConstants.prefKeys[entry.key];
        if (prefKey != null) {
          await prefs.setString(prefKey, entry.value);
        }
      }

      // 保存置忙状态
      await prefs.setBool('login_busy', _isBusyEnabled);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('保存登录数据失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () {
          // 点击空白区域取消焦点
          FocusScope.of(context).unfocus();
        },
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 60),
                const _LoginHeader(),
                const SizedBox(height: 40),
                _buildInputFields(),
                const SizedBox(height: 20),
                _buildLogSwitch(),
                const SizedBox(height: 20),
                _buildBusySwitch(),
                const SizedBox(height: 20),
                _buildForceSwitch(),
                const SizedBox(height: 20),
                _buildLoginButton(),
                if (_loginState == LoginState.error) ...[
                  const SizedBox(height: 16),
                  _buildErrorMessage(),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建输入字段区域
  Widget _buildInputFields() {
    return Column(
      children: LoginConstants.inputFields.map((config) {
        return _LoginInputField(
          controller: _controllers[config.key]!,
          config: config,
        );
      }).toList(),
    );
  }

  /// 构建日志开关
  Widget _buildLogSwitch() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.bug_report,
            color: Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '调试日志',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: _isLogEnabled,
            onChanged:
                _loginState == LoginState.loading ? null : _toggleLogEnabled,
            activeColor: Colors.blue,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildBusySwitch() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            color: Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '登录后置忙',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: _isBusyEnabled,
            onChanged:
                _loginState == LoginState.loading ? null : _toggleBusyEnabled,
            activeColor: Colors.blue,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildForceSwitch() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.security,
            color: Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '强制登录',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: _isForceEnabled,
            onChanged: _loginState == LoginState.loading
                ? null
                : (enabled) {
                    setState(() {
                      _isForceEnabled = enabled;
                    });
                  },
            activeColor: Colors.blue,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  /// 构建登录按钮
  Widget _buildLoginButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      width: double.infinity,
      height: LoginConstants.buttonHeight,
      child: ElevatedButton(
        onPressed: _loginState == LoginState.loading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: _loginState == LoginState.loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                '立即登录',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  /// 构建错误消息
  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red[600],
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? '未知错误',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // 注销事件处理器
    final eventManager = QuanyuEventManager.instance;
    eventManager.unregisterEventHandler(
        'code_kicked', (eventMap) => _handleAccountKickedEvent(eventMap));
    eventManager.unregisterEventHandler(
        'login_success', (eventMap) => _handleLoginSuccessEvent(eventMap));

    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

/// 登录页面头部组件
class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: LoginConstants.iconSize,
          height: LoginConstants.iconSize,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(LoginConstants.iconRadius),
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
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          LoginConstants.appTitle,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// 登录输入字段组件
class _LoginInputField extends StatelessWidget {
  final TextEditingController controller;
  final InputFieldConfig config;

  const _LoginInputField({
    required this.controller,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 7.5),
      height: LoginConstants.inputHeight,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Icon(
              config.icon,
              color: Colors.grey[600],
              size: 20,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: config.keyboardType,
              decoration: InputDecoration(
                hintText: config.hint,
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}
