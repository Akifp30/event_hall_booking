import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/booking.dart';
import '../../services/firestore_service.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// Demo payment page (FPX online banking, card, e-wallet).
/// Simulates a payment gateway: no real money is charged and
/// no card or bank details are collected.
class PaymentScreen extends StatefulWidget {
  final String bookingId;
  const PaymentScreen({super.key, required this.bookingId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final Stream<Booking?> _booking = context.read<FirestoreService>().bookingStream(widget.bookingId);

  static const _banks = ['Maybank2u', 'CIMB Clicks', 'Public Bank', 'RHB Now', 'Bank Islam', 'Bank Rakyat'];
  static const _wallets = ["Touch 'n Go eWallet", 'GrabPay', 'ShopeePay'];

  String _method = 'fpx';
  String _bank = _banks.first;
  String _wallet = _wallets.first;
  bool _busy = false;

  String get _methodLabel => switch (_method) {
    'fpx' => 'FPX ($_bank)',
    'card' => 'Credit/Debit Card',
    _ => _wallet,
  };

  void _leave() => context.go('/my-bookings');

  Future<void> _pay(Booking b) async {
    final db = context.read<FirestoreService>();
    final amount = b.balance;
    final method = _methodLabel;
    setState(() => _busy = true);

    // "Processing" dialog to mimic a payment gateway.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            SizedBox(width: 20),
            Expanded(child: Text('Processing payment...')),
          ],
        ),
      ),
    );

    try {
      await Future<void>.delayed(const Duration(seconds: 2));
      final txn = await db.recordPayment(b, method: method, amount: amount);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // close processing dialog

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.verified, color: Colors.green, size: 56),
          title: const Text('Payment successful'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _receiptRow('Amount', rm(amount)),
              _receiptRow('Method', method),
              _receiptRow('Hall', b.hallName),
              _receiptRow('Date', prettyDate(b.date)),
              _receiptRow('Reference', txn),
            ],
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        ),
      );
      if (mounted) _leave();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      showSnack(context, 'Payment failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _receiptRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(child: Text(value)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return StreamBuilder<Booking?>(
      stream: _booking,
      builder: (context, snap) {
        if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final b = snap.data;
        final appBar = AppBar(
          title: const Text('Payment'),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: _busy ? null : _leave),
        );

        if (b == null || !b.needsPayment) {
          return Scaffold(
            appBar: appBar,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmptyState(icon: Icons.task_alt, message: 'Nothing to pay for this booking.'),
                  FilledButton(onPressed: _leave, child: const Text('Back to my bookings')),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: appBar,
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.hallName, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      IconText(icon: Icons.calendar_today_outlined, text: prettyDate(b.date)),
                      const SizedBox(height: 4),
                      IconText(icon: Icons.schedule, text: b.timeSlot),
                      const Divider(height: 24),
                      _amountRow('Booking total', b.totalPrice),
                      if (b.amountPaid > 0) _amountRow('Already paid', -b.amountPaid),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('Amount due', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text(
                            rm(b.balance),
                            style: t.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: t.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Payment method', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _methodTile('fpx', Icons.account_balance_outlined, 'Online Banking (FPX)', 'Pay directly from your bank account'),
              if (_method == 'fpx')
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: _bank,
                    decoration: const InputDecoration(labelText: 'Select your bank'),
                    items: _banks.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                    onChanged: (v) => setState(() => _bank = v ?? _bank),
                  ),
                ),
              _methodTile('card', Icons.credit_card, 'Credit / Debit Card', 'Visa, Mastercard'),
              _methodTile('ewallet', Icons.account_balance_wallet_outlined, 'E-wallet', "Touch 'n Go, GrabPay, ShopeePay"),
              if (_method == 'ewallet')
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Wrap(
                    spacing: 8,
                    children: _wallets
                        .map((w) => ChoiceChip(
                      label: Text(w),
                      selected: _wallet == w,
                      onSelected: (_) => setState(() => _wallet = w),
                    ))
                        .toList(),
                  ),
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: t.colorScheme.onTertiaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Demo payment for this project: no real money is charged and no card or bank details are collected.',
                        style: TextStyle(color: t.colorScheme.onTertiaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: TextButton(onPressed: _busy ? null : _leave, child: const Text('Pay later')),
              ),
            ],
          ),
          bottomNavigationBar: TotalBar(
            label: 'Amount to pay',
            total: b.balance,
            buttonText: 'Pay now',
            busy: _busy,
            onPressed: () => _pay(b),
          ),
        );
      },
    );
  }

  Widget _amountRow(String label, double value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [Text(label), const Spacer(), Text(value < 0 ? '- ${rm(-value)}' : rm(value))]),
  );

  Widget _methodTile(String value, IconData icon, String title, String subtitle) {
    final t = Theme.of(context);
    final selected = _method == value;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? t.colorScheme.primaryContainer : null,
      child: ListTile(
        leading: Icon(icon, color: t.colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: t.colorScheme.primary),
        onTap: () => setState(() => _method = value),
      ),
    );
  }
}