import 'package:flutter/material.dart';
import 'services/auth_service.dart';

class AccountSettingsPage extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  const AccountSettingsPage({super.key, this.currentUser});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _currentPassword = TextEditingController();
  final TextEditingController _newEmail = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  bool _optIn = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = widget.currentUser;
    if (user != null) {
      _optIn = user['opt_in_email'] == true;
      _newEmail.text = user['email'] ?? '';
    }
  }

  @override
  void dispose() {
    _currentPassword.dispose();
    _newEmail.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final authToken = widget.currentUser?['auth_token'] as String?;

    final result = await _authService.updateSettings(
      authToken: authToken,
      email: widget.currentUser?['email'] as String?,
      currentPassword: _currentPassword.text.isEmpty
          ? null
          : _currentPassword.text,
      newEmail: _newEmail.text.isEmpty ? null : _newEmail.text.trim(),
      newPassword: _newPassword.text.isEmpty ? null : _newPassword.text,
      optInEmail: _optIn,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showMessage('Settings updated');
      Navigator.of(context).pop({'user': result['user']});
    } else {
      _showMessage(result['message'] ?? 'Update failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account settings'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              TextFormField(
                controller: _newEmail,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!val.contains('@') || !val.contains('.')) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _currentPassword,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (val) {
                  // Current password is required to change settings
                  if (val == null || val.isEmpty) {
                    return 'Enter your current password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPassword,
                decoration: const InputDecoration(
                  labelText: 'New password (optional)',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (val) {
                  if (val != null && val.isNotEmpty && val.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _optIn,
                onChanged: (v) => setState(() => _optIn = v ?? false),
                title: const Text('Subscribe to mailing list'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save settings',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
