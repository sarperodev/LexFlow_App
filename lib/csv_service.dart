import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'expense_model.dart';

class CsvService {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/lexflow_database.csv');
  }

  Future<void> saveExpense(Expense expense) async {
    final file = await _localFile;
    List<List<dynamic>> csvData = [];
    if (await file.exists()) {
      String content = await file.readAsString();
      csvData = const CsvToListConverter().convert(content);
    } else {
      csvData.add(['ID', 'Tarih', 'IsIncome', 'Client', 'City', 'Yargi Turu', 'Tam Merci', 'Dosya No', 'Tur', 'Tutar', 'Aciklama']);
    }
    csvData.add(expense.toCsvRow());
    await file.writeAsString(const ListToCsvConverter().convert(csvData));
  }

  // Akıllı Birleştirme - Mükerrer Kayıtları Önler
  Future<void> mergeExpenses(List<Expense> importedItems) async {
    final existingItems = await getAllExpenses();
    final Map<String, Expense> masterMap = {
      for (var item in existingItems) item.id: item,
      for (var item in importedItems) item.id: item,
    };
    final file = await _localFile;
    List<List<dynamic>> csvData = [['ID', 'Tarih', 'IsIncome', 'Client', 'City', 'Yargi Turu', 'Tam Merci', 'Dosya No', 'Tur', 'Tutar', 'Aciklama']];
    for (var item in masterMap.values) {
      csvData.add(item.toCsvRow());
    }
    await file.writeAsString(const ListToCsvConverter().convert(csvData));
  }

  Future<void> deleteExpenses(List<String> idsToDelete) async {
    final existingItems = await getAllExpenses();
    final remainingItems = existingItems.where((item) => !idsToDelete.contains(item.id)).toList();
    final file = await _localFile;
    List<List<dynamic>> csvData = [['ID', 'Tarih', 'IsIncome', 'Client', 'City', 'Yargi Turu', 'Tam Merci', 'Dosya No', 'Tur', 'Tutar', 'Aciklama']];
    for (var item in remainingItems) {
      csvData.add(item.toCsvRow());
    }
    await file.writeAsString(const ListToCsvConverter().convert(csvData));
  }

  Future<List<Expense>> getAllExpenses() async {
    final file = await _localFile;
    List<Expense> expenses = [];
    if (await file.exists()) {
      String content = await file.readAsString();
      List<List<dynamic>> rows = const CsvToListConverter().convert(content);
      for (int i = 1; i < rows.length; i++) {
        if (rows[i].isNotEmpty && rows[i].length >= 11) {
          expenses.add(Expense.fromCsvRow(rows[i]));
        }
      }
    }
    return expenses; 
  }
}