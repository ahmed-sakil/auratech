import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_routes.dart';

class ResetPasswordOtpScreen extends StatefulWidget {
  final String email;

  const ResetPasswordOtpScreen({
    super.key,
    required this.email,
  });

  @override
  State<ResetPasswordOtpScreen> createState() =>
      _ResetPasswordOtpScreenState();
}

class _ResetPasswordOtpScreenState extends State<ResetPasswordOtpScreen> {
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _isSubmitting = false;
  bool _isResending = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final token = _otpController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    if (token.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 8-digit code')),
      );
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New password must be at least 6 characters'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: token,
        type: OtpType.recovery,
      );

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successful. Please login.'),
        ),
      );

      context.go(AppRoutes.login);
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset failed')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isResending = true;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(widget.email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset code resent')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not resend reset code')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isResending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.login),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          height: 64,
                          width: 64,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.lock_reset_outlined,
                            color: AppColors.white,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Reset Password',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Enter the reset code sent to ${widget.email}, then choose a new password.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 8,
                        decoration: const InputDecoration(
                          labelText: 'Reset code',
                          hintText: 'Enter 8-digit code',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _newPasswordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'New password',
                          hintText: 'Enter new password',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _resetPassword,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : const Text('Update Password'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isResending ? null : _resendCode,
                          child: _isResending
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Resend Code'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: TextButton(
                          onPressed: () => context.go(AppRoutes.login),
                          child: const Text('Back to Login'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}