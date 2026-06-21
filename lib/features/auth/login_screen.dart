import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/form_factor_features.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/language_provider.dart';
import '../patient/find_doctors_screen.dart';
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus         = FocusNode();
  final _passwordFocus      = FocusNode();
  final _authService        = AuthService();
  bool _isLoading = false;
  bool _obscure   = true;

  Future<void> _showForgotPasswordDialog() async {
    final s = AppStrings(context.read<LanguageProvider>().isArabic);
    final emailCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.forgotPasswordTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.forgotPasswordHint,
                style: const TextStyle(fontSize: 14, color: Color(0xFF607D8B))),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(
                hintText: s.email,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.send),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final sent = await _authService.resetPassword(emailCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(sent ? s.forgotPasswordSent : s.forgotPasswordError),
        backgroundColor: sent ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Mobile-only "Continue as Guest" entry. No Supabase session is created
  /// and no data is written — the patient just gets a restricted preview of
  /// the Find a Therapist screen until they sign in.
  void _continueAsGuest() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FindDoctorsScreen(isGuest: true),
      ),
    );
  }

  Future<void> _handleLogin() async {
    final s = AppStrings(context.read<LanguageProvider>().isArabic);
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) return;
    setState(() => _isLoading = true);
    final user = await _authService.loginAdmin(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    if (!mounted) return;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.loginFailed)));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();
    final s            = AppStrings(langProvider.isArabic);
    final size         = MediaQuery.of(context).size;
    final isWide       = size.width >= 900;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Ambient gradient ────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE8F5E9),
                  Color(0xFFF0F9FF),
                  Color(0xFFE0F2F1),
                  Color(0xFFE3F2FD),
                ],
                stops: [0.0, 0.33, 0.66, 1.0],
              ),
            ),
          ),

          // ── PT-themed decorations ───────────────────────────────────────────
          const _PTBackground(),

          // ── Card ────────────────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 0 : 20,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWide ? 460 : 440),
                  child: _LoginCard(
                    emailController:    _emailController,
                    passwordController: _passwordController,
                    emailFocus:         _emailFocus,
                    passwordFocus:      _passwordFocus,
                    isLoading:          _isLoading,
                    obscure:            _obscure,
                    onObscureToggle:    () => setState(() => _obscure = !_obscure),
                    onLogin:            _handleLogin,
                    onForgotPassword:   _showForgotPasswordDialog,
                    langProvider:       langProvider,
                    s: s,
                    showGuestLogin:     FormFactorFeatures.of(context).showGuestLogin,
                    onContinueAsGuest:  _continueAsGuest,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Login card ─────────────────────────────────────────────────────────────────

class _LoginCard extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final bool isLoading;
  final bool obscure;
  final VoidCallback onObscureToggle;
  final VoidCallback onLogin;
  final VoidCallback onForgotPassword;
  final LanguageProvider langProvider;
  final AppStrings s;
  final bool showGuestLogin;
  final VoidCallback onContinueAsGuest;

  const _LoginCard({
    required this.emailController,
    required this.passwordController,
    required this.emailFocus,
    required this.passwordFocus,
    required this.isLoading,
    required this.obscure,
    required this.onObscureToggle,
    required this.onLogin,
    required this.onForgotPassword,
    required this.langProvider,
    required this.s,
    required this.showGuestLogin,
    required this.onContinueAsGuest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 44, 40, 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE4ECF5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.09),
            blurRadius: 64,
            offset: const Offset(0, 24),
            spreadRadius: -6,
          ),
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.07),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Logo ────────────────────────────────────────────────────────────
          const _PhysioLogo(size: 96),
          const SizedBox(height: 12),

          // ── App name gradient ────────────────────────────────────────────────
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF00897B), Color(0xFF2E7D32)],
              stops: [0.0, 0.5, 1.0],
            ).createShader(bounds),
            child: const Text(
              'PhysioConnect',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 30),

          // ── "Welcome Back!" ──────────────────────────────────────────────────
          Text(
            s.welcomeBack,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2E7D32),
              letterSpacing: -0.4,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 7),

          // ── Subheading ───────────────────────────────────────────────────────
          Text(
            s.signInSubtitle,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF90A4AE),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 32),

          // ── Email field ──────────────────────────────────────────────────────
          _InputField(
            controller: emailController,
            focusNode:  emailFocus,
            hintText:   s.emailOrUsername,
            icon:       Icons.person_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textDirection: langProvider.isArabic
                ? TextDirection.rtl
                : TextDirection.ltr,
            onSubmitted: (_) => passwordFocus.requestFocus(),
          ),
          const SizedBox(height: 14),

          // ── Password field ───────────────────────────────────────────────────
          _InputField(
            controller: passwordController,
            focusNode:  passwordFocus,
            hintText:   s.password,
            icon:       Icons.lock_outline_rounded,
            obscureText: obscure,
            onSubmitted: (_) => onLogin(),
            suffix: IconButton(
              onPressed: onObscureToggle,
              tooltip: obscure ? s.showPassword : s.hidePassword,
              icon: Icon(
                obscure
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: const Color(0xFF1565C0),
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Forgot Password ──────────────────────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onForgotPassword,
              child: Text(
                s.forgotPassword,
                style: const TextStyle(
                  color: Color(0xFF1565C0),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Sign In button ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 54,
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF2E7D32),
                      strokeWidth: 2.5,
                    ),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.38),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: onLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        s.signIn,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
          ),

          // ── Continue as Guest (mobile only) ──────────────────────────────────
          if (showGuestLogin) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: onContinueAsGuest,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2E7D32),
                  side: const BorderSide(color: Color(0xFFBBD1EA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  s.continueAsGuest,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 26),

          // ── Language toggle ──────────────────────────────────────────────────
          TextButton.icon(
            onPressed: langProvider.toggle,
            icon: const Icon(Icons.language_rounded,
                size: 15, color: Color(0xFF78909C)),
            label: Text(
              s.language,
              style: const TextStyle(color: Color(0xFF78909C), fontSize: 13),
            ),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF78909C)),
          ),

          // ── Privacy policy (required by App Store, Play Store, MS Store) ─────
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(AppStrings.privacyPolicyUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(
              s.privacyPolicy,
              style: const TextStyle(color: Color(0xFF78909C), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated focus input field ─────────────────────────────────────────────────

class _InputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  const _InputField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textDirection,
    this.onSubmitted,
    this.suffix,
  });

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: _focused ? const Color(0xFFF1FBF4) : const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: _focused ? const Color(0xFF43A047) : const Color(0xFFDDE3EA),
          width: _focused ? 1.5 : 1.0,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: const Color(0xFF43A047).withValues(alpha: 0.13),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: TextField(
        controller:    widget.controller,
        focusNode:     widget.focusNode,
        obscureText:   widget.obscureText,
        keyboardType:  widget.keyboardType,
        textDirection: widget.textDirection,
        onSubmitted:   widget.onSubmitted,
        style: const TextStyle(
          color: Color(0xFF1A2332),
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: const Color(0xFF2E7D32),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: const TextStyle(
            color: Color(0xFFB0BEC5),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(
              widget.icon,
              color: _focused ? const Color(0xFF2E7D32) : const Color(0xFFB0BEC5),
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 44),
          suffixIcon: widget.suffix,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
        ),
      ),
    );
  }
}

