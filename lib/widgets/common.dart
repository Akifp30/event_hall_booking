import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../models/hall.dart';
import '../utils/format.dart';

/// Network image with caching, loading placeholder and error fallback.
class HallImage extends StatelessWidget {
  final String url;
  final double height;
  final double? width;
  final BorderRadius? radius;

  const HallImage({super.key, required this.url, this.height = 160, this.width, this.radius});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      height: height,
      width: width ?? double.infinity,
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Icon(Icons.meeting_room_outlined, size: height / 3, color: scheme.onPrimaryContainer),
    );
    final Widget img = url.isEmpty
        ? placeholder
        : CachedNetworkImage(
            imageUrl: url,
            height: height,
            width: width ?? double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: height,
              width: width ?? double.infinity,
              color: scheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) => placeholder,
          );
    return radius == null ? img : ClipRRect(borderRadius: radius!, child: img);
  }
}

/// Hall card used on the guest page and the user hall list.
class HallCard extends StatelessWidget {
  final Hall hall;
  final VoidCallback onTap;

  const HallCard({super.key, required this.hall, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HallImage(url: hall.imageUrl, height: 160),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hall.name, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  IconText(icon: Icons.place_outlined, text: hall.location),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      InfoPill(icon: Icons.groups_outlined, label: '${hall.capacity} pax'),
                      const Spacer(),
                      Text(
                        'From ${rm(hall.basePrice)}',
                        style: t.textTheme.titleSmall?.copyWith(
                          color: t.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IconText extends StatelessWidget {
  final IconData icon;
  final String text;
  const IconText({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: t.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const InfoPill({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.onSecondaryContainer),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: scheme.onSecondaryContainer, fontSize: 13)),
        ],
      ),
    );
  }
}

/// "Step 1 of 3" header for the booking flow.
class StepHeader extends StatelessWidget {
  final int step;
  final String title;
  const StepHeader({super.key, required this.step, required this.title});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step $step of 3', style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.primary)),
          const SizedBox(height: 4),
          Text(title, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: step / 3, minHeight: 6),
          ),
        ],
      ),
    );
  }
}

/// Bottom bar showing a (live) total and an action button.
class TotalBar extends StatelessWidget {
  final String label;
  final double total;
  final String buttonText;
  final VoidCallback? onPressed;
  final bool busy;

  const TotalBar({
    super.key,
    required this.label,
    required this.total,
    required this.buttonText,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Material(
      elevation: 8,
      color: t.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: t.textTheme.labelMedium),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                      child: Text(
                        rm(total),
                        key: ValueKey(total),
                        style: t.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: t.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: busy ? null : onPressed,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                ),
                child: busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(buttonText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Booking card used in "My Bookings" and admin "Manage Bookings".
class BookingCard extends StatelessWidget {
  final Booking booking;
  final bool showUser;
  final List<Widget> actions;

  const BookingCard({super.key, required this.booking, this.showUser = false, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final b = booking;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    b.hallName,
                    style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                StatusChip(booking: b),
              ],
            ),
            const SizedBox(height: 8),
            IconText(icon: Icons.calendar_today_outlined, text: prettyDate(b.date)),
            const SizedBox(height: 4),
            IconText(icon: Icons.schedule, text: b.timeSlot),
            if (showUser) ...[
              const SizedBox(height: 4),
              IconText(icon: Icons.person_outline, text: '${b.userName}  •  ${b.userEmail}'),
            ],
            if (b.addons.isNotEmpty) ...[
              const SizedBox(height: 4),
              IconText(icon: Icons.add_box_outlined, text: b.addons.map((a) => a.name).join(', ')),
            ],
            const SizedBox(height: 4),
            IconText(icon: Icons.payments_outlined, text: rm(b.totalPrice)),
            if (actions.isNotEmpty)
              Row(mainAxisAlignment: MainAxisAlignment.end, children: actions)
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final Booking booking;
  const StatusChip({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color bg;
    final Color fg;
    if (booking.isCancelled) {
      bg = scheme.errorContainer;
      fg = scheme.onErrorContainer;
    } else if (booking.isUpcoming) {
      bg = scheme.primaryContainer;
      fg = scheme.onPrimaryContainer;
    } else {
      bg = scheme.surfaceContainerHighest;
      fg = scheme.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(booking.statusLabel, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Simple empty-state message.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: t.colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: t.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

/// Yes/No confirmation dialog. Returns true when confirmed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          FilledButton(
            style: destructive ? FilledButton.styleFrom(backgroundColor: scheme.error) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}
