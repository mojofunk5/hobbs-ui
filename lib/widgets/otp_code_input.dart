import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A row of [length] single-digit boxes for entering a numeric one-time code - mirrors the segmented
/// OTP input UX from things-ui's password reset screen, matched here since hobbs's own reset code
/// is the same shape (a 6-digit numeric string, see PasswordReset.generateCode()).
class OtpCodeInput extends StatefulWidget {
  const OtpCodeInput(
      {super.key,
      required this.onChanged,
      this.length = 6,
      this.enabled = true});

  final ValueChanged<String> onChanged;
  final int length;
  final bool enabled;

  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _notify() {
    widget.onChanged(_controllers.map((c) => c.text).join());
  }

  void _distributePaste(String pasted, int startIndex) {
    final digits = pasted.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    var box = startIndex;
    for (var i = 0; i < digits.length && box < widget.length; i++, box++) {
      _controllers[box].text = digits[i];
    }
    _focusNodes[(box - 1).clamp(0, widget.length - 1)].requestFocus();
    _notify();
  }

  void _onChanged(int index, String value) {
    // A multi-character value only happens via paste (a single keystroke can't produce more than
    // one character in an empty box) - anything longer than one digit gets distributed across the
    // remaining boxes instead of overflowing this one.
    if (value.length > 1) {
      _distributePaste(value, index);
      return;
    }
    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    _notify();
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      _notify();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < widget.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Focus(
              onKeyEvent: (_, event) => _onKey(i, event),
              child: TextField(
                enabled: widget.enabled,
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                // Deliberately no maxLength here: a paste needs the *full* pasted string to reach
                // _onChanged uncut so it can be distributed across the other boxes - each box is
                // trimmed back to a single digit as part of that distribution, not by a formatter
                // truncating the paste before it's even seen.
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofillHints:
                    i == 0 ? const [AutofillHints.oneTimeCode] : null,
                decoration: const InputDecoration(counterText: ''),
                onChanged: (value) => _onChanged(i, value),
                // Selects the existing digit so tapping back into an already-filled box and typing
                // replaces it, rather than appending a second character (which would otherwise
                // wrongly trigger the paste-distribution path above for a value.length of 2).
                onTap: () => _controllers[i].selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _controllers[i].text.length,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
