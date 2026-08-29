import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../api/api_exception.dart';
import '../api/auth_api.dart';
import '../session_store.dart';
import '../widgets/otp_code_input.dart';
import '../widgets/responsive_page.dart';
import 'signed_in_screen.dart';

enum _Step { request, confirm }

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen(
      {super.key, this.httpClient, this.initialEmail, this.initialCode});

  /// Overridable for tests - see test/reset_password_screen_test.dart.
  final http.Client? httpClient;

  /// Set when arriving via the emailed reset link (main.dart parses ?email=&code= from the
  /// loading URL) - jumps straight to the confirm step with both pre-filled, matching things-ui's
  /// handling of the same deep link.
  final String? initialEmail;
  final String? initialCode;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _requestFormKey = GlobalKey<FormState>();
  final _confirmFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();

  late _Step _step;
  late bool _codeLocked;
  String _code = '';
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeLocked = widget.initialEmail != null && widget.initialCode != null;
    _step = _codeLocked ? _Step.confirm : _Step.request;
    if (_codeLocked) {
      _emailController.text = widget.initialEmail!;
      _code = widget.initialCode!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String value) {
    final at = value.indexOf('@');
    return at > 0 && value.indexOf('.', at) > at + 1;
  }

  Future<void> _submitRequest() async {
    if (!_requestFormKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AuthApi.requestPasswordReset(
        email: _emailController.text.trim(),
        client: widget.httpClient,
      );
      if (!mounted) return;
      setState(() => _step = _Step.confirm);
    } catch (e) {
      // Deliberately generic - never confirms whether the email exists, matching the backend's own
      // /auth/password-reset, which always returns 200 regardless.
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitConfirm() async {
    if (!_confirmFormKey.currentState!.validate()) return;
    if (_code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final session = await AuthApi.confirmPasswordReset(
        email: _emailController.text.trim(),
        code: _code,
        newPassword: _newPasswordController.text,
        client: widget.httpClient,
      );
      await SessionStore.save(session);
      TextInput.finishAutofillContext();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => SignedInScreen(session: session)),
        (route) => false,
      );
    } on ApiException {
      // One message for both causes - matches the backend's own deliberately-ambiguous 400 for
      // "bad new password" and "invalid/expired/used code", so this never reveals which it was.
      setState(() => _error =
          'Invalid or expired code, or the new password was rejected.');
    } catch (e) {
      setState(() => _error = 'Could not reach the backend: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _useADifferentEmail() {
    setState(() {
      _step = _Step.request;
      _codeLocked = false;
      _code = '';
      _newPasswordController.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: ResponsivePage(
        child: _step == _Step.request
            ? _buildRequestStep(context)
            : _buildConfirmStep(context),
      ),
    );
  }

  Widget _buildRequestStep(BuildContext context) {
    return Form(
      key: _requestFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Enter your email and we'll send you a reset code.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username],
            validator: (v) => (v == null || !_looksLikeEmail(v.trim()))
                ? 'Enter a valid email address'
                : null,
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _submitting ? null : _submitRequest,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send reset code'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmStep(BuildContext context) {
    return Form(
      key: _confirmFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "If an account exists for that email, we've sent a reset code. Enter it below "
            'along with your new password.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _emailController.text,
            decoration: const InputDecoration(labelText: 'Email'),
            enabled: false,
          ),
          const SizedBox(height: 16),
          OtpCodeInput(
            onChanged: (code) => _code = code,
            initialValue: _codeLocked ? widget.initialCode : null,
            enabled: !_codeLocked,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _newPasswordController,
            decoration: const InputDecoration(labelText: 'New password'),
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _submitting ? null : _submitConfirm,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Reset password'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _submitting ? null : _useADifferentEmail,
            child: const Text('Use a different email'),
          ),
        ],
      ),
    );
  }
}
