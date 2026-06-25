import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/crypto_service.dart';
import '../../../core/constants/app_constants.dart';
import '../bloc/auth_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = AppRoles.patient;
  bool _obscurePassword = true;
  bool _biometricAvailable = false;
  bool _hasSavedCredentials = false;
  String _savedEmail = '';
  String _savedRole = '';
  late AnimationController _shimmerController;

  final List<Map<String, dynamic>> _roles = [
    {'value': AppRoles.patient, 'label': 'Patient', 'icon': Icons.person_outline},
    {'value': AppRoles.doctor, 'label': 'Doctor', 'icon': Icons.medical_services_outlined},
    {'value': AppRoles.lab, 'label': 'Lab Technician', 'icon': Icons.biotech_outlined},
    {'value': AppRoles.pharmacist, 'label': 'Pharmacist', 'icon': Icons.local_pharmacy_outlined},
    {'value': AppRoles.nurse, 'label': 'Nurse', 'icon': Icons.medical_information_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _checkBiometrics();
    _loadSavedCredentials();
    context.read<AuthBloc>().add(AuthCheckSession());
  }

  Future<void> _checkBiometrics() async {
    final available = await BiometricService.isAvailable();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('cc_last_email') ?? '';
      final savedRole = prefs.getString('cc_last_role') ?? '';
      if (savedEmail.isNotEmpty && mounted) {
        setState(() {
          _hasSavedCredentials = true;
          _savedEmail = savedEmail;
          _savedRole = savedRole;
          _emailController.text = savedEmail;
          if (savedRole.isNotEmpty) _selectedRole = savedRole;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) async {
        if (state is AuthAuthenticated) {
          // Save credentials for future biometric login
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('cc_last_email', state.user.email);
            await prefs.setString('cc_last_role', state.user.role);
            if (_passwordController.text.isNotEmpty) {
              await CryptoService.storeKey('cc_secure_pass_${state.user.email}', _passwordController.text);
            }
          } catch (_) {}
          if (context.mounted) context.go(state.user.dashboardRoute);
        } else if (state is AuthError) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.error,
              ),
            );
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Stack(
          children: [
            // Background gradient blobs
            _buildBackgroundBlobs(),
            // Header
            _buildHeader(),
            // Main content
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 80),
                    // Logo & Branding
                    _buildLogo(),
                    const SizedBox(height: 32),
                    // Login Card
                    _buildLoginCard(),
                    const SizedBox(height: 24),
                    // Footer
                    _buildFooter(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            // Bottom status bar
            _buildStatusBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundBlobs() {
    return Stack(
      children: [
        Positioned(
          top: -60,
          right: -60,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryFixed.withValues(alpha: 0.3),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: -40,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.secondaryContainer.withValues(alpha: 0.2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              // CareCrypt Logo mark
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.security, color: AppTheme.onPrimary, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'CareCrypt',
                style: AppTextStyles.titleLg.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              // AES-256 badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user, size: 12, color: AppTheme.secondary),
                    const SizedBox(width: 4),
                    Text(
                      'AES-256',
                      style: AppTextStyles.codeSm.copyWith(
                        color: AppTheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        // Logo with glow
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppTheme.primaryFixed.withValues(alpha: 0.4),
                AppTheme.primaryFixed.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'CareCrypt',
          style: AppTextStyles.headlineLg.copyWith(color: AppTheme.onSurface),
        ),
        const SizedBox(height: 8),
        Text(
          'Secure Healthcare Platform — Your Data, Your Control.',
          style: AppTextStyles.bodyMd.copyWith(
            color: AppTheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Role selector
            _buildLabel('Access Role'),
            const SizedBox(height: 8),
            _buildRoleSelector(),
            const SizedBox(height: 20),

            // Email field
            _buildLabel('Healthcare ID or Email'),
            const SizedBox(height: 8),
            _buildEmailField(),
            const SizedBox(height: 20),

            // Password field
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLabel('Security Key'),
                GestureDetector(
                  onTap: () {},
                  child: Text(
                    'Forgot Password?',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildPasswordField(),
            const SizedBox(height: 24),

            // Login button
            _buildLoginButton(),
            const SizedBox(height: 20),

            // Divider
            Row(
              children: [
                Expanded(child: Divider(color: AppTheme.outlineVariant.withValues(alpha: 0.5))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR BIOMETRIC',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppTheme.outline,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: AppTheme.outlineVariant.withValues(alpha: 0.5))),
              ],
            ),
            const SizedBox(height: 16),

            // Biometric hint
            if (_hasSavedCredentials)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.fingerprint, size: 16, color: AppTheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Biometric login available for $_savedEmail',
                        style: AppTextStyles.labelMd.copyWith(color: AppTheme.secondary),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppTheme.outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Login once with password to enable biometric access',
                        style: AppTextStyles.labelMd.copyWith(color: AppTheme.outline),
                      ),
                    ),
                  ],
                ),
              ),

            // Biometric buttons
            _buildBiometricButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.labelMd.copyWith(
        color: AppTheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRole,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, color: AppTheme.outline),
          style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurface),
          dropdownColor: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          items: _roles.map((role) {
            return DropdownMenuItem<String>(
              value: role['value'] as String,
              child: Row(
                children: [
                  Icon(role['icon'] as IconData, size: 20, color: AppTheme.outline),
                  const SizedBox(width: 12),
                  Text(role['label'] as String),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) setState(() => _selectedRole = value);
          },
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurface),
      decoration: InputDecoration(
        hintText: 'harshlimkar23@gmail.com',
        prefixIcon: const Icon(Icons.alternate_email, size: 20, color: AppTheme.outline),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Email is required';
        if (!v.contains('@')) return 'Enter a valid email';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurface),
      decoration: InputDecoration(
        hintText: '••••••••••••',
        prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppTheme.outline),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          icon: Icon(
            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
            color: AppTheme.outline,
          ),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Password is required';
        if (v.length < 6) return 'Minimum 6 characters';
        return null;
      },
    );
  }

  Widget _buildLoginButton() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: ElevatedButton(
            onPressed: isLoading ? null : _onLoginPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryContainer,
              foregroundColor: AppTheme.onPrimary,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              shadowColor: AppTheme.primary.withValues(alpha: 0.3),
            ),
            child: isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Authenticating...', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onPrimary)),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Secure Access', style: AppTextStyles.titleMd.copyWith(color: AppTheme.onPrimary)),
                      const SizedBox(width: 8),
                      const Icon(Icons.login, size: 18, color: AppTheme.onPrimary),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildBiometricButtons() {
    return Row(
      children: [
        Expanded(
          child: _BiometricButton(
            icon: Icons.fingerprint,
            label: 'Touch ID',
            enabled: _biometricAvailable,
            onTap: _biometricAvailable
                ? (_hasSavedCredentials ? _onBiometricTap : _showBiometricNotAvailable)
                : null,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _BiometricButton(
            icon: Icons.face_retouching_natural,
            label: 'Face ID',
            enabled: _biometricAvailable,
            onTap: _biometricAvailable
                ? (_hasSavedCredentials ? _onBiometricTap : _showBiometricNotAvailable)
                : null,
          ),
        ),
      ],
    );
  }

  void _showBiometricNotAvailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please log in once with your password to enable biometric login.'),
        backgroundColor: AppTheme.warningAmber,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget _buildFooter() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: AppTextStyles.bodyMd.copyWith(color: AppTheme.onSurfaceVariant),
        children: [
          const TextSpan(text: 'New to the network? '),
          TextSpan(
            text: 'Request Professional Access',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.background.withValues(alpha: 0.85),
          border: Border(top: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.3))),
        ),
        child: Row(
          children: [
            // System status
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0.4, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  builder: (ctx, val, child) => Opacity(opacity: val, child: child),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'SYSTEM NOMINAL',
                  style: AppTextStyles.codeSm.copyWith(
                    color: AppTheme.onSurfaceVariant,
                    letterSpacing: 1.0,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 1,
              height: 12,
              color: AppTheme.outlineVariant,
            ),
            Text(
              'SRV-772_NODE',
              style: AppTextStyles.codeSm.copyWith(
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            Text(
              'Trust Center',
              style: AppTextStyles.labelMd.copyWith(color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.help_outline, size: 16, color: AppTheme.outline),
          ],
        ),
      ),
    );
  }

  void _onLoginPressed() {
    if (_formKey.currentState?.validate() != true) return;
    context.read<AuthBloc>().add(AuthLoginRequested(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _selectedRole,
    ));
  }

  void _onBiometricTap() {
    context.read<AuthBloc>().add(AuthBiometricRequested(
      role: _savedRole.isNotEmpty ? _savedRole : _selectedRole,
    ));
  }
}

class _BiometricButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  const _BiometricButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled ? AppTheme.secondary.withValues(alpha: 0.5) : AppTheme.outlineVariant.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(16),
          color: enabled ? AppTheme.secondaryContainer.withValues(alpha: 0.1) : AppTheme.surfaceContainerLow,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: enabled ? AppTheme.secondary : AppTheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.labelMd.copyWith(
                color: enabled ? AppTheme.secondary : AppTheme.onSurfaceVariant,
              ),
            ),
            if (enabled) ...[
              const SizedBox(height: 2),
              Text(
                'Ready',
                style: AppTextStyles.codeSm.copyWith(color: AppTheme.secondary, fontSize: 9),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
