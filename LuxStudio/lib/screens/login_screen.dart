import 'package:flutter/material.dart';

import '../main.dart';
import '../state/app_state.dart';
import '../theme/lux_theme.dart';
import '../widgets/lux_buttons.dart';
import '../widgets/lux_card.dart';

/// Single shared church-passcode gate — V2 Decision #1 (PIVOT_PLAN_V2.md):
/// no per-user accounts/sessions, just one passcode the whole staff shares,
/// checked via [AppState.verifyPasscode] against the backend's
/// `/auth/verify`. Visually follows `ui_kit/auth/index.html`'s card shell
/// and palette, but that mockup's email/password/sign-up/social-login UI
/// is deliberately not built here — it doesn't match this decision.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passcodeController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState appState) async {
    final passcode = _passcodeController.text.trim();
    if (passcode.isEmpty || appState.isVerifyingPasscode) return;
    await appState.verifyPasscode(passcode);
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: LuxColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/branding/icon.png', width: 56, height: 56),
                  const SizedBox(height: 14),
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(text: 'Lux', style: LuxText.sora(size: 26, color: LuxColors.textPrimary)),
                      TextSpan(text: 'Studio', style: LuxText.sora(size: 26, color: LuxColors.gold)),
                    ]),
                  ),
                  const SizedBox(height: 32),
                  AnimatedBuilder(
                    animation: appState,
                    builder: (context, _) => LuxCard(
                      radius: 24,
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CHURCH PASSCODE',
                            style: LuxText.manrope(
                              size: 10,
                              weight: FontWeight.w700,
                              color: LuxColors.textSecondary,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _passcodeController,
                            obscureText: _obscure,
                            autofocus: true,
                            style: LuxText.manrope(size: 15, color: LuxColors.textPrimary),
                            onSubmitted: (_) => _submit(appState),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: LuxColors.background,
                              hintText: '••••••••',
                              hintStyle: LuxText.manrope(size: 15, color: LuxColors.textMutedAlt),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                                color: LuxColors.textSecondary,
                                size: 19,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: LuxColors.textMuted,
                                  size: 19,
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(LuxRadii.button),
                                borderSide: const BorderSide(color: LuxColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(LuxRadii.button),
                                borderSide: const BorderSide(color: LuxColors.gold),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(LuxRadii.button),
                              ),
                            ),
                          ),
                          if (appState.passcodeError != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              appState.passcodeError!,
                              style: LuxText.manrope(size: 12, color: LuxColors.error),
                            ),
                          ],
                          const SizedBox(height: 22),
                          LuxPrimaryButton(
                            label: 'UNLOCK STUDIO',
                            loading: appState.isVerifyingPasscode,
                            onPressed: () => _submit(appState),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Ask your ministry lead for the shared studio passcode.',
                    textAlign: TextAlign.center,
                    style: LuxText.manrope(size: 12, color: LuxColors.textMutedAlt),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
