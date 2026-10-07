import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_language.dart';
import '../theme/app_colors.dart';
import '../widgets/gh_ui.dart';
import '../services/api_client.dart';
import '../utils/auth_guard.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameCtrl     = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  final _addressCtrl  = TextEditingController();

  bool _isRegistering = false;
  bool _isLoading     = false;
  String _selectedRole = 'patient';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.emergency,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  void _navigateByRole(String role) {
    AuthGuard.onLogin(role);
    switch (role.toLowerCase()) {
      case 'admin':
        context.go('/admin/dashboard');
        break;
      case 'doctor':
        context.go('/doctor/requests');
        break;
      case 'pharmacy':
        context.go('/pharmacy/dashboard');
        break;
      default:
        context.go('/main/home');
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter your email and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await AuthService.login(email, password);
      final role = (user['role'] as String? ?? 'PATIENT').toLowerCase();
      _navigateByRole(role);
    } on ApiException catch (e) {
      if (e.statusCode == 401 || (e.statusCode == 400 && e.message.toLowerCase().contains('invalid'))) {
        _showError('Invalid email or password.');
      } else if (e.statusCode == 503) {
        _showError('Backend unreachable. Please verify network connection or ADB reverse.');
      } else if (e.statusCode == 504) {
        _showError('Connection timed out. Backend is not responding.');
      } else {
        _showError(e.message);
      }
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('connection refused') ||
          errStr.contains('failed to fetch')) {
        _showError('Backend unreachable. Please verify network connection or ADB reverse.');
      } else {
        _showError('Login failed: ${e.toString().replaceAll("Exception: ", "")}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────

  Future<void> _handleRegister() async {
    final name     = _nameCtrl.text.trim();
    final phone    = _phoneCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm  = _confirmCtrl.text;

    if (name.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty) {
      _showError('Please fill in all required fields.');
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showError('Please enter a valid email address.');
      return;
    }
    if (password.length < 8) {
      _showError('Password must be at least 8 characters.');
      return;
    }
    if (password != confirm) {
      _showError('Passwords do not match.');
      return;
    }
    
    String? address;
    double? latitude;
    double? longitude;

    if (_selectedRole == 'pharmacy') {
      address = _addressCtrl.text.trim();
      if (address.isEmpty) {
        _showError('Please enter the pharmacy address.');
        return;
      }
      
      setState(() => _isLoading = true);
      try {
        List<geocoding.Location> locations = await geocoding.Geocoding().locationFromAddress(address);
        if (locations.isNotEmpty) {
          latitude = locations.first.latitude;
          longitude = locations.first.longitude;
        }
      } catch (e) {
        setState(() => _isLoading = false);
        _showError('Could not find location from address. Please try a different address.');
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
        role: _selectedRole,
        address: address,
        latitude: latitude,
        longitude: longitude,
      );
      // After registration, log in automatically
      final user = await AuthService.login(email, password);
      final role = (user['role'] as String? ?? 'PATIENT').toLowerCase();
      if (role == 'doctor') {
        // Send new doctors to the onboarding screen to fill professional details
        if (mounted) {
          AuthGuard.onLogin(role);
          context.go('/doctor/onboarding');
        }
      } else {
        _navigateByRole(role);
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Network error. Please check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleContinue() {
    if (_isRegistering) {
      _handleRegister();
    } else {
      _handleLogin();
    }
  }

  void _submitFromKeyboard() {
    if (!_isLoading) _handleContinue();
  }

  void _toggleMode() {
    FocusScope.of(context).unfocus();
    setState(() => _isRegistering = !_isRegistering);
  }

  // ── Role Card ─────────────────────────────────────────────────────────────

  Widget _buildRoleCard(String role, IconData icon, String title) {
    final isSelected = _selectedRole == role;
    final radius = BorderRadius.circular(GhTokens.radiusSm);
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        child: Material(
          color: isSelected ? AppColors.leafGreenPale : GhTokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color:
                  isSelected ? AppColors.leafGreenPrimary : GhTokens.border,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: () => setState(() => _selectedRole = role),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isSelected
                        ? AppColors.leafGreenPrimary
                        : AppColors.textMedium,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded,
                        size: 18, color: AppColors.leafGreenPrimary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondaryBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 960;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isWide) const Expanded(flex: 5, child: _BrandPanel()),
              Expanded(flex: 6, child: _buildFormArea(isWide)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFormArea(bool isWide) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                if (!isWide) ...[
                  const GhLogoMark(size: 36),
                  const SizedBox(width: 10),
                  const Text(
                    'RuralCare',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
                const Spacer(),
                const GhLanguageChip(),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AutofillGroup(child: _buildForm()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _isRegistering
              ? context.tr('create_account')
              : context.tr('welcome_back'),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            letterSpacing: -0.6,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isRegistering
              ? context.tr('register_desc')
              : context.tr('signin_desc'),
          style: const TextStyle(
            fontSize: 15,
            height: 1.45,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: GhTokens.surface,
            borderRadius: BorderRadius.circular(GhTokens.radiusLg),
            border: Border.all(color: GhTokens.border),
            boxShadow: GhTokens.shadowSm,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isRegistering) ...[
                  const Text(
                    'Select your role',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMedium,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildRoleCard('patient', Icons.person_outline, 'User'),
                      const SizedBox(width: 10),
                      _buildRoleCard('doctor',
                          Icons.local_hospital_outlined, 'Doctor'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildRoleCard('admin',
                          Icons.admin_panel_settings_outlined, 'Admin'),
                      const SizedBox(width: 10),
                      _buildRoleCard('pharmacy',
                          Icons.local_pharmacy_outlined, 'Pharmacy'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GhTextField(
                    key: const ValueKey('field_name'),
                    label: 'Full Name',
                    hint: 'Enter your full name',
                    controller: _nameCtrl,
                    icon: Icons.person_outline_rounded,
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                  ),
                  GhTextField(
                    key: const ValueKey('field_phone'),
                    label: 'Phone',
                    hint: 'Enter your phone number',
                    controller: _phoneCtrl,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                  ),
                  if (_selectedRole == 'pharmacy')
                    GhTextField(
                      key: const ValueKey('field_address'),
                      label: 'Pharmacy Address',
                      hint: 'Street, City',
                      helperText:
                          'Used to place your pharmacy on the map for patients.',
                      controller: _addressCtrl,
                      icon: Icons.location_on_outlined,
                      keyboardType: TextInputType.streetAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.fullStreetAddress],
                    ),
                ],
                GhTextField(
                  key: const ValueKey('field_email'),
                  label: _isRegistering ? 'Email' : 'Email or Phone',
                  hint: _isRegistering
                      ? 'Enter your email address'
                      : 'Enter your email or phone',
                  controller: _emailCtrl,
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                ),
                GhTextField(
                  key: const ValueKey('field_password'),
                  label: context.tr('password'),
                  hint: context.tr('enter_password'),
                  helperText:
                      _isRegistering ? 'Use at least 8 characters.' : null,
                  controller: _passwordCtrl,
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  textInputAction: _isRegistering
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onSubmitted:
                      _isRegistering ? null : (_) => _submitFromKeyboard(),
                  autofillHints: [
                    _isRegistering
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                ),
                if (_isRegistering)
                  GhTextField(
                    key: const ValueKey('field_confirm'),
                    label: context.tr('confirm_password'),
                    hint: context.tr('repeat_password'),
                    controller: _confirmCtrl,
                    icon: Icons.lock_outline_rounded,
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submitFromKeyboard(),
                    autofillHints: const [AutofillHints.newPassword],
                  ),
                const SizedBox(height: 8),
                GhPrimaryButton(
                  label: _isRegistering
                      ? context.tr('register_btn')
                      : context.tr('continue_btn'),
                  onPressed: _handleContinue,
                  loading: _isLoading,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _isLoading ? null : _toggleMode,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.leafGreenPrimary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            child: Text(
              _isRegistering
                  ? context.tr('already_have_account')
                  : context.tr('register_new_account'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  Widget _feature(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(GhTokens.radiusSm),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, size: 20, color: AppColors.leafGreenAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.leafGradientHero),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  GhLogoMark(size: 40),
                  SizedBox(width: 12),
                  Text(
                    'RuralCare',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: const Text(
                  'Smart Healthcare for Rural Communities',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _feature(Icons.monitor_heart_outlined,
                  context.tr('service_consult')),
              _feature(Icons.search_rounded, context.tr('service_symptoms')),
              _feature(Icons.local_pharmacy_outlined,
                  context.tr('service_medicine')),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

