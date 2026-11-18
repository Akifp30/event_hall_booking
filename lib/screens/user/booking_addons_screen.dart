import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/addon.dart';
import '../../providers/booking_draft.dart';
import '../../services/firestore_service.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// Step 2: choose add-on services. The total price updates in real time.
class BookingAddonsScreen extends StatefulWidget {
  const BookingAddonsScreen({super.key});

  @override
  State<BookingAddonsScreen> createState() => _BookingAddonsScreenState();
}

class _BookingAddonsScreenState extends State<BookingAddonsScreen> {
  late final Stream<List<Addon>> _addons = context.read<FirestoreService>().addonsStream();

  IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('cater')) return Icons.restaurant_outlined;
    if (n.contains('av') || n.contains('audio')) return Icons.speaker_outlined;
    if (n.contains('decor')) return Icons.local_florist_outlined;
    if (n.contains('photo')) return Icons.photo_camera_outlined;
    if (n.contains('stream')) return Icons.videocam_outlined;
    if (n.contains('clean')) return Icons.cleaning_services_outlined;
    return Icons.add_box_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final draft = context.watch<BookingDraft>();

    if (draft.hall == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.info_outline, message: 'Please choose a hall first.'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(draft.isEditing ? 'Edit booking' : 'New booking')),
      body: StreamBuilder<List<Addon>>(
        stream: _addons,
        builder: (context, snap) {
          final addons = snap.data ?? const <Addon>[];
          return ListView(
            children: [
              const StepHeader(step: 2, title: 'Add-on services'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Optional extras for your event. Tap to add or remove.', style: t.textTheme.bodyMedium),
              ),
              const SizedBox(height: 12),
              if (!snap.hasData)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else if (addons.isEmpty)
                const EmptyState(icon: Icons.inventory_2_outlined, message: 'No add-on services available.')
              else
                ...addons.map((a) {
                  final selected = draft.isSelected(a);
                  return Card(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    color: selected ? t.colorScheme.primaryContainer : null,
                    child: CheckboxListTile(
                      value: selected,
                      onChanged: (_) => draft.toggleAddon(a),
                      secondary: Icon(_iconFor(a.name), color: t.colorScheme.primary),
                      title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${a.description}\n${rm(a.price)}'),
                      isThreeLine: true,
                    ),
                  );
                }),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _row('Hall base price', rm(draft.hall!.basePrice)),
                    _row('Add-ons (${draft.addons.length})', rm(draft.addonsTotal)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: TotalBar(
        label: 'Running total',
        total: draft.total,
        buttonText: 'Review',
        onPressed: () => context.push('/book/summary'),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [Text(label), const Spacer(), Text(value)]),
      );
}
