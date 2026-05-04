import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/auth_service.dart';
import 'account_settings.dart';

class AuthPage extends StatefulWidget {
  final Map<String, dynamic>? currentUser;

  const AuthPage({super.key, this.currentUser});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _showSignUp = false;

  bool _isLoading = false;
  bool _regOptIn = false;

  final AuthService _authService = AuthService();

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

  // ── Logged-in view ─────────────────────────────────────────────────────────
  Widget _buildLoggedInView() {
    final email = widget.currentUser?['email'] as String? ?? '';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, size: 64),
            const SizedBox(height: 16),
            const Text(
              'You are currently signed in as',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              email,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    // Open account settings and return updated user (if any)
                    final res = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            // Lazy import to avoid cycles
                            AccountSettingsPage(
                              currentUser: widget.currentUser!,
                            ),
                      ),
                    );
                    if (res is Map<String, dynamic>) {
                      // Return updated user back to the main app
                      Navigator.of(context).pop(res);
                      return;
                    }
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Account Settings'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    // Pop back to the caller indicating sign-out explicitly.
                    Navigator.of(context).pop({'__logout__': true});
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
                      setState(() => _isLoading = false);

                      if (result['success'] == true) {
                        _showMessage('Login successful');
                        Navigator.of(context).pop(result['user']);
                      } else {
                        _showMessage(result['message'] ?? 'Login failed.');
                      }
                    },
              child: const Text('Login'),
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
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Receive occasional emails about Unify updates',
              ),
              value: _regOptIn,
              onChanged: (v) => setState(() => _regOptIn = v ?? false),
            ),
            const SizedBox(height: 12),
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
                        optInEmail: _regOptIn,
                      );
                      setState(() => _isLoading = false);

                      if (result['success'] == true) {
                        _showMessage('Registration successful');
                        // Optionally switch back to login form after sign-up
                        setState(() => _showSignUp = false);
                      } else {
                        _showMessage(
                          result['message'] ?? 'Registration failed.',
                        );
                      }
                    },
              child: const Text('Sign Up'),
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
    final bool isLoggedIn = widget.currentUser != null;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(
          isLoggedIn ? 'Account' : (_showSignUp ? 'Sign Up' : 'Login'),
        ),
      ),
      body: isLoggedIn
          ? _buildLoggedInView()
          : (_showSignUp ? _buildSignUpPage() : _buildLoginPage()),
    );
  }
}
