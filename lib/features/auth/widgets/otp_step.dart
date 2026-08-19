import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/onboarding_theme.dart';
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

class _OtpStepState extends State<OtpStep> {
  late final TextEditingController _otpCtrl;
  late final FocusNode _focusNode;
  String? _captchaToken;
  int _turnstileReset = 0;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _otpCtrl = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: widget.loading ? null : widget.onBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OnboardingGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            children: [
              Text(
                'Enter the 6-digit code sent to your mail',
                textAlign: TextAlign.center,
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // 6 PIN Input Boxes matching Figma Frame 3835
              GestureDetector(
                onTap: () => _focusNode.requestFocus(),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        final char = index < codeText.length
                            ? codeText[index]
                            : '';
                        final isFocused =
                            _focusNode.hasFocus &&
                            (index == codeText.length ||
                                (index == 5 && codeText.length == 6));
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 44,
                          height: 50,
                          decoration: BoxDecoration(
                            color: OnboardingColors.inputFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isFocused
                                  ? Colors.white
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
                        );
                      }),
                    ),
                    // Invisible text field capturing keyboard inputs
                    Opacity(
                      opacity: 0,
                      child: SizedBox(
                        height: 1,
                        child: TextField(
                          controller: _otpCtrl,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          maxLength: 6,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _submit(),
                        ),
                      ),
                    ),
                  ],
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
                    color: Colors.tealAccent,
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
                    color: Color(0xFFFF6B81),
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
                    color: Colors.tealAccent,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              OnboardingPrimaryButton(
                label: 'Verify',
                loading: widget.loading,
                onPressed: codeText.length == 6 ? _submit : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
