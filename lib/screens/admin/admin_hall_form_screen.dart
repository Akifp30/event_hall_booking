import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/hall.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common.dart';

/// Admin: create or edit a hall.
class AdminHallFormScreen extends StatefulWidget {
  final Hall? hall; // null = create new
  const AdminHallFormScreen({super.key, this.hall});

  @override
  State<AdminHallFormScreen> createState() => _AdminHallFormScreenState();
}

class _AdminHallFormScreenState extends State<AdminHallFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _location;
  late final TextEditingController _capacity;
  late final TextEditingController _price;
  late final TextEditingController _image;
  late final TextEditingController _description;
  late final TextEditingController _amenities;
  late bool _active;
  bool _busy = false;

  bool get _isEdit => widget.hall != null;

  @override
  void initState() {
    super.initState();
    final h = widget.hall;
    _name = TextEditingController(text: h?.name ?? '');
    _location = TextEditingController(text: h?.location ?? '');
    _capacity = TextEditingController(text: h == null ? '' : '${h.capacity}');
    _price = TextEditingController(text: h == null ? '' : h.basePrice.toStringAsFixed(2));
    _image = TextEditingController(text: h?.imageUrl ?? '');
    _description = TextEditingController(text: h?.description ?? '');
    _amenities = TextEditingController(text: h?.amenities.join(', ') ?? '');
    _active = h?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final c in [_name, _location, _capacity, _price, _image, _description, _amenities]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final hall = Hall(
      id: widget.hall?.id ?? '',
      name: _name.text.trim(),
      location: _location.text.trim(),
      capacity: int.parse(_capacity.text.trim()),
      basePrice: double.parse(_price.text.trim()),
      imageUrl: _image.text.trim(),
      description: _description.text.trim(),
      amenities: _amenities.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      isActive: _active,
    );
    try {
      await context.read<FirestoreService>().saveHall(hall);
      if (!mounted) return;
      showSnack(context, _isEdit ? 'Hall updated.' : 'Hall added.');
      context.pop();
    } catch (e) {
      if (mounted) showSnack(context, 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit hall' : 'Add hall')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            HallImage(url: _image.text.trim(), height: 160, radius: BorderRadius.circular(16)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Hall name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _capacity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Capacity (pax)'),
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      return (n == null || n <= 0) ? 'Enter a number > 0' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Base price (RM)'),
                    validator: (v) {
                      final n = double.tryParse(v?.trim() ?? '');
                      return (n == null || n < 0) ? 'Enter a valid price' : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _image,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Image URL', hintText: 'https://...'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amenities,
              decoration: const InputDecoration(
                labelText: 'Amenities',
                hintText: 'Projector, Wi-Fi, Parking',
                helperText: 'Separate with commas',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Visible to users'),
              subtitle: const Text('Turn off to hide this hall from the booking list'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEdit ? 'Save changes' : 'Add hall'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
