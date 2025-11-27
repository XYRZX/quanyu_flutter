import 'package:flutter/material.dart';
import 'package:quanyu_sdk/quanyu_sdk.dart';
import 'login_page.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../managers/quanyu_event_manager.dart';

/// 主页面 - 通话功能主界面
/// 提供通话控制、状态显示、音量调节等功能
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ==================== 常量定义 ====================

  /// SharedPreferences中登录状态的键名
  static const String _loginStatusKey = 'websocket_login';

  /// 默认音量级别（0.0-1.0）
  static const double _defaultVolumeLevel = 0.5;

  /// 输入框高度
  static const double _inputHeight = 45.0;

  /// 按钮高度
  static const double _buttonHeight = 45.0;

  /// 卡片外边距
  static const double _cardMargin = 20.0;

  /// 卡片内边距
  static const double _cardPadding = 16.0;

  /// 完整的状态映射表（与iOS端保持一致）
  static const Map<int, String> _fullAgentStateMap = {
    0: '离线',
    1: '空闲',
    2: '置忙中',
    3: '抢接',
    4: '选出队列',
    5: '来电振铃',
    6: '通话中',
    7: '转接中',
    8: '等待转移确认',
    9: '保持中',
    10: '会议中',
    11: '话后处理',
    12: '输入被叫号码',
    13: '发起呼叫',
    14: '管理状态',
    15: '监听',
    16: '强插',
    17: '等待电话登录',
    18: '等待脚本Free',
    19: '通话中',
    20: '通话中',
    21: '发起会议邀请',
    22: '会议通话确认',
    23: '会议主持人',
    24: '会议确认通话中',
    25: '会议成员',
    26: '等待pc登录',
    27: '正在呼叫坐席',
    28: '会议中',
    29: '小休',
    30: '静音',
  };

  // ==================== 控制器 ====================

  /// 主叫号码输入控制器
  final TextEditingController _callerController = TextEditingController();

  /// 被叫号码输入控制器
  final TextEditingController _calleeController = TextEditingController();

  // ==================== 状态变量 ====================

  /// 扬声器是否开启
  bool _isSpeakerOn = false;

  /// 是否开启保活
  bool _isKeepAlive = false;

  /// 坐席状态显示文本
  String _dropDownText = '空闲';

  /// 当前坐席状态码
  int _agentState = 0;

  /// 当前喇叭音量级别（0.0-1.0）
  double _speakerVolumeLevel = _defaultVolumeLevel;

  /// 当前麦克风音量级别（0.0-1.0）
  double _microphoneVolumeLevel = _defaultVolumeLevel;

  /// 软电话注册状态
  String _softPhoneStatus = '离线';

  /// 软电话是否在线
  bool _isSoftPhoneOnline = false;

  /// 保存完整的消息数据，用于下拉菜单操作
  Map<String, dynamic>? _savedMessageDic;

  /// 当前可用的状态选项列表（用于下拉菜单）
  /// 格式：Map<状态名称, Map<状态码, 是否可用>>
  List<MapEntry<String, MapEntry<int, bool>>> _availableStates = [];

  /// 来电弹窗是否正在显示
  bool _isIncomingCallDialogShowing = false;

  /// 更新可用状态列表（用于下拉菜单）
  void _updateAvailableStates() {
    // 定义所有可能的状态选项
    List<MapEntry<String, int>> allStates = [
      const MapEntry('置闲', 1),
      const MapEntry('置忙', 2),
      const MapEntry('小休', 29),
      const MapEntry('重新注册分机', -1), // 使用-1表示重新注册分机
    ];

    // 获取当前状态码
    int currentCode = 0;
    if (_savedMessageDic != null) {
      if (_savedMessageDic!.containsKey('state')) {
        currentCode = _savedMessageDic!['state'] as int? ?? 0;
      } else if (_savedMessageDic!.containsKey('registerState')) {
        currentCode = _savedMessageDic!['registerState'] as int? ?? 0;
      }
    }

    // 根据当前状态码判断哪些选项可用
    _availableStates = allStates.map((entry) {
      bool isEnabled = _isStateEnabled(entry.key, currentCode);
      return MapEntry(entry.key, MapEntry(entry.value, isEnabled));
    }).toList();
  }

  /// 判断指定状态是否可用
  bool _isStateEnabled(String stateName, int currentCode) {
    // 重新注册分机总是可用，不受其他条件限制
    if (stateName == '重新注册分机') {
      return true;
    }

    // 如果_savedMessageDic为空，其他选项都不可用
    if (_savedMessageDic == null) {
      return false;
    }

    // 根据iOS逻辑判断状态是否可用
    switch (stateName) {
      case '置忙':
        // 只要收到软电话状态事件，置忙始终可点击
        return true;
      case '置闲':
        // 只要收到软电话状态事件，置闲始终可点击
        return true;
      case '小休':
        // 仅在空闲或置忙状态下允许小休
        return currentCode == 1 || currentCode == 2;
      default:
        return false;
    }
  }

  /// 显示状态选择对话框
  void _showStateSelectionDialog() {
    _updateAvailableStates();

    if (_availableStates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前没有可切换的状态')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('选择坐席状态'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _availableStates.map((state) {
              String stateName = state.key;
              int stateCode = state.value.key;
              bool isEnabled = state.value.value;

              return ListTile(
                title: Text(
                  stateName,
                  style: TextStyle(
                    color: isEnabled
                        ? const Color.fromRGBO(51, 51, 51, 1)
                        : const Color.fromRGBO(200, 200, 200, 1),
                  ),
                ),
                onTap: isEnabled
                    ? () {
                        Navigator.of(context).pop();
                        // 主动取消焦点
                        FocusScope.of(context).unfocus();
                        _changeAgentState(stateCode, stateName);
                      }
                    : null,
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  /// 切换坐席状态
  void _changeAgentState(int newState, String stateName) {
    debugPrint('切换坐席状态: $stateName (code: $newState)');

    // 根据状态名称调用相应的SDK方法
    switch (stateName) {
      case '置闲':
        _sendSetFreeOpcode();
        break;
      case '置忙':
        _sendSetBusyOpcode();
        break;
      case '小休':
        _sendSetRestOpcode();
        break;
      case '重新注册分机':
        _reregisterSoftPhone();
        break;
      default:
        debugPrint('不支持的状态切换: $stateName');
    }
  }

  /// 重新注册软电话
  Future<void> _reregisterSoftPhone() async {
    try {
      debugPrint('重新注册软电话...');
      await QuanyuSdk().reregisterSoftPhone();
      debugPrint('软电话重新注册请求已发送');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在重新注册软电话...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('重新注册软电话失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重新注册软电话失败: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// 初始化应用
  /// 按顺序执行：登录状态验证、事件监听、网络监听注册、连接状态检查、软电话注册
  void _initializeApp() async {
    // 首先验证登录状态
    final isValidLogin = await _validateLoginStatus();
    if (!isValidLogin) {
      return; // 如果登录状态无效，直接返回，不继续初始化
    }

    // 使用事件管理器
    _setupEventListeners();
    await _registerSoftPhone();
    await _applyInitialBusyFromPrefs();
  }

  Future<void> _applyInitialBusyFromPrefs() async {
    try {
      // final prefs = await SharedPreferences.getInstance();
      // final int? agentState = prefs.getInt('agent_state');
      // final bool busyFlag = prefs.getBool('login_busy') ?? false;

      // 如果已经从事件中获取到当前坐席状态，且不是空闲/置忙/小休，则不覆盖为置闲
      int currentCode = 0;
      if (_savedMessageDic != null && _savedMessageDic!.containsKey('state')) {
        final dynamic s = _savedMessageDic!['state'];
        if (s is int) currentCode = s;
        if (s is num) currentCode = s.toInt();
      } else {
        currentCode = _agentState;
      }

      if (currentCode != 0 &&
          currentCode != 1 &&
          currentCode != 2 &&
          currentCode != 29) {
        debugPrint('检测到当前坐席状态($currentCode)，跳过初始化状态应用');
        _updateAvailableStates();
        return;
      }

      // if (agentState == 29) {
      //   await _sendSetRestOpcode();
      //   if (mounted) {
      //     setState(() {
      //       _agentState = 29;
      //       _dropDownText = _fullAgentStateMap[29] ?? '小休';
      //     });
      //   }
      // } else if (agentState == 2 || (agentState == null && busyFlag)) {
      //   await _sendSetBusyOpcode();
      //   if (mounted) {
      //     setState(() {
      //       _agentState = 2;
      //       _dropDownText = _fullAgentStateMap[2] ?? '置忙中';
      //     });
      //   }
      // }
      // else {
      //   await _sendSetFreeOpcode();
      //   if (mounted) {
      //     setState(() {
      //       _agentState = 1;
      //       _dropDownText = _fullAgentStateMap[1] ?? '空闲';
      //     });
      //   }
      // }

      _updateAvailableStates();
    } catch (e) {
      debugPrint('应用初始坐席状态失败: $e');
    }
  }

  /// 设置事件监听器
  void _setupEventListeners() {
    final eventManager = QuanyuEventManager.instance;

    // 启动事件监听
    eventManager.startListening();

    // 注册事件处理器
    eventManager.registerEventHandler('soft_phone_registration_status',
        (eventMap) => _handleSoftPhoneRegistrationStatusEvent(eventMap));
    eventManager.registerEventHandler('soft_phone_status',
        (eventMap) => _handleSoftPhoneStatusEvent(eventMap));
    eventManager.registerEventHandler(
        'code_kicked', (eventMap) => _handleAccountKickedEvent(eventMap));
  }

  /// 处理软电话注册状态事件
  void _handleSoftPhoneRegistrationStatusEvent(Map<String, dynamic> eventMap) {
    if (!mounted) return;

    Map<String, dynamic>? data;
    try {
      if (eventMap['data'] != null) {
        data = Map<String, dynamic>.from(eventMap['data'] as Map);
      }
    } catch (e) {
      debugPrint('事件数据类型转换失败: $e');
      return;
    }

    debugPrint('处理软电话注册状态事件: $data');
    _handleSoftPhoneRegistrationStatus(data);
  }

  /// 处理软电话状态事件
  void _handleSoftPhoneStatusEvent(Map<String, dynamic> eventMap) {
    if (!mounted) return;

    Map<String, dynamic>? data;
    try {
      if (eventMap['data'] != null) {
        data = Map<String, dynamic>.from(eventMap['data'] as Map);
      }
    } catch (e) {
      debugPrint('soft_phone_status事件数据类型转换失败: $e');
      return;
    }

    debugPrint('处理软电话状态事件: $data');
    _handleSoftPhoneStatus(data);
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
      debugPrint('code_kicked事件数据类型转换失败: $e');
      return;
    }

    final dynamic typeDyn = data?['type'];
    final int type = typeDyn is int
        ? typeDyn
        : typeDyn is num
            ? typeDyn.toInt()
            : 0;
    final String deviceName = (data?['deviceName'] ?? '') as String;

    if (type == 1) {
      _showOtherDeviceLoggingDialog(deviceName);
      return;
    }

    if (type == 2) {
      _showForcedLoginDialog(deviceName);
      return;
    }

    if (type == 3) {
      _showSeatLimitDialog();
      return;
    }

    _handleAccountKicked(data?['message'] ?? '账号在其他设备登录');
  }

  /// 验证登录状态
  /// 检查本地存储的登录状态，如果无效则返回登录页
  Future<bool> _validateLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLogin = prefs.getBool(_loginStatusKey) ?? false;

      if (!isLogin) {
        // 登录状态无效，返回登录页
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('验证登录状态失败: $e');
      // 出错时也返回登录页
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
      return false;
    }
  }

  /// 注册软电话
  /// 向SDK注册当前设备作为软电话终端
  Future<void> _registerSoftPhone() async {
    try {
      debugPrint('开始注册软电话...');
      await QuanyuSdk().registerSoftPhone();
      debugPrint('软电话注册请求已发送');
    } catch (e) {
      debugPrint('注册软电话失败: $e');
    }
  }

  /// 处理来电事件
  /// 解析来电数据并显示来电弹窗
  void _handleIncomingCall(Map<String, dynamic> messageDic) {
    try {
      debugPrint('处理来电事件: $messageDic');

      // 解析extinfo字段
      String? extinfo = messageDic['extinfo'] as String?;
      if (extinfo != null && extinfo.isNotEmpty) {
        Map<String, dynamic> extinfoData = jsonDecode(extinfo);
        String? customer = extinfoData['customer'] as String?;
        String? hotline = extinfoData['hotline'] as String?;

        if (customer != null && customer.isNotEmpty) {
          _showIncomingCallDialog(customer, hotline);
        } else {
          debugPrint('来电信息中没有找到customer字段');
        }
      } else {
        debugPrint('来电信息中没有找到extinfo字段');
      }
    } catch (e) {
      debugPrint('处理来电事件失败: $e');
    }
  }

  /// 显示来电对话框
  /// 显示接听/拒绝选项
  void _showIncomingCallDialog(String customer, String? hotline) {
    if (!mounted) return;
    if (_isIncomingCallDialogShowing) {
      debugPrint('来电弹窗已显示，忽略重复弹出');
      return;
    }
    _isIncomingCallDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false, // 不允许点击外部关闭
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // 禁止返回键关闭
          child: AlertDialog(
            title: const Text(
              '来电',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '来电号码：$customer',
                  style: const TextStyle(fontSize: 16),
                ),
                if (hotline != null && hotline.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '热线号码：$hotline',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _isIncomingCallDialogShowing = false;
                  _rejectCall();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text(
                  '拒绝',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _isIncomingCallDialogShowing = false;
                  _answerCall();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  '接听',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      // 兜底：任何情况下关闭都重置标记
      _isIncomingCallDialogShowing = false;
    });
  }

  /// 接听来电
  /// 调用SDK接听当前来电
  Future<void> _answerCall() async {
    try {
      debugPrint('接听来电');

      // 调用SDK接听方法
      await QuanyuSdk().clientAnswer();

      // 发送接听来电的指令
      // await _sendCustomMessage('{"opcode":"C_ReplyRing","reply_type":0}');

      debugPrint('来电接听成功');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已接听来电'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('接听来电失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('接听失败: $e')),
        );
      }
    }
  }

  /// 拒绝来电
  /// 调用SDK拒绝当前来电
  Future<void> _rejectCall() async {
    try {
      debugPrint('拒绝来电');
      // 发送拒绝来电的指令
      await _sendCustomMessage('{"opcode":"C_ReplyRing","reply_type":1}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已拒绝来电'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('拒绝来电失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拒绝失败: $e')),
        );
      }
    }
  }

  // ==================== sendRequest方法指令封装 ====================

  /// 发送自定义JSON消息到原生代码
  /// 通过sendRequestWithMessage方法传递JSON字符串给原生WebSocket
  Future<void> _sendCustomMessage(String jsonMessage) async {
    try {
      await QuanyuSdk().sendRequestWithMessage(message: jsonMessage);
      debugPrint('发送自定义消息成功: $jsonMessage');
    } catch (e) {
      debugPrint('发送自定义消息失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送消息失败: $e')),
        );
      }
    }
  }

  /// 发送C_SetBusy指令
  /// 发送JSON格式: {"opcode": "C_SetBusy"}
  Future<void> _sendSetBusyOpcode() async {
    const String message = '{"opcode": "C_SetBusy"}';
    await _sendCustomMessage(message);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('login_busy', true);
      await prefs.setInt('agent_state', 2);
    } catch (_) {}
  }

  /// 发送C_SetFree指令
  /// 发送JSON格式: {"opcode": "C_SetFree"}
  Future<void> _sendSetFreeOpcode() async {
    const String message = '{"opcode": "C_SetFree"}';
    await _sendCustomMessage(message);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('login_busy', false);
      await prefs.setInt('agent_state', 1);
    } catch (_) {}
  }

  /// 发送C_SetRest指令
  /// 发送JSON格式: {"opcode": "C_SetRest"}
  Future<void> _sendSetRestOpcode() async {
    const String message = '{"opcode": "C_SetRest"}';
    await _sendCustomMessage(message);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('login_busy', false);
      await prefs.setInt('agent_state', 29);
    } catch (_) {}
  }

  /// 发送C_Silence指令
  /// 发送JSON格式: {"opcode": "C_Silence"}
  Future<void> _sendSilenceOpcode() async {
    const String message = '{"opcode": "C_Silence"}';
    await _sendCustomMessage(message);
  }

  /// 发送C_EndProcessing指令
  /// 发送JSON格式: {"opcode": "C_EndProcessing"}
  Future<void> _sendEndProcessingOpcode() async {
    const String message = '{"opcode": "C_EndProcessing"}';
    await _sendCustomMessage(message);
  }

  /// 发送C_CancelMakeCall指令
  /// 发送JSON格式: {"opcode": "C_CancelMakeCall"}
  Future<void> _sendCancelMakeCallOpcode() async {
    const String message = '{"opcode": "C_CancelMakeCall"}';
    await _sendCustomMessage(message);
  }

  /// 发送C_Hangup指令
  /// 发送JSON格式: {"opcode": "C_Hangup"}
  Future<void> _sendHangupOpcode() async {
    const String message = '{"opcode": "C_Hangup"}';
    await _sendCustomMessage(message);
  }

  /// 发送C_Keep指令
  /// 发送JSON格式: {"opcode": "C_Keep"}
  Future<void> _toggleKeep() async {
    const String message = '{"opcode": "C_Keep"}';
    await _sendCustomMessage(message);
  }

  /// 发送C_Restore指令
  /// 发送JSON格式: {"opcode": "C_Restore"}
  Future<void> _toggleRestore() async {
    const String message = '{"opcode": "C_Restore"}';
    await _sendCustomMessage(message);
  }

  /// 发送拨号指令
  /// 发送JSON格式: {"opcode": "C_MakeCall", "_Caller": "主叫号码", "_Called": "被叫号码", "BusinessCode": "", "Reserved": ""}
  Future<void> _sendMakeCallOpcode(String caller, String called) async {
    // 验证输入参数是否有值
    if (called.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请填写被叫号码')),
        );
      }
      return;
    }

    final Map<String, String> messageMap = {
      "opcode": "C_MakeCall",
      "_Caller": caller,
      "_Called": called,
      "BusinessCode": "",
      "Reserved": ""
    };
    final String message = jsonEncode(messageMap);

    await QuanyuSdk().setAutoAnswerCall();

    await _sendCustomMessage(message);
  }

  /// 切换保活状态
  /// 开启或关闭连接保活功能
  void _toggleKeepAlive() async {
    try {
      // 使用统一的保活控制方法
      await QuanyuSdk().setKeepAlive(enabled: !_isKeepAlive);

      setState(() {
        _isKeepAlive = !_isKeepAlive;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isKeepAlive ? '保活已开启' : '保活已关闭'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保活操作失败: $e')),
        );
      }
    }
  }

  /// 切换扬声器状态【完成】
  /// 开启或关闭扬声器模式
  Future<void> _toggleSpeaker() async {
    try {
      await QuanyuSdk().setSpeakerOn(enabled: !_isSpeakerOn);

      setState(() {
        _isSpeakerOn = !_isSpeakerOn;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('扬声器操作失败: $e')),
        );
      }
    }
  }

  /// 处理软电话注册状态
  void _handleSoftPhoneRegistrationStatus(Map<String, dynamic>? data) {
    if (data == null) return;

    setState(() {
      String status = data['status'] ?? 'offline';
      _isSoftPhoneOnline = status == 'online';
      _softPhoneStatus = _isSoftPhoneOnline ? '在线' : '离线';

      String message = data['message'] ?? '';
      int sipRegistrationStatus = data['sipRegistrationStatus'] ?? 0;

      debugPrint(
          '软电话状态更新: $_softPhoneStatus, SIP状态: $sipRegistrationStatus, 消息: $message');
    });
  }

  /// 处理软电话状态事件
  void _handleSoftPhoneStatus(Map<String, dynamic>? data) {
    if (data == null) {
      debugPrint('soft_phone_status 数据为空');
      return;
    }

    debugPrint('处理 soft_phone_status 事件: $data');

    try {
      // 获取原生传递的字段
      int? code = data['code'] as int?;
      int? sipRegistrationStatus = data['sipRegistrationStatus'] as int?;

      // 更安全地转换 messageDic
      Map<String, dynamic>? messageDic;
      if (data['messageDic'] != null) {
        try {
          // 使用更安全的转换方式
          final rawMessageDic = data['messageDic'];
          if (rawMessageDic is Map) {
            messageDic = <String, dynamic>{};
            rawMessageDic.forEach((key, value) {
              messageDic![key.toString()] = value;
            });
          }
        } catch (e) {
          debugPrint('messageDic 类型转换失败: $e');
          messageDic = null;
        }
      }

      // 保存完整的消息数据
      if (messageDic != null) {
        _savedMessageDic = messageDic;
      }

      // 检查是否为来电状态（状态码5表示来电振铃）
      if (code == 5 && messageDic != null) {
        String? opcode = messageDic['opcode'] as String?;
        if (opcode == 'S_AgentState') {
          _handleIncomingCall(messageDic);
        }
      }

      // 更新坐席状态
      if (code != null) {
        setState(() {
          _agentState = code;
          // 使用完整的状态映射表获取状态显示文本
          _dropDownText = _fullAgentStateMap[code] ?? '未知状态($code)';

          // 更新软电话在线状态
          _isSoftPhoneOnline = sipRegistrationStatus == 2; // 2表示注册成功
          _softPhoneStatus = _isSoftPhoneOnline ? '在线' : '离线';
        });

        // 更新可用状态列表
        _updateAvailableStates();

        debugPrint(
            '坐席状态已更新: code=$code, text=$_dropDownText, online=$_isSoftPhoneOnline');
      }
    } catch (e) {
      debugPrint('处理 soft_phone_status 事件失败: $e');
    }
  }

  /// 处理账号被挤事件
  /// 显示提示信息，清除登录状态，返回登录页面
  void _handleAccountKicked(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // 延迟一下再跳转，让用户看到提示信息
    Future.delayed(const Duration(seconds: 1), () {
      _forceLogout();
    });
  }

  /// 强制退出登录（用于账号被挤等情况）
  /// 清除登录状态，返回登录页面，不调用SDK注销方法
  Future<void> _forceLogout() async {
    try {
      // 清除本地登录状态
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_loginStatusKey, false);

      // 检查组件是否仍然挂载，避免内存泄漏
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      debugPrint('强制退出登录失败: $e');
      // 即使出错也要跳转到登录页
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  Future<void> _logoutAndReturnToLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_loginStatusKey, false);
      await QuanyuSdk().logout();
    } catch (e) {
      debugPrint('退出登录失败: $e');
    } finally {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
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
                _logoutAndReturnToLogin();
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  void _showOtherDeviceLoggingDialog(String deviceName) {
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
                _logoutAndReturnToLogin();
              },
              child: const Text('确认'),
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
                _logoutAndReturnToLogin();
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  /// 退出登录
  /// 立即跳转到登录页面，后台异步执行注销操作
  Future<void> _logout() async {
    try {
      // 后台异步执行注销操作，不阻塞页面跳转
      _performLogoutInBackground();

      // 立即清除本地登录状态
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_loginStatusKey, false);

      // 立即跳转到登录页面
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      debugPrint('退出登录失败: $e');
      // 即使出错也要跳转到登录页
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  /// 在后台执行注销操作
  /// 发送注销指令和SDK注销，不阻塞UI
  void _performLogoutInBackground() {
    // 使用unawaited确保这个操作在后台执行，不阻塞UI
    () async {
      try {
        // 发送注销指令
        const String message = '{"opcode": "C_Logout"}';
        await _sendCustomMessage(message);

        // 注销SDK连接
        await QuanyuSdk().logout();

        debugPrint('后台注销操作完成');
      } catch (e) {
        debugPrint('后台注销操作失败: $e');
      }
    }();
  }

  /// 构建输入行组件
  /// 创建带标签的输入框，用于号码输入
  Widget _buildInputRow(String label, TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      height: _inputHeight,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          // 标签区域
          Container(
            width: 80,
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          // 输入框区域
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone, // 数字键盘
              decoration: InputDecoration(
                hintText: '请输入',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
                border: InputBorder.none, // 无边框
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              ),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建操作按钮组件
  /// 创建统一样式的操作按钮，支持自定义颜色
  Widget _buildActionButton(String text, VoidCallback onPressed,
      {Color? color}) {
    return Expanded(
      child: Container(
        height: _buttonHeight,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? Colors.blue, // 默认蓝色
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8), // 圆角
            ),
            elevation: 0, // 无阴影
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建顶部栏
  /// 包含通话状态图标、坐席状态下拉菜单和快捷控制按钮
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          // 通话状态图标
          Icon(
            _isSoftPhoneOnline ? Icons.phone : Icons.phone_disabled,
            color: _isSoftPhoneOnline ? Colors.green : Colors.red,
            size: 24,
          ),
          const SizedBox(width: 4),
          // 电话状态文本
          Expanded(
            child: Text(
              _softPhoneStatus,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // 坐席状态下拉菜单
          GestureDetector(
            onTap: (_savedMessageDic != null || _isSoftPhoneOnline)
                ? _showStateSelectionDialog
                : null,
            child: Row(
              children: [
                Text(
                  _dropDownText,
                  style: TextStyle(
                    fontSize: 14,
                    color: _isSoftPhoneOnline ? null : Colors.red,
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 扬声器控制按钮
          GestureDetector(
            onTap: _toggleSpeaker,
            child: Text(
              '免提',
              style: TextStyle(
                color: _isSpeakerOn ? Colors.blue : Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  /// 构建状态显示卡片
  /// 显示电话连接状态、坐席状态和通话状态
  Widget _buildStatusCard() {
    return Card(
      margin: const EdgeInsets.all(_cardMargin),
      child: Padding(
        padding: const EdgeInsets.all(_cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '状态信息',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildStatusRow('软电话状态', _softPhoneStatus, _isSoftPhoneOnline),
            _buildStatusRow('坐席状态', _isSoftPhoneOnline ? _dropDownText : '离线',
                _isSoftPhoneOnline && _agentState == 1),
          ],
        ),
      ),
    );
  }

  /// 构建状态行
  Widget _buildStatusRow(String label, String value, bool isOnline) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                !isOnline && value == "空闲" ? "离线" : value,
                style: TextStyle(
                  fontSize: 14,
                  color: isOnline ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建音量控制卡片
  /// 提供喇叭和麦克风音量滑块控制，支持实时调节通话音量
  Widget _buildVolumeCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: _cardMargin),
      child: Padding(
        padding: const EdgeInsets.all(_cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '音量控制',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // 喇叭音量控制
            const Text(
              '喇叭音量',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Row(
              children: [
                const Icon(Icons.speaker, size: 20), // 喇叭图标
                Expanded(
                  child: Slider(
                    value: _speakerVolumeLevel,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10, // 分为10个档位
                    label: '${(_speakerVolumeLevel * 100).round()}%', // 显示百分比
                    onChanged: (value) async {
                      try {
                        // 实时调节SDK喇叭音量，将0.0-1.0转换为0-1000
                        await QuanyuSdk().setChannelOutputVolumeScaling(
                            volume: (value * 1000).toInt());
                        setState(() {
                          _speakerVolumeLevel = value;
                        });
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('设置喇叭音量失败: $e')),
                          );
                        }
                      }
                    },
                  ),
                ),
                const Icon(Icons.volume_up, size: 20), // 音量增大图标
              ],
            ),
            const SizedBox(height: 16),
            // 麦克风音量控制
            const Text(
              '麦克风音量',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Row(
              children: [
                const Icon(Icons.mic, size: 20), // 麦克风图标
                Expanded(
                  child: Slider(
                    value: _microphoneVolumeLevel,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10, // 分为10个档位
                    label:
                        '${(_microphoneVolumeLevel * 100).round()}%', // 显示百分比
                    onChanged: (value) async {
                      try {
                        // 实时调节SDK麦克风音量，将0.0-1.0转换为0-1000
                        await QuanyuSdk().setChannelInputVolumeScaling(
                            volume: (value * 1000).toInt());
                        setState(() {
                          _microphoneVolumeLevel = value;
                        });
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('设置麦克风音量失败: $e')),
                          );
                        }
                      }
                    },
                  ),
                ),
                const Icon(Icons.mic_none, size: 20), // 麦克风静音图标
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建外呼区域
  /// 提供主叫、被叫号码输入和呼叫控制功能
  Widget _buildOutboundCallSection() {
    return Container(
      padding: const EdgeInsets.all(_cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行，包含加载指示器
          const Row(
            children: [
              Text(
                '外呼',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 10),
            ],
          ),
          const SizedBox(height: 15),
          // 号码输入区域
          _buildInputRow('主叫号码', _callerController),
          _buildInputRow('被叫号码', _calleeController),
          const SizedBox(height: 20),
          // 操作按钮行
          Row(
            children: [
              _buildActionButton(
                  '呼叫',
                  () => _sendMakeCallOpcode(
                      _callerController.text, _calleeController.text)),
              const SizedBox(width: 10),
              _buildActionButton('取消呼叫', _sendCancelMakeCallOpcode,
                  color: Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建通话控制卡片
  /// 提供完整的通话控制功能：
  Widget _buildCallControlCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: _cardMargin),
      child: Padding(
        padding: const EdgeInsets.all(_cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '控制',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // 第一行按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 挂断按钮
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ElevatedButton.icon(
                      onPressed: _sendHangupOpcode,
                      icon: const Icon(Icons.call_end),
                      label: const Text('挂机'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                // 保持按钮
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ElevatedButton.icon(
                      onPressed: _toggleKeep,
                      icon: const Icon(Icons.pause),
                      label: const Text('保持'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            // 第二行按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 恢复按钮
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ElevatedButton.icon(
                      onPressed: _toggleRestore,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('恢复'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                // 保活控制
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ElevatedButton.icon(
                      onPressed: _toggleKeepAlive,
                      icon: Icon(_isKeepAlive
                          ? Icons.favorite
                          : Icons.favorite_border),
                      label: Text(_isKeepAlive ? '保活中' : '保活'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isKeepAlive ? Colors.orange : Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  /// 构建自定义消息控制卡片
  /// 提供sendRequest方法指令的封装功能
  Widget _buildCustomMessageCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: _cardMargin),
      child: Padding(
        padding: const EdgeInsets.all(_cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '方法指令',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Opcode指令控制行
            const Text(
              'Opcode 指令控制',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _sendSetBusyOpcode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('置忙'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _sendSetFreeOpcode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('置闲'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _sendSetRestOpcode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('小休'),
                  ),
                )
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _sendSilenceOpcode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('静音'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _sendEndProcessingOpcode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('话后处理'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 构建系统操作卡片
  /// 提供系统级操作，如退出登录等
  Widget _buildSystemOperationsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: _cardMargin),
      child: Padding(
        padding: const EdgeInsets.all(_cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '操作',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // 退出登录按钮
                ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('退出登录'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                Expanded(child: Container()), // 占位符，保持左对齐
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 释放资源
  /// 取消事件监听，释放控制器资源
  @override
  void dispose() {
    // 注销事件处理器
    final eventManager = QuanyuEventManager.instance;
    eventManager.unregisterEventHandler('soft_phone_registration_status',
        (eventMap) => _handleSoftPhoneRegistrationStatusEvent(eventMap));
    eventManager.unregisterEventHandler('soft_phone_status',
        (eventMap) => _handleSoftPhoneStatusEvent(eventMap));
    eventManager.unregisterEventHandler(
        'code_kicked', (eventMap) => _handleAccountKickedEvent(eventMap));

    _callerController.dispose();
    _calleeController.dispose();
    super.dispose();
  }

  /// 构建主界面
  /// 包含状态栏、顶部栏和可滚动的功能区域
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(), // 顶部控制栏

                _buildStatusCard(), // 状态显示卡片

                _buildOutboundCallSection(), // 外呼功能区

                _buildCallControlCard(), // 通话控制卡片
                const SizedBox(height: 10),

                _buildCustomMessageCard(), // 自定义消息控制卡片
                const SizedBox(height: 10),

                _buildVolumeCard(), // 音量控制卡片
                const SizedBox(height: 10),

                _buildSystemOperationsCard(), // 系统操作卡片
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
