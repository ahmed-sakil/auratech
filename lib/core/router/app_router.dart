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
import '../../features/buyer/presentation/buyer_cart_screen.dart';
import '../../features/buyer/presentation/buyer_home_screen.dart';
import '../../features/buyer/presentation/buyer_orders_screen.dart';
import '../../features/buyer/presentation/buyer_product_details_screen.dart';
import '../../features/buyer/presentation/buyer_profile_screen.dart';
import '../../features/seller/presentation/seller_dashboard_screen.dart';
import '../../features/seller/presentation/seller_onboarding_screen.dart';
import '../../features/seller/presentation/seller_pending_screen.dart';
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
        path: AppRoutes.buyerCart,
        builder: (context, state) => const BuyerCartScreen(),
      ),
      GoRoute(
        path: AppRoutes.buyerOrders,
        builder: (context, state) => const BuyerOrdersScreen(),
      ),
      GoRoute(
        path: AppRoutes.buyerProfile,
        builder: (context, state) => const BuyerProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.buyerProductDetails,
        builder: (context, state) {
          final product = state.extra as Map<String, dynamic>;
          return BuyerProductDetailsScreen(product: product);
        },
      ),
      GoRoute(
        path: AppRoutes.sellerPending,
        builder: (context, state) => const SellerPendingScreen(),
      ),
      GoRoute(
        path: AppRoutes.sellerOnboarding,
        builder: (context, state) => const SellerOnboardingScreen(),
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

  final profile = session.profile!;
  final role = profile.role;
  final status = profile.status;

  switch (role) {
    case AppRole.buyer:
      final allowedBuyerRoutes = {
        AppRoutes.buyerHome,
        AppRoutes.buyerCart,
        AppRoutes.buyerOrders,
        AppRoutes.buyerProfile,
        AppRoutes.buyerProductDetails,
      };
      return allowedBuyerRoutes.contains(location) ? null : AppRoutes.buyerHome;

    case AppRole.seller:
      if (status == ProfileStatus.pending) {
        final allowedPendingRoutes = {
          AppRoutes.sellerPending,
          AppRoutes.sellerOnboarding,
        };
        return allowedPendingRoutes.contains(location)
            ? null
            : AppRoutes.sellerPending;
      }

      if (status == ProfileStatus.active) {
        return location == AppRoutes.sellerDashboard
            ? null
            : AppRoutes.sellerDashboard;
      }

      return location == AppRoutes.login ? null : AppRoutes.login;

    case AppRole.admin:
      return location == AppRoutes.adminDashboard
          ? null
          : AppRoutes.adminDashboard;
  }
}