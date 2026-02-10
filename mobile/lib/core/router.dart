import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/ar_claim/presentation/ar_camera_screen.dart';
import '../features/rewards/presentation/rewards_screen.dart';
import '../features/profile/presentation/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // Wait for auth state to load before making decisions
      if (authState.isLoading) {
        return null; // Don't redirect while loading
      }

      final isLoggedIn = authState.value != null;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/';
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'map',
            builder: (context, state) => const MapScreen(),
          ),
          GoRoute(
            path: '/rewards',
            name: 'rewards',
            builder: (context, state) => const RewardsScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/ar-claim',
        name: 'ar-claim',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ARCameraScreen(
            locationId: extra['locationId'] as String,
            locationName: extra['locationName'] as String,
            rewardBearing: extra['rewardBearing'] as double? ?? 45.0,
            rewardElevation: extra['rewardElevation'] as double? ?? 0.0,
            distanceM: extra['distanceM'] as double? ?? 1000.0,
            rewardType: extra['rewardType'] as String? ?? 'points',
          );
        },
      ),
    ],
  );
});
