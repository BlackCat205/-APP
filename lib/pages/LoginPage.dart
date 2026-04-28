import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

/// 登录页面
/// 支持手机号+验证码登录，包含验证码倒计时、表单验证等功能
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 手机号输入控制器
  final TextEditingController _phoneController = TextEditingController();
  // 验证码输入控制器
  final TextEditingController _codeController = TextEditingController();
  // 表单验证Key
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  // 登录加载状态
  bool _isLoading = false;
  // 验证码倒计时（秒）
  int _countdown = 0;

  @override
  void dispose() {
    // 释放控制器资源
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// 发送验证码
  /// 1. 验证手机号格式
  /// 2. 启动倒计时
  /// 3. 提示验证码发送成功（实际项目需对接接口）
  Future<void> _sendCode() async {
    // 手机号为空校验
    if (_phoneController.text.isEmpty) {
      _showSnackBar('请输入手机号');
      return;
    }

    // 手机号长度校验
    if (_phoneController.text.length != 11) {
      _showSnackBar('请输入正确的手机号');
      return;
    }

    // 启动60秒倒计时
    setState(() {
      _countdown = 60;
    });

    _showSnackBar('验证码已发送');
    _startCountdown();
  }

  /// 启动验证码倒计时
  /// 每秒更新倒计时数值，直到倒计时结束
  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));

      if (mounted && _countdown > 0) {
        setState(() {
          _countdown--;
        });
        return true;
      }

      return false;
    });
  }

  /// 执行登录逻辑
  /// 1. 表单验证
  /// 2. 调用登录接口
  /// 3. 处理登录结果（成功/失败）
  Future<void> _login() async {
    // 表单验证
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 显示加载状态
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取用户状态管理Provider
      final UserProvider userProvider =
      Provider.of<UserProvider>(context, listen: false);

      // 模拟接口请求延迟（实际项目移除）
      await Future.delayed(const Duration(seconds: 1));

      // 调用登录方法
      await userProvider.login(
        phone: _phoneController.text,
        nickname: '用户${_phoneController.text.substring(7)}',
      );

      // 登录成功处理
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar('登录成功');
      }
    } catch (e) {
      // 登录失败处理
      if (mounted) {
        _showSnackBar('登录失败，请重试');
      }
    } finally {
      // 隐藏加载状态
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 显示SnackBar提示
  /// [message] 提示文本
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  /// 构建页面AppBar
  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('登录'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      elevation: 1,
    );
  }

  /// 构建页面主体内容
  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            _buildTitleSection(),
            const SizedBox(height: 48),
            _buildPhoneInput(),
            const SizedBox(height: 16),
            _buildCodeInput(),
            const SizedBox(height: 32),
            _buildLoginButton(),
            const SizedBox(height: 24),
            _buildAgreementText(),
            const SizedBox(height: 16),
            _buildHintText(),
          ],
        ),
      ),
    );
  }

  /// 构建标题区域
  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '欢迎登录',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '使用手机号登录，体验更多功能',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// 构建手机号输入框
  Widget _buildPhoneInput() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      maxLength: 11,
      decoration: const InputDecoration(
        labelText: '手机号',
        prefixIcon: Icon(Icons.phone),
        border: OutlineInputBorder(),
        counterText: '', // 隐藏字符计数
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入手机号';
        }
        if (value.length != 11) {
          return '请输入正确的手机号';
        }
        return null;
      },
    );
  }

  /// 构建验证码输入框
  Widget _buildCodeInput() {
    return TextFormField(
      controller: _codeController,
      keyboardType: TextInputType.number,
      maxLength: 6,
      decoration: InputDecoration(
        labelText: '验证码',
        prefixIcon: const Icon(Icons.verified_user),
        border: const OutlineInputBorder(),
        counterText: '', // 隐藏字符计数
        suffixIcon: TextButton(
          onPressed: _countdown > 0 ? null : _sendCode,
          child: Text(
            _countdown > 0 ? '${_countdown}秒后重发' : '获取验证码',
            style: TextStyle(
              color: _countdown > 0 ? Colors.grey : Colors.red,
            ),
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入验证码';
        }
        if (value.length != 6) {
          return '请输入6位验证码';
        }
        return null;
      },
    );
  }

  /// 构建登录按钮
  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : const Text('登录', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  /// 构建用户协议文本
  Widget _buildAgreementText() {
    return Center(
      child: Text(
        '登录即表示同意《用户协议》和《隐私政策》',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  /// 构建提示文本
  Widget _buildHintText() {
    return Center(
      child: Text(
        '提示：输入任意手机号和6位验证码即可登录',
        style: TextStyle(
          fontSize: 12,
          color: Colors.orange,
        ),
      ),
    );
  }
}