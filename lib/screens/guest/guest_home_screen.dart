import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/hall.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common.dart';

/// Guest homepage - featured halls, no login required.
class GuestHomeScreen extends StatefulWidget {
  const GuestHomeScreen({super.key});

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  late final Stream<List<Hall>> _halls = context.read<FirestoreService>().hallsStream(activeOnly: true);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.apartment_rounded, color: t.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('HallBook', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => context.push('/login'), child: const Text('Login')),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<Hall>>(
        stream: _halls,
        builder: (context, snap) {
          final halls = snap.data ?? const <Hall>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _Hero(),
              const SizedBox(height: 24),
              Text('Featured Halls', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (snap.hasError)
                Text('Could not load halls: ${snap.error}')
              else if (!snap.hasData)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (halls.isEmpty)
                const EmptyState(icon: Icons.meeting_room_outlined, message: 'No halls available yet.')
              else
                ...halls.take(6).map((h) => HallCard(hall: h, onTap: () => context.push('/hall/${h.id}'))),
              const SizedBox(height: 8),
              const _LoginCta(),
            ],
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [t.colorScheme.primary, t.colorScheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find the perfect venue\nfor your next event',
            style: t.textTheme.headlineSmall?.copyWith(
              color: t.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ballrooms, seminar halls and meeting rooms - book in minutes.',
            style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onPrimary.withAlpha(220)),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => context.push('/register'),
            child: const Text('Get started'),
          ),
        ],
      ),
    );
  }
}

class _LoginCta extends StatelessWidget {
  const _LoginCta();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      color: t.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.lock_open_rounded, color: t.colorScheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Login or register to make a booking.',
                style: TextStyle(color: t.colorScheme.onSecondaryContainer),
              ),
            ),
            TextButton(onPressed: () => context.push('/login'), child: const Text('Login')),
          ],
        ),
      ),
    );
  }
}
