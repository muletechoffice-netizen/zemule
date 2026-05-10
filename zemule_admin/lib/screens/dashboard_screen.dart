import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return FutureBuilder<Map<String, int>>(
      future: _loadStats(db),
      builder: (BuildContext context, AsyncSnapshot<Map<String, int>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Failed to load stats: ${snapshot.error}'));
        }

        final stats = snapshot.data ?? <String, int>{};

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _StatCard(title: 'Businesses', value: '${stats['businesses'] ?? 0}'),
                _StatCard(title: 'Pending Approval', value: '${stats['pendingBusinesses'] ?? 0}'),
                _StatCard(title: 'Users', value: '${stats['users'] ?? 0}'),
                _StatCard(title: 'Categories', value: '${stats['categories'] ?? 0}'),
              ],
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Recent Pending Businesses', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: db
                          .collection('businesses')
                          .where('status', isEqualTo: 'pending')
                          .limit(8)
                          .snapshots(),
                      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> pendingSnap) {
                        if (pendingSnap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (pendingSnap.hasError) {
                          return Text('Could not load pending list: ${pendingSnap.error}');
                        }

                        final docs = pendingSnap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                        if (docs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No pending businesses right now.'),
                          );
                        }

                        return Column(
                          children: docs.map((doc) {
                            final data = doc.data();
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text((data['name'] as String?)?.trim().isNotEmpty == true
                                  ? (data['name'] as String)
                                  : doc.id),
                              subtitle: Text(
                                '${(data['category'] as String?) ?? 'Uncategorized'} • '
                                '${(data['area'] as String?) ?? 'Unknown area'}',
                              ),
                              trailing: Text(_formatDate(data['createdAt'])),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, int>> _loadStats(FirebaseFirestore db) async {
    final businesses = await db.collection('businesses').count().get();
    final pendingBusinesses = await db
        .collection('businesses')
        .where('status', isEqualTo: 'pending')
        .count()
        .get();
    final users = await db.collection('users').count().get();
    final categories = await db.collection('categories').count().get();

    return <String, int>{
      'businesses': businesses.count ?? 0,
      'pendingBusinesses': pendingBusinesses.count ?? 0,
      'users': users.count ?? 0,
      'categories': categories.count ?? 0,
    };
  }

  String _formatDate(dynamic raw) {
    if (raw is! Timestamp) {
      return '-';
    }
    return DateFormat('MMM d, y').format(raw.toDate());
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

