import 'package:flutter/material.dart';

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    this.isSelected = false,
  });

  final String id;
  final String name;
  final IconData icon;
  final bool isSelected;

  Category copyWith({
    String? id,
    String? name,
    IconData? icon,
    bool? isSelected,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
