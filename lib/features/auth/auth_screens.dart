part of '../../main.dart';

class StartupLoadingScreen extends StatelessWidget {
  const StartupLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CcColors.hero,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const BrandMark(onDark: true, centered: true),
                const SizedBox(height: 38),
                Container(
                  width: 126,
                  height: 126,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .10),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: CcColors.lime.withValues(alpha: .55),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: CircularProgressIndicator(
                        strokeWidth: 5,
                        color: CcColors.lime,
                        backgroundColor: CcColors.green,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  context.t('Preparing CalamansiCare'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.t('Loading saved settings and reports.'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      backgroundColor: CcColors.hero,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: HeroLeafPainter()),
                      ),
                      Positioned(
                        top: 8,
                        right: 24,
                        child: OfflinePill(label: state.readinessLabel),
                      ),
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 18,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'CalamansiCare',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge
                                    ?.copyWith(color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.t(
                                'AI disease detection and treatment guide for calamansi farmers.',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                  decoration: const BoxDecoration(
                    color: CcColors.bgAlt,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.t(
                          'Choose language / Pumili ng wika / Pili og pinulongan',
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: LanguageChoice(
                              language: supportedLanguages[0],
                              selected: state.language == supportedLanguages[0],
                              onSelected: () =>
                                  state.setLanguage(supportedLanguages[0]),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: LanguageChoice(
                              language: supportedLanguages[1],
                              selected: state.language == supportedLanguages[1],
                              onSelected: () =>
                                  state.setLanguage(supportedLanguages[1]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Center(
                            child: SizedBox(
                              width: (constraints.maxWidth - 12) / 2,
                              child: LanguageChoice(
                                language: supportedLanguages[2],
                                selected:
                                    state.language == supportedLanguages[2],
                                onSelected: () =>
                                    state.setLanguage(supportedLanguages[2]),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Start plant check',
                        icon: Icons.eco,
                        onPressed: () async {
                          final accepted =
                              await ensureTermsAgreementAccepted(context);
                          if (accepted && context.mounted) {
                            replaceWith(context, const MainShell());
                          }
                        },
                      ),
                      if (!state.isSignedIn) ...[
                        const SizedBox(height: 10),
                        OutlineAction(
                          label: 'Sign in or create account',
                          icon: Icons.account_circle_outlined,
                          onTap: () => go(context, const AuthLandingScreen()),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            context
                                .t('You can check plants without an account.'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: CcColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthLandingScreen extends StatefulWidget {
  const AuthLandingScreen({super.key});

  @override
  State<AuthLandingScreen> createState() => _AuthLandingScreenState();
}

class _AuthLandingScreenState extends State<AuthLandingScreen> {
  AuthFormMode _mode = AuthFormMode.signIn;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return ScreenFrame(
      showNav: false,
      child: SingleChildScrollView(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopLine(
            title: 'Account',
            subtitle:
                'Sign in to sync reports and restore saved data after reinstalling.',
            trailing: IconButton(
              tooltip: context.t('Close'),
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          const SizedBox(height: 16),
          state.isSignedIn
              ? SectionCard(
                  title: 'Account connected',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.accountEmail,
                        style: const TextStyle(
                          color: CcColors.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Sign out',
                        icon: Icons.logout_rounded,
                        color: CcColors.red,
                        onPressed: () async {
                          final confirmed =
                              await showSignOutConfirmation(context);
                          if (!confirmed || !context.mounted) return;
                          await state.signOut();
                          state.setTab(0);
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute<void>(
                                    builder: (_) => const WelcomeScreen()),
                                (_) => false);
                          }
                        },
                      ),
                    ],
                  ),
                )
              : AuthPanel(
                  mode: _mode,
                  onModeChanged: (mode) => setState(() => _mode = mode),
                ),
          if (!isKeyboardOpen) ...[
            const SizedBox(height: 14),
            if (!state.isSignedIn) ...[
              const NoticeCard(
                text:
                    'You can still scan offline. Sign in is only needed before sending reports online.',
              ),
              const SizedBox(height: 14),
            ],
            OutlineAction(
              label: state.isSignedIn ? 'Go to Dashboard' : 'Continue offline',
              icon: state.isSignedIn
                  ? Icons.dashboard_rounded
                  : Icons.eco_rounded,
              onTap: () => replaceWith(context, const MainShell()),
            ),
          ],
        ],
      )),
    );
  }
}

enum AuthFormMode { signIn, create }

class AuthPanel extends StatelessWidget {
  const AuthPanel({
    super.key,
    required this.mode,
    required this.onModeChanged,
  });

  final AuthFormMode mode;
  final ValueChanged<AuthFormMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.authConfigured) {
      return const SectionCard(
        title: 'Account',
        child: NoticeCard(
          text:
              'Supabase is not configured on this build. Add env keys before using accounts.',
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        children: [
          AuthModeToggle(mode: mode, onChanged: onModeChanged),
          const SizedBox(height: 12),
          SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Image.asset('assets/google-g.png',
                    width: 20, height: 20, excludeFromSemantics: true),
                label: Text(context.t('Sign in with Google')),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: Colors.white,
                    foregroundColor: CcColors.ink,
                    textStyle: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    side: const BorderSide(color: CcColors.muted),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                onPressed: () async {
                  try {
                    await state.signInWithGoogle();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.t(
                              'Google sign-in opened. Complete it in the browser.',
                            ),
                          ),
                        ),
                      );
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.t(
                              'Google sign-in is not ready yet. Check Supabase Google setup.',
                            ),
                          ),
                        ),
                      );
                    }
                  }
                },
              )),
          const SizedBox(height: 12),
          const Row(children: [
            Expanded(child: Divider()),
            Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('or use email',
                    style: TextStyle(fontSize: 12, color: CcColors.muted))),
            Expanded(child: Divider())
          ]),
          const SizedBox(height: 12),
          AuthFormContent(
            mode: mode,
            onSwitchMode: onModeChanged,
          ),
        ],
      ),
    );
  }
}

