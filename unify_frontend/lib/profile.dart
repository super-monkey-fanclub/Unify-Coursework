import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/auth_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _showSignUp = false;
  bool _isLoading = false;

  final _authService = AuthService();
  final _loginKey = GlobalKey<FormState>();
  final _regKey = GlobalKey<FormState>();

  final TextEditingController _loginEmail = TextEditingController();
  final TextEditingController _loginPassword = TextEditingController();

  final TextEditingController _regName = TextEditingController();
  final TextEditingController _regEmail = TextEditingController();
  final TextEditingController _regPassword = TextEditingController();
  final TextEditingController _regConfirm = TextEditingController();

  @override
  void dispose() {
    _loginEmail.dispose();
    _loginPassword.dispose();
    _regName.dispose();
    _regEmail.dispose();
    _regPassword.dispose();
    _regConfirm.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isValidEmail(String email) {
    return email.contains('@') && email.contains('.');
  }

  // ── Login page ─────────────────────────────────────────────────────────────
  Widget _buildLoginPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _loginKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            TextFormField(
              controller: _loginEmail,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (val) {
                if (val == null || val.trim().isEmpty)
                  return 'Email is required';
                if (!_isValidEmail(val.trim()))
                  return 'Enter a valid email address';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _loginPassword,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Password is required';
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (!_loginKey.currentState!.validate()) return;
                      setState(() => _isLoading = true);
                      final result = await _authService.login(
                        email: _loginEmail.text.trim(),
                        password: _loginPassword.text,
                      );
                      if (!mounted) return;
                      setState(() => _isLoading = false);
                      if (result['success'] == true) {
                        final user = result['user'] as Map<String, dynamic>;
                        _showMessage('Welcome back, ${user['name']}!');
                        Navigator.pop(context);
                      } else {
                        _showMessage(result['message'] ?? 'Login failed.');
                      }
                    },
              child: _isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Login'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _showSignUp = true),
              child: const Text('Not a member? Sign up now'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sign-up page ────────────────────────────────────────────────────────────
  Widget _buildSignUpPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _regKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            TextFormField(
              controller: _regName,
              decoration: const InputDecoration(
                labelText: 'Preferred name',
                border: OutlineInputBorder(),
                helperText: 'Maximum 50 characters',
              ),
              maxLength: 50,
              inputFormatters: [LengthLimitingTextInputFormatter(50)],
              validator: (val) {
                if (val == null || val.trim().isEmpty)
                  return 'Preferred name is required';
                if (val.trim().length > 50)
                  return 'Name must be 50 characters or fewer';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _regEmail,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (val) {
                if (val == null || val.trim().isEmpty)
                  return 'Email is required';
                if (!_isValidEmail(val.trim()))
                  return 'Enter a valid email address';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _regPassword,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Password is required';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _regConfirm,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (val) {
                if (val == null || val.isEmpty)
                  return 'Please confirm your password';
                if (val != _regPassword.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (!_regKey.currentState!.validate()) return;
                      setState(() => _isLoading = true);
                      final result = await _authService.register(
                        name: _regName.text.trim(),
                        email: _regEmail.text.trim(),
                        password: _regPassword.text,
                      );
                      if (!mounted) return;
                      setState(() => _isLoading = false);
                      if (result['success'] == true) {
                        _showMessage(
                          'Account created! Your UP number is ${result['upNumber']}.',
                        );
                        _regName.clear();
                        _regEmail.clear();
                        _regPassword.clear();
                        _regConfirm.clear();
                        setState(() => _showSignUp = false);
                      } else {
                        _showMessage(
                          result['message'] ?? 'Registration failed.',
                        );
                      }
                    },
              child: _isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign Up'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _showSignUp = false),
              child: const Text('Already a member? Log in'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(_showSignUp ? 'Sign Up' : 'Login'),
      ),
      body: _showSignUp ? _buildSignUpPage() : _buildLoginPage(),
    );
  }
}
