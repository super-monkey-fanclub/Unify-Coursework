import 'package:flutter/material.dart';

class AuthPage extends StatefulWidget {
	const AuthPage({super.key});

	@override
	State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
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

	void _showPlaceholder(String message) {
		ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
	}

	@override
	Widget build(BuildContext context) {
		return DefaultTabController(
			length: 2,
			child: Scaffold(
				appBar: AppBar(
					backgroundColor: Theme.of(context).colorScheme.primary,
					title: const Text('Account'),
					bottom: const TabBar(
						tabs: [Tab(text: 'Login'), Tab(text: 'Register')],
					),
				),
				body: TabBarView(
					children: [
						// Login Tab
						Padding(
							padding: const EdgeInsets.all(16.0),
							child: Form(
								key: _loginKey,
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.stretch,
									children: [
										TextFormField(
											controller: _loginEmail,
											decoration: const InputDecoration(labelText: 'Email'),
											keyboardType: TextInputType.emailAddress,
										),
										const SizedBox(height: 12),
										TextFormField(
											controller: _loginPassword,
											decoration: const InputDecoration(labelText: 'Password'),
											obscureText: true,
										),
										const SizedBox(height: 24),
										ElevatedButton(
											onPressed: () {
												_showPlaceholder('Login not implemented');
											},
											child: const Text('Login'),
										),
									],
								),
							),
						),

						// Register Tab
						Padding(
							padding: const EdgeInsets.all(16.0),
							child: Form(
								key: _regKey,
								child: SingleChildScrollView(
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.stretch,
										children: [
											TextFormField(
												controller: _regName,
												decoration: const InputDecoration(labelText: 'Full name'),
											),
											const SizedBox(height: 12),
											TextFormField(
												controller: _regEmail,
												decoration: const InputDecoration(labelText: 'Email'),
												keyboardType: TextInputType.emailAddress,
											),
											const SizedBox(height: 12),
											TextFormField(
												controller: _regPassword,
												decoration: const InputDecoration(labelText: 'Password'),
												obscureText: true,
											),
											const SizedBox(height: 12),
											TextFormField(
												controller: _regConfirm,
												decoration: const InputDecoration(labelText: 'Confirm password'),
												obscureText: true,
											),
											const SizedBox(height: 24),
											ElevatedButton(
												onPressed: () {
													_showPlaceholder('Registration not implemented');
												},
												child: const Text('Register'),
											),
										],
									),
								),
							),
						),
					],
				),
			),
		);
	}
}

