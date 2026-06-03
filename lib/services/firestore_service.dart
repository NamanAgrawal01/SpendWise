import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/expense.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection reference
  CollectionReference _getExpensesRef(String userId) {
    return _db.collection('users').doc(userId).collection('expenses');
  }

  Future<void> addExpense(String userId, Expense expense) async {
    try {
      await _getExpensesRef(userId).doc(expense.id).set(expense.toMap());
    } catch (e) {
      debugPrint("Error adding to Firestore: $e");
    }
  }

  Future<void> updateExpense(String userId, Expense expense) async {
    try {
      await _getExpensesRef(userId).doc(expense.id).update(expense.toMap());
    } catch (e) {
      debugPrint("Error updating in Firestore: $e");
    }
  }

  Future<void> deleteExpense(String userId, String expenseId) async {
    try {
      await _getExpensesRef(userId).doc(expenseId).delete();
    } catch (e) {
      debugPrint("Error deleting from Firestore: $e");
    }
  }

  Future<void> clearAllData(String userId) async {
    try {
      final snapshot = await _getExpensesRef(userId).get();
      final batch = _db.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      await _db.collection('users').doc(userId).delete();
    } catch (e) {
      debugPrint("Error clearing Firestore data: $e");
    }
  }

  Future<void> updateSettings(String userId, Map<String, dynamic> settings) async {
    try {
      await _db.collection('users').doc(userId).set({
        'settings': settings,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error updating settings in Firestore: $e");
    }
  }

  // Optional: Fetch all from Firestore (for initial sync)
  Future<List<Expense>> fetchExpenses(String userId) async {
    try {
      final snapshot = await _getExpensesRef(userId).get();
      return snapshot.docs
          .map((doc) => Expense.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint("Error fetching from Firestore: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchSettings(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['settings'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint("Error fetching settings from Firestore: $e");
    }
    return null;
  }
}
