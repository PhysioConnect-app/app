import 'dart:math';
import 'package:flutter/material.dart';
import '../../widgets/physio_logo.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/form_factor_features.dart';
import '../../core/utils/pwa_install.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/language_provider.dart';
import '../patient/find_doctors_screen.dart';
import '../store/doctor_storefront_screen.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _showRequestAccountDialog() async {
    final nameCtrl  = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    bool hasDoctorate = false;
    bool sending = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.person_add_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 10),
            Text('Request a Doctor Account'),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(
                'Fill in your details and the admin team will review your request.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address *',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: hasDoctorate,
                onChanged: (v) => setBS(() => hasDoctorate = v ?? false),
                title: const Text('I hold a doctorate / PhD',
                    style: TextStyle(fontSize: 13)),
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: sending
                  ? null
                  : () async {
                      final name  = nameCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      if (name.isEmpty || email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Name and email are required.')),
                        );
                        return;
                      }
                      setBS(() => sending = true);
                      try {
                        await Supabase.instance.client
                            .from('account_requests')
                            .insert({
                          'therapist_name': name,
                          'email':          email,
                          'phone_number':   phoneCtrl.text.trim(),
                          'has_doctorate':  hasDoctorate,
                          'status':         'pending',
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Request submitted! We\'ll be in touch.'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setBS(() => sending = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
              child: sending
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
  }

  void _openPhysioGate() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DoctorStorefrontScreen()),
    );
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
          // ── Ambient gradient — single teal family ───────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE0F2F1), // teal 50
                  Color(0xFFF4F9F9),
                  Color(0xFFE0F7FA), // cyan 50
                  Color(0xFFE8F5E9), // light green 50
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
                    langProvider:       langProvider,
                    s: s,
                    showGuestLogin:     FormFactorFeatures.of(context).showGuestLogin,
                    onContinueAsGuest:  _continueAsGuest,
                    onRequestAccount:   _showRequestAccountDialog,
                    onOpenPhysioGate:   _openPhysioGate,
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
  final LanguageProvider langProvider;
  final AppStrings s;
  final bool showGuestLogin;
  final VoidCallback onContinueAsGuest;
  final VoidCallback onRequestAccount;
  final VoidCallback onOpenPhysioGate;

  const _LoginCard({
    required this.emailController,
    required this.passwordController,
    required this.emailFocus,
    required this.passwordFocus,
    required this.isLoading,
    required this.obscure,
    required this.onObscureToggle,
    required this.onLogin,
    required this.langProvider,
    required this.s,
    required this.showGuestLogin,
    required this.onContinueAsGuest,
    required this.onRequestAccount,
    required this.onOpenPhysioGate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 44, 40, 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFB2DFDB), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00897B).withValues(alpha: 0.10),
            blurRadius: 48,
            offset: const Offset(0, 16),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: const Color(0xFF00897B).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Logo — responsive font size for small screens ────────────────────
          LayoutBuilder(
            builder: (_, constraints) {
              final size = (constraints.maxWidth * 0.135).clamp(24.0, 38.0);
              return PhysioLogo(fontSize: size, showTagline: true);
            },
          ),
          const SizedBox(height: 28),

          // ── "Welcome Back!" ──────────────────────────────────────────────────
          Text(
            s.welcomeBack,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2332),
              letterSpacing: -0.3,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),

          // ── Subheading ───────────────────────────────────────────────────────
          Text(
            s.signInSubtitle,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF78909C),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 32),

          // ── Email field ──────────────────────────────────────────────────────
          _InputField(
            key: const Key('login_email_field'),
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
            key: const Key('login_password_field'),
            controller: passwordController,
            focusNode:  passwordFocus,
            hintText:   s.password,
            icon:       Icons.lock_outline_rounded,
            obscureText: obscure,
            onSubmitted: (_) => onLogin(),
            suffix: IconButton(
              key: const Key('login_password_toggle'),
              onPressed: onObscureToggle,
              tooltip: obscure ? s.showPassword : s.hidePassword,
              icon: Icon(
                obscure
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: const Color(0xFF00897B),
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Request Account ───────────────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('login_request_account_btn'),
              onPressed: onRequestAccount,
              icon: const Icon(Icons.person_add_rounded, size: 15),
              label: const Text(
                'Request a Doctor / PT Account',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00897B),
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Sign In button ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00897B),
                      strokeWidth: 2.5,
                    ),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00897B), Color(0xFF00695C)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00897B).withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      key: const Key('login_sign_in_btn'),
                      onPressed: onLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        s.signIn,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
          ),

          // ── Continue as Guest (mobile only) ──────────────────────────────────
          if (showGuestLogin) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                key: const Key('login_guest_btn'),
                onPressed: onContinueAsGuest,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00897B),
                  side: const BorderSide(color: Color(0xFF80CBC4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  s.continueAsGuest,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // ── Divider ──────────────────────────────────────────────────────────
          Row(children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500)),
            ),
            const Expanded(child: Divider()),
          ]),
          const SizedBox(height: 16),

          // ── PhysioGate square tile ───────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  key: const Key('login_physiogate_tile'),
                  onTap: onOpenPhysioGate,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCE93D8), width: 1.5),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: Image.asset(
                        'assets/images/physiogate_logo.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.store_rounded,
                          size: 42,
                          color: Color(0xFF4527A0),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'PhysioGate',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4527A0),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Language toggle ──────────────────────────────────────────────────
          TextButton.icon(
            key: const Key('login_language_toggle'),
            onPressed: langProvider.toggle,
            icon: const Icon(Icons.language_rounded,
                size: 15, color: Color(0xFF78909C)),
            label: Text(
              s.language,
              style: const TextStyle(color: Color(0xFF78909C), fontSize: 13),
            ),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF78909C)),
          ),

          // ── PWA install banner (Android / iOS) ───────────────────────────────
          const _PwaInstallBanner(),
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
    super.key,
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
        color: _focused ? const Color(0xFFE0F2F1) : const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: _focused ? const Color(0xFF00897B) : const Color(0xFFDDE3EA),
          width: _focused ? 1.5 : 1.0,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: const Color(0xFF00897B).withValues(alpha: 0.13),
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
        cursorColor: const Color(0xFF00897B),
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
              color: _focused ? const Color(0xFF00897B) : const Color(0xFFB0BEC5),
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

