import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common.dart';

/// Admin: manage user accounts (role + enable/disable).
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late final Stream<List<AppUser>> _users = context.read<FirestoreService>().usersStream();
  String _query = '';
  String _filter = 'All';

  Future<void> _update(AppUser u, Map<String, dynamic> data, String done) async {
    try {
      await context.read<FirestoreService>().updateUser(u.uid, data);
      if (mounted) showSnack(context, done);
    } catch (e) {
      if (mounted) showSnack(context, 'Failed: $e');
    }
  }

  Future<void> _toggleRole(AppUser u) async {
    final newRole = u.isAdmin ? 'user' : 'admin';
    final ok = await confirmDialog(
      context,
      title: 'Change role?',
      message: 'Make ${u.name} ${newRole == 'admin' ? 'an admin' : 'a normal user'}?',
    );
    if (ok && mounted) await _update(u, {'role': newRole}, '${u.name} is now $newRole.');
  }

  Future<void> _toggleActive(AppUser u) async {
    final ok = await confirmDialog(
      context,
      title: u.isActive ? 'Disable account?' : 'Enable account?',
      message: u.isActive
          ? '${u.name} will not be able to login until enabled again.'
          : '${u.name} will be able to login again.',
      destructive: u.isActive,
      confirmText: u.isActive ? 'Disable' : 'Enable',
    );
    if (ok && mounted) await _update(u, {'isActive': !u.isActive}, u.isActive ? 'Account disabled.' : 'Account enabled.');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final me = context.watch<AuthService>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('User Accounts')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search name or email', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                for (final f in ['All', 'Users', 'Admins', 'Disabled'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: _users,
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final users = snap.data!.where((u) {
                  final matchQ = _query.isEmpty || u.name.toLowerCase().contains(_query) || u.email.toLowerCase().contains(_query);
                  final matchF = switch (_filter) {
                    'Users' => !u.isAdmin,
                    'Admins' => u.isAdmin,
                    'Disabled' => !u.isActive,
                    _ => true,
                  };
                  return matchQ && matchF;
                }).toList();
                if (users.isEmpty) return const EmptyState(icon: Icons.person_search_outlined, message: 'No users found.');

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: users.length,
                  itemBuilder: (context, i) {
                    final u = users[i];
                    final isMe = u.uid == me?.uid;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: u.isAdmin ? t.colorScheme.tertiaryContainer : t.colorScheme.secondaryContainer,
                          child: Text(u.name.isEmpty ? '?' : u.name[0].toUpperCase()),
                        ),
                        title: Text(
                          '${u.name}${isMe ? ' (you)' : ''}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: u.isActive ? null : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Text(
                          '${u.email}\n${u.isAdmin ? 'Admin' : 'User'}'
                          '${u.phone.isEmpty ? '' : '  •  ${u.phone}'}'
                          '${u.isActive ? '' : '  •  DISABLED'}',
                        ),
                        isThreeLine: true,
                        trailing: isMe
                            ? null
                            : PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'role') _toggleRole(u);
                                  if (v == 'active') _toggleActive(u);
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(value: 'role', child: Text(u.isAdmin ? 'Make user' : 'Make admin')),
                                  PopupMenuItem(value: 'active', child: Text(u.isActive ? 'Disable account' : 'Enable account')),
                                ],
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
