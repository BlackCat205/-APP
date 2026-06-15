import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

/// 登录页面：手机号+验证码登录
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  int _countdown = 0;

  static const int _countdownSeconds = 60;
  static const int _phoneLength = 11;
  static const int _codeLength = 6;
  static const double _defaultPadding = 24.0;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_phoneController.text.isEmpty) {
      _showSnackBar('请输入手机号');
      return;
    }
    if (_phoneController.text.length != _phoneLength) {
      _showSnackBar('请输入正确的手机号');
      return;
    }
    setState(() => _countdown = _countdownSeconds);
    _showSnackBar('验证码已发送');
    _startCountdown();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _countdown > 0) {
        setState(() => _countdown--);
        return true;
      }
      return false;
    });
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await Future.delayed(const Duration(seconds: 1)); // 模拟网络请求
      await userProvider.login(
        phone: _phoneController.text,
        nickname: '用户${_phoneController.text.substring(7)}',
      );
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar('登录成功');
      }
    } catch (e) {
      if (mounted) _showSnackBar('登录失败，请重试');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

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

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(_defaultPadding),
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

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('欢迎登录',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('使用手机号登录，体验更多功能',
            style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildPhoneInput() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      maxLength: _phoneLength,
      decoration: const InputDecoration(
        labelText: '手机号',
        prefixIcon: Icon(Icons.phone),
        border: OutlineInputBorder(),
        counterText: '',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return '请输入手机号';
        if (value.length != _phoneLength) return '请输入正确的手机号';
        return null;
      },
    );
  }

  Widget _buildCodeInput() {
    return TextFormField(
      controller: _codeController,
      keyboardType: TextInputType.number,
      maxLength: _codeLength,
      decoration: InputDecoration(
        labelText: '验证码',
        prefixIcon: const Icon(Icons.verified_user),
        border: const OutlineInputBorder(),
        counterText: '',
        suffixIcon: TextButton(
          onPressed: _countdown > 0 ? null : _sendCode,
          child: Text(
            _countdown > 0 ? '$_countdown秒后重发' : '获取验证码',
            style: TextStyle(color: _countdown > 0 ? Colors.grey : Colors.red),
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return '请输入验证码';
        if (value.length != _codeLength) return '请输入6位验证码';
        return null;
      },
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  Widget _buildAgreementText() {
    return Center(
      child: Text('登录即表示同意《用户协议》和《隐私政策》',
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
    );
  }

  Widget _buildHintText() {
    return Center(
      child: const Text('提示：输入任意手机号和6位验证码即可登录',
          style: TextStyle(fontSize: 12, color: Colors.orange)),
    );
  }
}