// ── PWA install banner ─────────────────────────────────────────────────────────

class _PwaInstallBanner extends StatefulWidget {
  const _PwaInstallBanner();

  @override
  State<_PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<_PwaInstallBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed || isStandalone) return const SizedBox.shrink();
    if (isInstallPromptAvailable) return _androidBanner();
    if (isIos) return _iosBanner();
    return const SizedBox.shrink();
  }

  Widget _androidBanner() => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2F1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF80CBC4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.download_rounded,
                  color: Color(0xFF00897B), size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Install PhysioConnect on this device',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF00695C),
                      fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 30,
                child: ElevatedButton(
                  onPressed: () {
                    triggerInstallPrompt();
                    setState(() => _dismissed = true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Download'),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => setState(() => _dismissed = true),
                icon: const Icon(Icons.close,
                    size: 16, color: Color(0xFF90A4AE)),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
        ),
      );

  Widget _iosBanner() => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFA5D6A7)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.ios_share,
                  color: Color(0xFF2E7D32), size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text.rich(
                  TextSpan(
                    style:
                        TextStyle(fontSize: 12, color: Color(0xFF1B5E20)),
                    children: [
                      TextSpan(text: 'Add to Home Screen: tap '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Icon(Icons.ios_share,
                            size: 13, color: Color(0xFF2E7D32)),
                      ),
                      TextSpan(text: ' then "Add to Home Screen"'),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _dismissed = true),
                icon: const Icon(Icons.close,
                    size: 16, color: Color(0xFF90A4AE)),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
        ),
      );
}
