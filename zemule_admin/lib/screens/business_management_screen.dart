import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BusinessManagementScreen extends StatefulWidget {
  const BusinessManagementScreen({super.key});

  @override
  State<BusinessManagementScreen> createState() => _BusinessManagementScreenState();
}

class _BusinessManagementScreenState extends State<BusinessManagementScreen> {
  String _filter = 'pending';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final query = _filter == 'pending'
        ? db.collection('businesses').where('status', isEqualTo: 'pending')
        : db.collection('businesses');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('Business Approval', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _filter,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: 'pending', child: Text('Pending only')),
                  DropdownMenuItem<String>(value: 'all', child: Text('All businesses')),
                ],
                onChanged: (String? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _filter = value);
                },
              ),
              if (_busy) ...<Widget>[
                const SizedBox(width: 12),
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: query.snapshots(),
                  builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Failed to load businesses: ${snapshot.error}'));
                    }

                    final docs = snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    if (docs.isEmpty) {
                      return const Center(child: Text('No businesses found.'));
                    }

                    return DataTable2(
                      columnSpacing: 12,
                      minWidth: 1100,
                      columns: const <DataColumn2>[
                        DataColumn2(label: Text('Name'), size: ColumnSize.L),
                        DataColumn2(label: Text('Category')),
                        DataColumn2(label: Text('Area')),
                        DataColumn2(label: Text('Status')),
                        DataColumn2(label: Text('Owner ID'), size: ColumnSize.L),
                        DataColumn2(label: Text('Created')),
                        DataColumn2(label: Text('Actions'), size: ColumnSize.L),
                      ],
                      rows: docs.map((doc) {
                        final data = doc.data();
                        final status = ((data['status'] as String?) ?? 'pending').toLowerCase();

                        return DataRow2(cells: <DataCell>[
                          DataCell(Text(_string(data['name'], fallback: doc.id))),
                          DataCell(Text(_string(data['category'], fallback: '-'))),
                          DataCell(Text(_string(data['area'], fallback: '-'))),
                          DataCell(Text(status)),
                          DataCell(Text(_string(data['ownerId'], fallback: '-'))),
                          DataCell(Text(_formatDate(data['createdAt']))),
                          DataCell(
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                if (status != 'approved')
                                  FilledButton.tonal(
                                    onPressed: _busy ? null : () => _setStatus(doc.id, 'approved'),
                                    child: const Text('Approve'),
                                  ),
                                if (status != 'rejected')
                                  FilledButton.tonal(
                                    onPressed: _busy ? null : () => _setStatus(doc.id, 'rejected'),
                                    child: const Text('Reject'),
                                  ),
                                IconButton(
                                  tooltip: 'Delete business',
                                  onPressed: _busy ? null : () => _deleteBusiness(doc.id),
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
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setStatus(String businessId, String status) async {
    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance.collection('businesses').doc(businessId).set(
        <String, dynamic>{
          'status': status,
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

  Future<void> _deleteBusiness(String businessId) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Delete business?'),
            content: const Text('This removes the business document from Firestore.'),
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
      await FirebaseFirestore.instance.collection('businesses').doc(businessId).delete();
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

