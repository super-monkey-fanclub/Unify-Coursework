import 'package:flutter/material.dart';

import 'services/auth_service.dart';

class AccountSettingsPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;

  const AccountSettingsPage({super.key, required this.currentUser});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  late TextEditingController _emailController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmNewPasswordController;
  bool _optIn = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.currentUser['email'] as String? ?? '');
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmNewPasswordController = TextEditingController();
    _optIn = widget.currentUser['opt_in_email'] as bool? ?? false;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    String? current = _currentPasswordController.text.isEmpty ? null : _currentPasswordController.text;
    String? newPass = _newPasswordController.text.isEmpty ? null : _newPasswordController.text;

    setState(() => _isLoading = true);
    final res = await _authService.updateAccount(
      authToken: widget.currentUser['auth_token'] as String,
      email: _emailController.text.trim(),
      currentPassword: current,
      newPassword: newPass,
      optInEmail: _optIn,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      _showMessage('Account updated');
      Navigator.of(context).pop(res['user']);
      return;
    }

    _showMessage(res['message'] ?? 'Update failed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Email is required';
                  if (!val.contains('@') || !val.contains('.')) return 'Enter a valid email address';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Receive occasional emails about Unify updates'),
                value: _optIn,
                onChanged: (v) => setState(() => _optIn = v ?? false),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _currentPasswordController,
                decoration: const InputDecoration(labelText: 'Current password', border: OutlineInputBorder()),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPasswordController,
                decoration: const InputDecoration(labelText: 'New password', border: OutlineInputBorder()),
                obscureText: true,
                validator: (val) {
                  if (_currentPasswordController.text.isNotEmpty && (val == null || val.isEmpty)) return 'Enter a new password';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmNewPasswordController,
                decoration: const InputDecoration(labelText: 'Confirm new password', border: OutlineInputBorder()),
                obscureText: true,
                validator: (val) {
                  if (_newPasswordController.text.isNotEmpty && val != _newPasswordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