class AuthModeToggle extends StatelessWidget {
  const AuthModeToggle(
      {super.key, required this.mode, required this.onChanged});

  final AuthFormMode mode;
  final ValueChanged<AuthFormMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AuthFormMode>(
      style: ButtonStyle(
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          textStyle: const WidgetStatePropertyAll(TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.w600))),
      segments: [
        ButtonSegment(
          value: AuthFormMode.signIn,
          label: Text(context.t('Sign in')),
          icon: const Icon(Icons.login_rounded),
        ),
        ButtonSegment(
          value: AuthFormMode.create,
          label: Text(context.t('Create account')),
          icon: const Icon(Icons.person_add_alt_1_rounded),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) => onChanged(selection.first),
      showSelectedIcon: false,
    );
  }
}

class AuthFormScreen extends StatefulWidget {
  const AuthFormScreen({super.key, required this.mode});

  final AuthFormMode mode;

  @override
  State<AuthFormScreen> createState() => _AuthFormScreenState();
}

class AuthFormContent extends StatefulWidget {
  const AuthFormContent({
    super.key,
    required this.mode,
    this.onSwitchMode,
  });

  final AuthFormMode mode;
  final ValueChanged<AuthFormMode>? onSwitchMode;

  @override
  State<AuthFormContent> createState() => _AuthFormContentState();
}

class _AuthFormScreenState extends State<AuthFormScreen> {
  @override
  Widget build(BuildContext context) {
    final isCreate = widget.mode == AuthFormMode.create;
    return ScreenFrame(
      showNav: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TopLine(
              title: isCreate ? 'Create account' : 'Sign in',
              subtitle: isCreate
                  ? 'Use this account to restore synced reports later.'
                  : 'Use your account to sync and restore reports.',
              trailing: IconButton(
                tooltip: context.t('Back'),
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const SizedBox(height: 16),
            AuthFormContent(mode: widget.mode),
          ],
        ),
      ),
    );
  }
}

