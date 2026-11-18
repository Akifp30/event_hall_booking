import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/hall.dart';
import '../../providers/booking_draft.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// Hall details: images, capacity, amenities, base price.
class HallDetailScreen extends StatefulWidget {
  final String hallId;
  const HallDetailScreen({super.key, required this.hallId});

  @override
  State<HallDetailScreen> createState() => _HallDetailScreenState();
}

class _HallDetailScreenState extends State<HallDetailScreen> {
  late final Stream<Hall?> _hall = context.read<FirestoreService>().hallStream(widget.hallId);

  void _book(Hall hall) {
    final auth = context.read<AuthService>();
    if (!auth.isLoggedIn) {
      showSnack(context, 'Please login or register to book this hall.');
      context.push('/login');
      return;
    }
    context.read<BookingDraft>().start(hall);
    context.push('/book/date');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final auth = context.watch<AuthService>();

    return StreamBuilder<Hall?>(
      stream: _hall,
      builder: (context, snap) {
        if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final hall = snap.data;
        if (hall == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.search_off, message: 'This hall is no longer available.'),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(hall.name)),
          body: ListView(
            children: [
              HallImage(url: hall.imageUrl, height: 240),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hall.name, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    IconText(icon: Icons.place_outlined, text: hall.location),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        InfoPill(icon: Icons.groups_outlined, label: 'Up to ${hall.capacity} pax'),
                        InfoPill(icon: Icons.sell_outlined, label: 'Base ${rm(hall.basePrice)}'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('About', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(hall.description.isEmpty ? '-' : hall.description, style: t.textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    Text('Amenities', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (hall.amenities.isEmpty)
                      const Text('-')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: hall.amenities
                            .map((a) => Chip(
                                  avatar: const Icon(Icons.check_circle_outline, size: 18),
                                  label: Text(a),
                                ))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: auth.isAdmin
              ? null
              : TotalBar(
                  label: 'Base price',
                  total: hall.basePrice,
                  buttonText: auth.isLoggedIn ? 'Book this hall' : 'Login to book',
                  onPressed: () => _book(hall),
                ),
        );
      },
    );
  }
}
