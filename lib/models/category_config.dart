import 'package:flutter/material.dart';

class CategoryConfig {
  final String name;
  final IconData icon;
  final Color color;
  final double? budget;

  CategoryConfig({
    required this.name,
    required this.icon,
    required this.color,
    this.budget,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'iconCode': icon.codePoint,
      'colorValue': color.value,
      'budget': budget,
    };
  }

  factory CategoryConfig.fromMap(Map<String, dynamic> map) {
    return CategoryConfig(
      name: map['name'],
      icon: IconData(map['iconCode'], fontFamily: 'MaterialIcons'),
      color: Color(map['colorValue']),
      budget: map['budget'],
    );
  }
}

final List<CategoryConfig> kDefaultCategories = [
  CategoryConfig(name: 'Food', icon: Icons.restaurant, color: Colors.orange),
  CategoryConfig(name: 'Travel', icon: Icons.directions_car, color: Colors.blue),
  CategoryConfig(name: 'Shopping', icon: Icons.shopping_bag, color: Colors.purple),
  CategoryConfig(name: 'Petrol', icon: Icons.local_gas_station, color: Colors.green),
  CategoryConfig(name: 'Bills', icon: Icons.receipt_long, color: Colors.red),
  CategoryConfig(name: 'Medical', icon: Icons.medical_services, color: Colors.pink),
  CategoryConfig(name: 'Entertainment', icon: Icons.sports_esports, color: Colors.deepPurple),
  CategoryConfig(name: 'Other', icon: Icons.more_horiz, color: Colors.grey),
];
