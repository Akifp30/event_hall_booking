import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/hall.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common.dart';
import '../notifications_screen.dart';

/// User home: list of halls with search, capacity filter and sorting.
class HallListScreen extends StatefulWidget {
  const HallListScreen({super.key});

  @override
  State<HallListScreen> createState() => _HallListScreenState();
}

class _HallListScreenState extends State<HallListScreen> {
  late final Stream<List<Hall>> _halls = context.read<FirestoreService>().hallsStream(activeOnly: true);

  static const _capacities = ['Any', 'Up to 100', '101 - 300', '300+'];
  static const _sorts = ['Name', 'Price: low to high', 'Price: high to low', 'Capacity'];

  String _query = '';
  String _capacity = 'Any';
  String _sort = 'Name';

  List<Hall> _apply(List<Hall> all) {
    final q = _query.trim().toLowerCase();
    final list = all.where((h) {
      final matchesText = q.isEmpty ||
          h.name.toLowerCase().contains(q) ||
          h.location.toLowerCase().contains(q) ||
          h.amenities.any((a) => a.toLowerCase().contains(q));
      final matchesCapacity = switch (_capacity) {
        'Up to 100' => h.capacity <= 100,
        '101 - 300' => h.capacity > 100 && h.capacity <= 300,
        '300+' => h.capacity > 300,
        _ => true,
      };
      return matchesText && matchesCapacity;
    }).toList();

    switch (_sort) {
      case 'Price: low to high':
        list.sort((a, b) => a.basePrice.compareTo(b.basePrice));
      case 'Price: high to low':
        list.sort((a, b) => b.basePrice.compareTo(a.basePrice));
      case 'Capacity':
        list.sort((a, b) => b.capacity.compareTo(a.capacity));
      default:
        list.sort((a, b) => a.name.compareTo(b.name));
    }
    return list;
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(context, title: 'Logout?', message: 'You will need to login again to book.', confirmText: 'Logout');
    if (!ok || !mounted) return;
    await context.read<AuthService>().logout();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final user = context.watch<AuthService>().user;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hi, ${user?.name ?? ''}', style: t.textTheme.labelLarge),
            const Text('Find a hall', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: 'My Bookings',
            icon: const Icon(Icons.event_note_outlined),
            onPressed: () => context.push('/my-bookings'),
          ),
          IconButton(tooltip: 'Logout', icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name, location or amenity',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final c in _capacities)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(c == 'Any' ? 'Any size' : c),
                      selected: _capacity == c,
                      onSelected: (_) => setState(() => _capacity = c),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: Row(
              children: [
                Text('Sort by', style: t.textTheme.labelLarge),
                const Spacer(),
                DropdownButton<String>(
                  value: _sort,
                  underline: const SizedBox.shrink(),
                  items: _sorts.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _sort = v ?? _sort),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Hall>>(
              stream: _halls,
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final halls = _apply(snap.data!);
                if (halls.isEmpty) {
                  return const EmptyState(icon: Icons.search_off, message: 'No halls match your search.');
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: halls.length,
                  itemBuilder: (context, i) => HallCard(
                    hall: halls[i],
                    onTap: () => context.push('/hall/${halls[i].id}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