class _AuthFormContentState extends State<AuthFormContent> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _officeEmailController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  bool get _isCreate => widget.mode == AuthFormMode.create;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    _nameController.text =
        _nameController.text.isEmpty ? state.farmerName : _nameController.text;
    _locationController.text = _locationController.text.isEmpty
        ? state.farmerLocation
        : _locationController.text;
    _officeEmailController.text = _officeEmailController.text.isEmpty
        ? state.officeEmail
        : _officeEmailController.text;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _officeEmailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final state = AppScope.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('Enter an email and a password with at least 6 letters.'),
          ),
        ),
      );
      return;
    }
    if (_isCreate &&
        (_nameController.text.trim().isEmpty ||
            _locationController.text.trim().isEmpty ||
            _officeEmailController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .t('Please complete name, farm location, and barangay email.'),
          ),
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      if (_isCreate) {
        await state.setFarmerName(_nameController.text.trim());
        await state.setFarmerLocation(_locationController.text.trim());
        await state.setEmail(_officeEmailController.text.trim());
        await state.createAccount(email: email, password: password);
      } else {
        await state.signIn(email: email, password: password);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                _isCreate
                    ? (state.isSignedIn
                        ? 'Account created and signed in.'
                        : 'Please check your email, then sign in.')
                    : 'Signed in successfully.',
              ),
            ),
          ),
        );
        Navigator.maybePop(context);
      }
    } on AccountCreatedNeedsSignInException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('Please check your email, then sign in.')),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(accountErrorMessage(error)),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionCard(
          title: _isCreate ? 'Farmer account' : 'Account details',
          child: Column(
            children: [
              if (_isCreate) ...[
                AuthTextField(
                  controller: _nameController,
                  label: 'Farmer name',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 10),
                AuthTextField(
                  controller: _locationController,
                  label: 'Farm location',
                  icon: Icons.place_outlined,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 10),
                AuthTextField(
                  controller: _officeEmailController,
                  label: 'Barangay email',
                  icon: Icons.mark_email_unread_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
              ],
              AuthTextField(
                controller: _emailController,
                label: 'Email address',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              AuthTextField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  tooltip: context.t(
                    _obscurePassword ? 'Show password' : 'Hide password',
                  ),
                  onPressed: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              if (!_isCreate) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => go(context, const ForgotPasswordScreen()),
                    child: Text(context.t('Forgot password?')),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: _isSubmitting
              ? (_isCreate ? 'Creating account...' : 'Signing in...')
              : (_isCreate ? 'Create account' : 'Sign in'),
          icon:
              _isCreate ? Icons.person_add_alt_1_rounded : Icons.login_rounded,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: widget.onSwitchMode == null
              ? null
              : () => widget.onSwitchMode!(
                    _isCreate ? AuthFormMode.signIn : AuthFormMode.create,
                  ),
          child: Text(
            context.t(
              _isCreate
                  ? 'Already have an account? Sign in'
                  : 'New here? Create account',
            ),
          ),
        ),
      ],
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _isSending = true);
    try {
      await AppScope.of(context).sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('Password reset email sent.')),
          ),
        );
        Navigator.maybePop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('Could not send reset email. Try again.')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      showNav: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopLine(
            title: 'Forgot password',
            subtitle: 'Enter your email to receive a reset link.',
            trailing: IconButton(
              tooltip: context.t('Back'),
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Email address',
            child: AuthTextField(
              controller: _emailController,
              label: 'Email address',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          const Spacer(),
          PrimaryButton(
            label: _isSending ? 'Sending email...' : 'Send reset email',
            icon: Icons.mark_email_read_outlined,
            isLoading: _isSending,
            onPressed: _isSending ? null : _send,
          ),
        ],
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontSize: 15, color: CcColors.ink),
      decoration: InputDecoration(
        labelText: context.t(label),
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        prefixIconColor: CcColors.green,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class LanguageChoice extends StatelessWidget {
  const LanguageChoice({
    super.key,
    required this.language,
    required this.selected,
    required this.onSelected,
  });

  final String language;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onSelected,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? CcColors.green : Colors.white,
          foregroundColor: selected ? Colors.white : CcColors.ink,
          side: const BorderSide(color: CcColors.line),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
        child: Text(language, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
