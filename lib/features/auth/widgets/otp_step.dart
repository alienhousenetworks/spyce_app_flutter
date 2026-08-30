import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/onboarding_theme.dart';
import '../../../core/theme/spyce_colors.dart';
import '../../../shared/widgets/onboarding_widgets.dart';
import '../../../shared/widgets/turnstile_widget.dart';
import '../auth_controller.dart';

class OtpStep extends StatefulWidget {
  const OtpStep({
    super.key,
    required this.email,
    required this.mode,
    required this.loading,
    required this.error,
    required this.message,
    required this.onBack,
    required this.onResend,
    required this.onVerify,
  });

  final String email;
  final AuthMode mode;
  final bool loading;
  final String? error;
  final String? message;
  final VoidCallback onBack;
  final Future<void> Function(String? captchaToken) onResend;
  final Future<void> Function(String otp) onVerify;

  @override
  State<OtpStep> createState() => _OtpStepState();
}

class _OtpStepState extends State<OtpStep> with WidgetsBindingObserver {
  late TextEditingController _otpCtrl;
  late FocusNode _focusNode;
  Key _fieldKey = UniqueKey();
  String? _captchaToken;
  int _turnstileReset = 0;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _otpCtrl = TextEditingController();
    _otpCtrl.addListener(_onOtpChanged);
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureKeyboard());
  }

  void _onOtpChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _otpCtrl.removeListener(_onOtpChanged);
    _otpCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving for mail / WhatsApp / SMS detaches the Samsung IME. If we keep
    // the same FocusNode, a later tap is a no-op and typing never arrives.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _focusNode.unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    } else if (state == AppLifecycleState.resumed) {
      _rebuildImeAfterResume();
    }
  }

  Future<void> _rebuildImeAfterResume() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    _rebindInputConnection(keepText: true);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    _ensureKeyboard();
  }

  void _rebindInputConnection({required bool keepText}) {
    final text = keepText ? _otpCtrl.text : '';
    final oldFocus = _focusNode;
    final oldCtrl = _otpCtrl;
    oldCtrl.removeListener(_onOtpChanged);
    _otpCtrl = TextEditingController(text: text);
    _otpCtrl.addListener(_onOtpChanged);
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _fieldKey = UniqueKey();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldFocus.dispose();
      oldCtrl.dispose();
    });
  }

  void _ensureKeyboard() {
    if (!mounted) return;
    FocusScope.of(context).requestFocus(_focusNode);
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  Future<void> _onBoxTap() async {
    // If the IME died after an app switch, the field can still report focus
    // while swallowing keystrokes. Drop focus, then show the keyboard again.
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
    }
    _ensureKeyboard();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await widget.onVerify(_otpCtrl.text);
  }

  Future<void> _resend() async {
    if (Env.turnstileEnabled &&
        (_captchaToken == null || _captchaToken!.isEmpty)) {
      setState(
        () => _localError = 'Complete the captcha below to resend the code.',
      );
      return;
    }
    setState(() => _localError = null);
    await widget.onResend(_captchaToken);
    if (!mounted) return;
    setState(() {
      _captchaToken = null;
      _turnstileReset++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showError = _localError ?? widget.error;
    final codeText = _otpCtrl.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: widget.loading ? null : widget.onBack,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter your code',
                  style: GoogleFonts.syne(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit code to ${widget.email}',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    height: 1.4,
                    color: OnboardingColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),

                AutofillGroup(
                  child: SizedBox(
                    height: 52,
                    child: Stack(
                      children: [
                        Row(
                          children: List.generate(6, (index) {
                            final char = index < codeText.length
                                ? codeText[index]
                                : '';
                            final isFocused =
                                _focusNode.hasFocus &&
                                (index == codeText.length ||
                                    (index == 5 && codeText.length == 6));
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: index == 5 ? 0 : 6,
                                ),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _onBoxTap,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: OnboardingColors.inputFill,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isFocused
                                            ? SpyceColors.pink
                                            : OnboardingColors.inputBorder,
                                        width: isFocused ? 1.8 : 1.0,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      char,
                                      style: GoogleFonts.syne(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        Positioned.fill(
                          child: TextField(
                            key: _fieldKey,
                            controller: _otpCtrl,
                            focusNode: _focusNode,
                            autofocus: true,
                            showCursor: true,
                            enableInteractiveSelection: true,
                            enableSuggestions: false,
                            autocorrect: false,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            maxLength: 6,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            style: const TextStyle(
                              color: Colors.transparent,
                              fontSize: 24,
                              letterSpacing: 32,
                              height: 1,
                            ),
                            cursorColor: Colors.white,
                            decoration: const InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: true,
                              fillColor: Colors.transparent,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onTap: _onBoxTap,
                            onSubmitted: (_) => _submit(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                if (Env.showMagicOtpHint) ...[
                  Text(
                    'Testing: use magic OTP ${Env.magicOtp}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SpyceColors.success,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Didn\'t receive the code?',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: OnboardingColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: widget.loading ? null : _resend,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OnboardingColors.inputFill,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(
                          color: OnboardingColors.inputBorder,
                        ),
                      ),
                    ),
                    child: Text(
                      'Resend',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                if (Env.turnstileEnabled) ...[
                  const SizedBox(height: 16),
                  TurnstileWidget(
                    resetKey: _turnstileReset,
                    onTokenReceived: (token) {
                      setState(() {
                        _captchaToken = token;
                        _localError = null;
                      });
                    },
                    onExpired: () {
                      setState(() {
                        _captchaToken = null;
                        _localError =
                            'Captcha expired — complete it again to resend.';
                      });
                    },
                    onError: () {
                      setState(() => _captchaToken = null);
                    },
                  ),
                ],
                if (showError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    showError,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: SpyceColors.error,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (widget.message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: SpyceColors.success,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: OnboardingPrimaryButton(
            label: 'Verify',
            loading: widget.loading,
            onPressed: codeText.length == 6 ? _submit : null,
          ),
        ),
      ],
    );
  }
}
