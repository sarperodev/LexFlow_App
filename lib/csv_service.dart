import 'package:flutter/foundation.dart' show kIsWeb; // Platform kontrolü için
import 'dart:io' show File; // Web'de sadece tip olarak bulunur, çağrılmazsa hata vermez
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';
import 'expense_model.dart';

class CsvService {
  // Web için veritabanı anahtarı
  static const String _webDbKey = 'lexflow_csv_db';

  // --- MOBİL DOSYA YOLLARI ---
  Future<String> get _localPath async {
    if (kIsWeb) return ""; 
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<dynamic> get _getStorage async {
    if (kIsWeb) {
      return await SharedPreferences.getInstance();
    } else {
      final path = await _localPath;
      return File('$path/lexflow_database.csv');
    }
  }

  // --- VERİ OKUMA (HER İKİ PLATFORM) ---
  Future<String> _readData() async {
    final storage = await _getStorage;
    if (kIsWeb) {
      final prefs = storage as SharedPreferences;
      return prefs.getString(_webDbKey) ?? "";
    } else {
      final file = storage as File;
      if (await file.exists()) {
        return await file.readAsString();
      }
    }
    return "";
  }

  // --- VERİ YAZMA (HER İKİ PLATFORM) ---
  Future<void> _writeData(String content) async {
    final storage = await _getStorage;
    if (kIsWeb) {
      // storage zaten SharedPreferences tipinde döner
      await (storage as SharedPreferences).setString(_webDbKey, content);
    } else {
      // storage zaten File tipinde döner
      await (storage as File).writeAsString(content);
    }
  }

  Future<void> saveExpense(Expense expense) async {
    String content = await _readData();
    List<List<dynamic>> csvData = const CsvToListConverter().convert(content);
    
    if (csvData.isEmpty) {
      csvData.add(['ID', 'Tarih', 'IsIncome', 'Client', 'City', 'Yargi Turu', 'Tam Merci', 'Dosya No', 'Tur', 'Tutar', 'Aciklama']);
    }
    
    csvData.add(expense.toCsvRow());
    await _writeData(const ListToCsvConverter().convert(csvData));
  }

  Future<List<Expense>> getAllExpenses() async {
    String content = await _readData();
    List<Expense> expenses = [];
    if (content.isNotEmpty) {
      List<List<dynamic>> rows = const CsvToListConverter().convert(content);
      for (int i = 1; i < rows.length; i++) {
        if (rows[i].isNotEmpty && rows[i].length >= 11) {
          expenses.add(Expense.fromCsvRow(rows[i]));
        }
      }
    }
    return expenses;
  }

  // Akıllı Birleştirme - Mükerrer Kayıtları Önler
  Future<void> mergeExpenses(List<Expense> importedItems) async {
    final existingItems = await getAllExpenses();
    final Map<String, Expense> masterMap = {
      for (var item in existingItems) item.id: item,
      for (var item in importedItems) item.id: item,
    };
    
    List<List<dynamic>> csvData = [['ID', 'Tarih', 'IsIncome', 'Client', 'City', 'Yargi Turu', 'Tam Merci', 'Dosya No', 'Tur', 'Tutar', 'Aciklama']];
    for (var item in masterMap.values) {
      csvData.add(item.toCsvRow());
    }
    await _writeData(const ListToCsvConverter().convert(csvData));
  }

  Future<void> deleteExpenses(List<String> idsToDelete) async {
    final existingItems = await getAllExpenses();
    final remainingItems = existingItems.where((item) => !idsToDelete.contains(item.id)).toList();
    
    List<List<dynamic>> csvData = [['ID', 'Tarih', 'IsIncome', 'Client', 'City', 'Yargi Turu', 'Tam Merci', 'Dosya No', 'Tur', 'Tutar', 'Aciklama']];
    for (var item in remainingItems) {
      csvData.add(item.toCsvRow());
    }
    await _writeData(const ListToCsvConverter().convert(csvData));
  }
}