// ── New PhysioConnect logo ─────────────────────────────────────────────────────

class _PhysioLogo extends StatelessWidget {
  final double size;
  const _PhysioLogo({this.size = 96});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: const Color(0xFF00897B).withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _PhysioLogoPainter(),
        size: Size(size, size),
      ),
    );
  }
}

class _PhysioLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final w = size.width;

    // ── 1. Gradient background circle ─────────────────────────────────────────
    final bgRect  = Rect.fromCircle(center: c, radius: r);
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1565C0),
          Color(0xFF0277BD),
          Color(0xFF00695C),
          Color(0xFF2E7D32),
        ],
        stops: [0.0, 0.32, 0.65, 1.0],
      ).createShader(bgRect);
    canvas.drawCircle(c, r, bgPaint);

    // ── 2. Outer ring ──────────────────────────────────────────────────────────
    canvas.drawCircle(c, r - 2,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // ── 3. Head (filled circle) ────────────────────────────────────────────────
    final headR  = w * 0.10;
    final headCY = c.dy - r * 0.54;
    canvas.drawCircle(
      Offset(c.dx, headCY),
      headR,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );

    // ── 4. Shoulders arc ──────────────────────────────────────────────────────
    final shoulderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final shoulderY = headCY + headR + w * 0.04;
    canvas.drawLine(
      Offset(c.dx - w * 0.22, shoulderY + w * 0.06),
      Offset(c.dx,             shoulderY),
      shoulderPaint,
    );
    canvas.drawLine(
      Offset(c.dx,             shoulderY),
      Offset(c.dx + w * 0.22, shoulderY + w * 0.06),
      shoulderPaint,
    );

    // ── 5. Spinal column (the core PT symbol) ─────────────────────────────────
    const vertebrae = 6;
    final spineTop    = shoulderY + w * 0.04;
    final spineBottom = c.dy + r * 0.52;
    final totalH      = spineBottom - spineTop;
    final vH          = totalH / (vertebrae + (vertebrae - 1) * 0.45);
    final gapH        = vH * 0.45;
    final vW          = w * 0.32;
    final wingW       = w * 0.13;
    final wingH       = vH * 0.55;

    for (int i = 0; i < vertebrae; i++) {
      final vy = spineTop + i * (vH + gapH);
      final vc = Offset(c.dx, vy + vH / 2);

      // Body of vertebra
      final shade = i.isEven
          ? Colors.white.withValues(alpha: 0.92)
          : Colors.white.withValues(alpha: 0.78);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: vc, width: vW, height: vH),
          const Radius.circular(3),
        ),
        Paint()..color = shade,
      );

      // Transverse processes (wings)
      for (final side in [-1, 1]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(c.dx + side * (vW / 2 + wingW / 2), vy + vH * 0.35),
              width: wingW,
              height: wingH,
            ),
            const Radius.circular(2),
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.55),
        );
      }

      // Inter-vertebral disc gap (teal accent)
      if (i < vertebrae - 1) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(c.dx, vy + vH + gapH / 2),
              width: vW * 0.70,
              height: gapH * 0.60,
            ),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFF80CBC4).withValues(alpha: 0.70),
        );
      }
    }

    // ── 6. Glossy highlight (top-left lens) ───────────────────────────────────
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.55, -0.55),
        radius: 0.88,
        colors: [
          Colors.white.withValues(alpha: 0.25),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(bgRect);

    canvas.save();
    canvas.clipPath(Path()..addOval(bgRect));
    canvas.drawRect(bgRect, highlightPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── PT-themed background ──────────────────────────────────────────────────────

class _PTBackground extends StatelessWidget {
  const _PTBackground();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _PTBackgroundPainter(), child: const SizedBox.expand());
}

class _PTBackgroundPainter extends CustomPainter {
  static const _green = Color(0xFF43A047);
  static const _blue  = Color(0xFF1565C0);
  static const _teal  = Color(0xFF00897B);

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;

    // ── Ambient blobs ──────────────────────────────────────────────────────────
    _blob(canvas, Offset(W * 0.08,  H * 0.14),  110,
        _blue.withValues(alpha: 0.035));
    _blob(canvas, Offset(W * 0.92,  H * 0.72),  120,
        _green.withValues(alpha: 0.035));
    _blob(canvas, Offset(W * 0.88,  H * 0.20),   80,
        _teal.withValues(alpha: 0.035));
    _blob(canvas, Offset(W * 0.14,  H * 0.80),   85,
        _blue.withValues(alpha: 0.030));

    // ── Dot grid (subtle) ──────────────────────────────────────────────────────
    _dotGrid(canvas, size);

    // ── Anatomical elements ────────────────────────────────────────────────────
    // TOP-LEFT: spine
    _spine(canvas, Offset(W * 0.06, H * 0.08),
        Paint()..color = _blue.withValues(alpha: 0.09)..style = PaintingStyle.fill);

    // TOP-RIGHT: brain
    _brain(canvas, Offset(W * 0.88, H * 0.10),
        Paint()..color = _green.withValues(alpha: 0.09)..style = PaintingStyle.fill,
        Paint()..color = _green.withValues(alpha: 0.10)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // LEFT-MID: wave / muscle fibers
    _muscle(canvas, Offset(W * 0.055, H * 0.48),
        Paint()..color = _teal.withValues(alpha: 0.09)..style = PaintingStyle.fill);

    // RIGHT-MID: bone
    _bone(canvas, Offset(W * 0.935, H * 0.42),
        Paint()..color = _blue.withValues(alpha: 0.09)..style = PaintingStyle.fill,
        Paint()..color = _blue.withValues(alpha: 0.09)..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round);

    // BOTTOM-LEFT: healing cross
    _cross(canvas, Offset(W * 0.08, H * 0.82),
        Paint()..color = _teal.withValues(alpha: 0.09)..style = PaintingStyle.fill,
        Paint()..color = _teal.withValues(alpha: 0.09)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // BOTTOM-RIGHT: crutch pair
    _crutches(canvas, Offset(W * 0.88, H * 0.78),
        Paint()..color = _green.withValues(alpha: 0.10)..style = PaintingStyle.fill,
        Paint()..color = _green.withValues(alpha: 0.10)..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round);

    // BOTTOM-CENTER: nerve branching
    _nerve(canvas, Offset(W * 0.50, H * 0.90),
        Paint()..color = _blue.withValues(alpha: 0.09)..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round);

    // Extra small nerve right
    _nerve(canvas, Offset(W * 0.76, H * 0.60),
        Paint()..color = _teal.withValues(alpha: 0.09)..style = PaintingStyle.stroke..strokeWidth = 1.6..strokeCap = StrokeCap.round);

    // ── Flow arcs (motion / vitality) ─────────────────────────────────────────
    _flowArc(canvas, Offset(W * 0.5, H * 0.0), W * 0.72, size,
        _green.withValues(alpha: 0.05));
    _flowArc(canvas, Offset(W * 0.0, H * 0.5), H * 0.65, size,
        _blue.withValues(alpha: 0.04));
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _blob(Canvas canvas, Offset c, double r, Color color) =>
      canvas.drawCircle(c, r, Paint()..color = color);

  void _dotGrid(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = const Color(0xFF1565C0).withValues(alpha: 0.04);
    const step = 44.0;
    for (double x = step; x < size.width; x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }
  }

  void _spine(Canvas canvas, Offset top, Paint fill) {
    for (int i = 0; i < 8; i++) {
      final cy = top.dy + i * 21.0;
      final cx = top.dx;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy), width: 26, height: 12),
            const Radius.circular(3)),
        fill,
      );
      for (final s in [-1, 1]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(cx + s * 20.0, cy), width: 11, height: 5),
              const Radius.circular(2)),
          fill,
        );
      }
    }
  }

  void _brain(Canvas canvas, Offset c, Paint fill, Paint stroke) {
    for (final s in [-1, 1]) {
      canvas.drawOval(
          Rect.fromCenter(
              center: c + Offset(s * 13.0, 0), width: 32, height: 40),
          fill);
    }
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: c + const Offset(0, 24), width: 11, height: 12),
            const Radius.circular(3)),
        fill);
    canvas.drawLine(c - const Offset(0, 18), c + const Offset(0, 14),
        Paint()
          ..color = stroke.color
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke);
  }

  void _muscle(Canvas canvas, Offset c, Paint fill) {
    for (int i = 0; i < 5; i++) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(c.dx + (i.isOdd ? 4.0 : 0.0), c.dy + i * 14.0),
            width: 60,
            height: 10),
        fill,
      );
    }
  }

  void _bone(Canvas canvas, Offset c, Paint fill, Paint shaft) {
    const angle = -pi / 5;
    const len   = 44.0;
    final p1 = Offset(c.dx - len * cos(angle), c.dy - len * sin(angle));
    final p2 = Offset(c.dx + len * cos(angle), c.dy + len * sin(angle));
    canvas.drawLine(p1, p2, shaft);
    for (final p in [p1, p2]) {
      canvas.drawCircle(p, 12, fill);
      canvas.drawCircle(
          p + Offset(-3 * cos(angle - pi / 2), -3 * sin(angle - pi / 2)),
          7, fill);
    }
  }

  void _cross(Canvas canvas, Offset c, Paint fill, Paint stroke) {
    const arm = 16.0;
    const w   = 6.5;
    final path = Path()
      ..addRect(Rect.fromCenter(center: c, width: w, height: arm * 2))
      ..addRect(Rect.fromCenter(center: c, width: arm * 2, height: w));
    canvas.drawPath(path, fill);
    canvas.drawCircle(c, arm + 8, stroke);
  }

  void _crutches(Canvas canvas, Offset o, Paint fill, Paint stroke) {
    for (int i = 0; i < 2; i++) {
      final ox = o.dx + i * 26.0;
      final oy = o.dy;
      canvas.drawLine(Offset(ox - 10, oy), Offset(ox + 10, oy), stroke);
      canvas.drawLine(Offset(ox - 8, oy + 20), Offset(ox + 8, oy + 20), stroke);
      canvas.drawLine(Offset(ox, oy), Offset(ox, oy + 62), stroke);
      canvas.drawCircle(Offset(ox, oy + 62), 3.5, fill);
    }
  }

  void _nerve(Canvas canvas, Offset root, Paint stroke) {
    canvas.drawLine(root, root + const Offset(0, 22), stroke);
    canvas.drawLine(root + const Offset(0, 11), root + const Offset(-16, 30), stroke);
    canvas.drawLine(root + const Offset(0, 11), root + const Offset(16, 30), stroke);
    canvas.drawLine(root + const Offset(-16, 30), root + const Offset(-24, 48), stroke);
    canvas.drawLine(root + const Offset(-16, 30), root + const Offset(-6, 48), stroke);
    canvas.drawLine(root + const Offset(16, 30), root + const Offset(6, 48), stroke);
    canvas.drawLine(root + const Offset(16, 30), root + const Offset(26, 48), stroke);
    final dot = Paint()..color = stroke.color..style = PaintingStyle.fill;
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(root + Offset(0, 3 + i * 6.0), 2.2, dot);
    }
  }

  void _flowArc(
      Canvas canvas, Offset center, double radius, Size size, Color color) {
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0, pi,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 60
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
