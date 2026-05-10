import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
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
                  Text('Category Management', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _busy ? null : _showCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Category'),
                  ),
                  if (_busy) ...<Widget>[
                    const SizedBox(width: 12),
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('categories').orderBy('name').snapshots(),
                  builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Failed to load categories: ${snapshot.error}'));
                    }

                    final docs = snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    if (docs.isEmpty) {
                      return const Center(child: Text('No categories found. Add your first category.'));
                    }

                    return DataTable2(
                      minWidth: 850,
                      columns: const <DataColumn2>[
                        DataColumn2(label: Text('Name'), size: ColumnSize.L),
                        DataColumn2(label: Text('Icon')),
                        DataColumn2(label: Text('Active')),
                        DataColumn2(label: Text('Created')),
                        DataColumn2(label: Text('Actions'), size: ColumnSize.L),
                      ],
                      rows: docs.map((doc) {
                        final data = doc.data();
                        final active = data['isActive'] != false;
                        return DataRow2(cells: <DataCell>[
                          DataCell(Text(_string(data['name'], fallback: doc.id))),
                          DataCell(Text(_string(data['icon'], fallback: '-'))),
                          DataCell(
                            Switch(
                              value: active,
                              onChanged: _busy
                                  ? null
                                  : (bool value) => _setActive(doc.id, value),
                            ),
                          ),
                          DataCell(Text(_formatDate(data['createdAt']))),
                          DataCell(
                            Wrap(
                              spacing: 8,
                              children: <Widget>[
                                IconButton(
                                  tooltip: 'Delete category',
                                  onPressed: _busy ? null : () => _deleteCategory(doc.id),
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

  Future<void> _showCreateDialog() async {
    final nameController = TextEditingController();
    final iconController = TextEditingController();

    final shouldCreate = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Create category'),
            content: SizedBox(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: iconController,
                    decoration: const InputDecoration(labelText: 'Icon key (optional)'),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Create'),
              ),
            ],
          ),
        ) ??
        false;

    final name = nameController.text.trim();
    final icon = iconController.text.trim();
    nameController.dispose();
    iconController.dispose();

    if (!shouldCreate || name.isEmpty) {
      return;
    }

    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance.collection('categories').add(<String, dynamic>{
        'name': name,
        'icon': icon,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _setActive(String categoryId, bool value) async {
    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance.collection('categories').doc(categoryId).set(
        <String, dynamic>{
          'isActive': value,
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

  Future<void> _deleteCategory(String categoryId) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Delete category?'),
            content: const Text('This removes the category document from Firestore.'),
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
      await FirebaseFirestore.instance.collection('categories').doc(categoryId).delete();
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

