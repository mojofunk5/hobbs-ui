import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../api/api_exception.dart';
import '../api/auth_api.dart';
import '../remembered_identifier.dart';
import '../session_store.dart';
import '../widgets/responsive_page.dart';
import 'reset_password_screen.dart';
import 'signed_in_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.httpClient});

  /// Overridable for tests - see test/login_screen_test.dart.
  final http.Client? httpClient;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  bool _rememberMe = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    RememberedIdentifier.load().then((identifier) {
      if (!mounted || identifier == null) return;
      setState(() {
        _identifierController.text = identifier;
        _rememberMe = true;
      });
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final identifier = _identifierController.text.trim();
      final session = await AuthApi.login(
        identifier: identifier,
        password: _passwordController.text,
        client: widget.httpClient,
      );
      await SessionStore.save(session);
      // Only actually persisted on a successful login, not on every keystroke or a failed
      // attempt - and unchecking then logging in actively clears any previously remembered value.
      if (_rememberMe) {
        await RememberedIdentifier.save(identifier);
      } else {
        await RememberedIdentifier.clear();
      }
      // Tells the browser the credentials just entered were genuinely used to complete a
      // sign-in, which is what prompts Chrome/Safari to offer saving them - without this call
      // the password manager has no signal that submission actually succeeded.
      TextInput.finishAutofillContext();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => SignedInScreen(session: session)),
        (route) => false,
      );
    } on ApiException catch (e) {
      setState(() {
        _error = switch (e.statusCode) {
          401 => 'Invalid email/password combination.',
          _ => 'Login failed (HTTP ${e.statusCode}).',
        };
      });
    } catch (e) {
      setState(() => _error = 'Could not reach the backend: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log in')),
      body: ResponsivePage(
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _identifierController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                CheckboxListTile(
                  value: _rememberMe,
                  onChanged: (value) =>
                      setState(() => _rememberMe = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Remember my email'),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ResetPasswordScreen()),
                      ),
                      child: const Text('Forgot password?'),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Log in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
