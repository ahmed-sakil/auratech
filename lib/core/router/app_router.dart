import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_enums.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/reset_password_otp_screen.dart';
import '../../features/auth/presentation/signup_buyer_screen.dart';
import '../../features/auth/presentation/signup_seller_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/verify_email_otp_screen.dart';
import '../../features/buyer/presentation/buyer_home_screen.dart';
import '../../features/seller/presentation/seller_dashboard_screen.dart';
import '../auth/app_session.dart';
import '../auth/app_session_provider.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final sessionAsync = ref.watch(appSessionProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signupBuyer,
        builder: (context, state) => const SignupBuyerScreen(),
      ),
      GoRoute(
        path: AppRoutes.signupSeller,
        builder: (context, state) => const SignupSellerScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmailOtp,
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return VerifyEmailOtpScreen(email: email);
        },
      ),
      GoRoute(
        path: AppRoutes.resetPasswordOtp,
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return ResetPasswordOtpScreen(email: email);
        },
      ),
      GoRoute(
        path: AppRoutes.buyerHome,
        builder: (context, state) => const BuyerHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.sellerDashboard,
        builder: (context, state) => const SellerDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
    ],
    redirect: (context, state) {
      return sessionAsync.when(
        loading: () => state.matchedLocation == AppRoutes.splash
            ? null
            : AppRoutes.splash,
        error: (_, __) =>
            _redirect(const AppSession.unauthenticated(), state.matchedLocation),
        data: (session) => _redirect(session, state.matchedLocation),
      );
    },
  );
});

String? _redirect(AppSession session, String location) {
  final publicRoutes = {
    AppRoutes.login,
    AppRoutes.signupBuyer,
    AppRoutes.signupSeller,
    AppRoutes.forgotPassword,
    AppRoutes.verifyEmailOtp,
    AppRoutes.resetPasswordOtp,
  };

  if (session.isLoading) {
    return location == AppRoutes.splash ? null : AppRoutes.splash;
  }

  if (!session.isAuthenticated) {
    return publicRoutes.contains(location) ? null : AppRoutes.login;
  }

  final role = session.profile!.role;

  switch (role) {
    case AppRole.buyer:
      return location == AppRoutes.buyerHome ? null : AppRoutes.buyerHome;
    case AppRole.seller:
      return location == AppRoutes.sellerDashboard
          ? null
          : AppRoutes.sellerDashboard;
    case AppRole.admin:
      return location == AppRoutes.adminDashboard
          ? null
          : AppRoutes.adminDashboard;
  }
}