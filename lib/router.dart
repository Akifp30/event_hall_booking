import 'package:go_router/go_router.dart';

import 'models/hall.dart';
import 'screens/admin/admin_bookings_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_hall_form_screen.dart';
import 'screens/admin/admin_halls_screen.dart';
import 'screens/admin/admin_users_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/guest/guest_home_screen.dart';
import 'screens/guest/hall_detail_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/user/booking_addons_screen.dart';
import 'screens/user/booking_date_screen.dart';
import 'screens/user/booking_summary_screen.dart';
import 'screens/user/hall_list_screen.dart';
import 'screens/user/my_bookings_screen.dart';
import 'screens/user/payment_screen.dart';
import 'services/auth_service.dart';

/// All app routes + role-based access control.
GoRouter createRouter(AuthService auth) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth, // re-run redirect when login state changes
    redirect: (context, state) {
      if (auth.isLoading) return null;

      final loc = state.matchedLocation;
      final loggedIn = auth.isLoggedIn;
      final onAuthPage = loc == '/login' || loc == '/register';
      final needsLogin = loc.startsWith('/home') ||
          loc.startsWith('/book') ||
          loc.startsWith('/my-bookings') ||
          loc.startsWith('/notifications') ||
          loc.startsWith('/pay') ||
          loc.startsWith('/admin');

      if (!loggedIn && needsLogin) return '/login';
      if (loggedIn && (onAuthPage || loc == '/')) return auth.isAdmin ? '/admin' : '/home';
      if (loggedIn && loc.startsWith('/admin') && !auth.isAdmin) return '/home';
      if (loggedIn && auth.isAdmin && (loc.startsWith('/book') || loc.startsWith('/home') || loc.startsWith('/pay'))) {
        return '/admin';
      }
      return null;
    },
    routes: [
      // Guest (no login needed)
      GoRoute(path: '/', builder: (context, state) => const GuestHomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/hall/:id',
        builder: (context, state) => HallDetailScreen(hallId: state.pathParameters['id']!),
      ),

      // User
      GoRoute(path: '/home', builder: (context, state) => const HallListScreen()),
      GoRoute(path: '/book/date', builder: (context, state) => const BookingDateScreen()),
      GoRoute(path: '/book/addons', builder: (context, state) => const BookingAddonsScreen()),
      GoRoute(path: '/book/summary', builder: (context, state) => const BookingSummaryScreen()),
      GoRoute(path: '/my-bookings', builder: (context, state) => const MyBookingsScreen()),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(
        path: '/pay/:id',
        builder: (context, state) => PaymentScreen(bookingId: state.pathParameters['id']!),
      ),

      // Admin
      GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardScreen()),
      GoRoute(path: '/admin/halls', builder: (context, state) => const AdminHallsScreen()),
      GoRoute(
        path: '/admin/halls/form',
        builder: (context, state) => AdminHallFormScreen(hall: state.extra as Hall?),
      ),
      GoRoute(path: '/admin/users', builder: (context, state) => const AdminUsersScreen()),
      GoRoute(path: '/admin/bookings', builder: (context, state) => const AdminBookingsScreen()),
    ],
  );
}