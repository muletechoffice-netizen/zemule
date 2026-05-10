import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('User Management', style: Theme.of(context).textTheme.titleLarge),
                  if (_busy) ...<Widget>[
                    const SizedBox(width: 12),
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('users').snapshots(),
                  builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Failed to load users: ${snapshot.error}'));
                    }

                    final docs = snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    if (docs.isEmpty) {
                      return const Center(child: Text('No users found.'));
                    }

                    return DataTable2(
                      columnSpacing: 12,
                      minWidth: 1000,
                      columns: const <DataColumn2>[
                        DataColumn2(label: Text('User ID'), size: ColumnSize.L),
                        DataColumn2(label: Text('Name')),
                        DataColumn2(label: Text('Phone')),
                        DataColumn2(label: Text('Role')),
                        DataColumn2(label: Text('Business')),
                        DataColumn2(label: Text('Created')),
                        DataColumn2(label: Text('Actions'), size: ColumnSize.L),
                      ],
                      rows: docs.map((doc) {
                        final data = doc.data();
                        final isOwner = data['isBusinessOwner'] == true;
                        return DataRow2(cells: <DataCell>[
                          DataCell(Text(doc.id)),
                          DataCell(Text(_string(data['name'], fallback: '-'))),
                          DataCell(Text(_string(data['phone'], fallback: '-'))),
                          DataCell(Text(isOwner ? 'Business Owner' : 'User')),
                          DataCell(Text(_string(data['businessName'], fallback: '-'))),
                          DataCell(Text(_formatDate(data['createdAt']))),
                          DataCell(
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                FilledButton.tonal(
                                  onPressed: _busy
                                      ? null
                                      : () => _setBusinessOwner(
                                            doc.id,
                                            value: !isOwner,
                                          ),
                                  child: Text(isOwner ? 'Set as User' : 'Set as Owner'),
                                ),
                                IconButton(
                                  tooltip: 'Delete user',
                                  onPressed: _busy ? null : () => _deleteUser(doc.id),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        ]);
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setBusinessOwner(String userId, {required bool value}) async {
    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set(
        <String, dynamic>{
          'isBusinessOwner': value,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteUser(String userId) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Delete user?'),
            content: const Text('This removes the user document from Firestore.'),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) {
      return;
    }

    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _string(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _formatDate(dynamic raw) {
    if (raw is! Timestamp) {
      return '-';
    }
    return DateFormat('MMM d, y').format(raw.toDate());
  }
}

