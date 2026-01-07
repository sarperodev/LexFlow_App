import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'package:intl/intl.dart';
import 'expense_model.dart';

class CsvService {
  static const String _webDbKey = 'lexflow_csv_db';
  static const String _sectionSeparator = "###_LEXFLOW_SYSTEM_DATA_###";

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

  Future<void> _writeData(String content) async {
    final storage = await _getStorage;
    if (kIsWeb) {
      await (storage as SharedPreferences).setString(_webDbKey, content);
    } else {
      await (storage as File).writeAsString(content, flush: true);
    }
  }

  // --- KRİTİK DÜZELTME BURADA YAPILDI ---
  // Eski kayıtları okurken satır sonlarını normalize ediyoruz.
  Future<void> saveExpense(Expense expense) async {
    String content = await _readData();
    
    // Windows (\r\n) veya Mac (\r) satır sonlarını Linux (\n) formatına çevir
    // Böylece 'csv' paketi satırları asla kaçırmaz.
    content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    
    List<List<dynamic>> csvData = const CsvToListConverter(eol: '\n', shouldParseNumbers: true).convert(content);
    
    if (csvData.isEmpty || csvData[0].isEmpty) {
      csvData = [['ID', 'Tarih', 'IsIncome', 'Client', 'City', 'Yargi Turu', 'Tam Merci', 'Dosya No', 'Tur', 'Tutar', 'Aciklama']];
    }

    csvData.add(expense.toCsvRow());

    String newCsv = const ListToCsvConverter(eol: '\n').convert(csvData);
    await _writeData(newCsv);
  }

  // --- OKUMA İŞLEMİNDE DE DÜZELTME ---
  Future<List<Expense>> getAllExpenses() async {
    String content = await _readData();
    
    // Satır sonlarını burada da temizliyoruz
    content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    List<Expense> expenses = [];
    if (content.isNotEmpty) {
      List<List<dynamic>> rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: true).convert(content);
      for (int i = 1; i < rows.length; i++) {
        if (rows[i].length >= 11) {
          try {
            expenses.add(Expense.fromCsvRow(rows[i]));
          } catch (e) {
            debugPrint("Satır atlandı: $e");
          }
        }
      }
    }
    return expenses;
  }

  Future<void> mergeExpenses(List<Expense> importedItems) async {
    final existingItems = await getAllExpenses(); // getAllExpenses zaten temizlenmiş veri getiriyor
    final Map<String, Expense> masterMap = {
      for (var item in existingItems) item.id: item,
      for (var item in importedItems) item.id: item,
    };
    List<List<dynamic>> csvData = [['ID', 'Tarih', 'IsIncome', 'Client', 'City', 'Yargi Turu', 'Tam Merci', 'Dosya No', 'Tur', 'Tutar', 'Aciklama']];
    for (var item in masterMap.values) {
      csvData.add(item.toCsvRow());
    }
    await _writeData(const ListToCsvConverter(eol: '\n').convert(csvData));
  }

  Future<void> deleteExpenses(List<String> idsToDelete) async {
    final existingItems = await getAllExpenses();
    final remainingItems = existingItems.where((item) => !idsToDelete.contains(item.id)).toList();
    List<List<dynamic>> csvData = [['ID', 'Tarih', 'IsIncome', 'Client', 'City', 'Yargi Turu', 'Tam Merci', 'Dosya No', 'Tur', 'Tutar', 'Aciklama']];
    for (var item in remainingItems) {
      csvData.add(item.toCsvRow());
    }
    await _writeData(const ListToCsvConverter(eol: '\n').convert(csvData));
  }

  Future<void> overwriteExpenses(List<Expense> expenses) async {
    List<List<dynamic>> csvData = [['ID', 'Tarih', 'IsIncome', 'Client', 'City', 'Yargi Turu', 'Tam Merci', 'Dosya No', 'Tur', 'Tutar', 'Aciklama']];
    for (var item in expenses) {
      csvData.add(item.toCsvRow());
    }
    await _writeData(const ListToCsvConverter(eol: '\n').convert(csvData));
  }

  Future<void> exportToCsv({
      required List<Expense> expenses, 
      required String userName, 
      required String lawFirmName, 
      required String email, 
      required String phone,
      required List<Map<String, dynamic>> tasksJson, 
      required bool isFullBackup 
      }) async {
    
    List<List<dynamic>> rows = [
      ['ID', 'Tarih', 'IsIncome', 'Client', 'City', 'Yargi Turu', 'Tam Merci', 'Dosya No', 'Tur', 'Tutar', 'Aciklama']
    ];
    for (var e in expenses) {
      rows.add(e.toCsvRow());
    }
    String csvData = const ListToCsvConverter(eol: '\n').convert(rows);

    if (isFullBackup) {
      StringBuffer systemData = StringBuffer();
      systemData.writeln(); 
      systemData.writeln(_sectionSeparator);
      
      Map<String, String> profileData = {
        'userName': userName,
        'lawFirmName': lawFirmName,
        'email': email,
        'phone': phone,
      };
      systemData.writeln(jsonEncode(profileData));

      for (var taskMap in tasksJson) {
        systemData.writeln("TASK|${jsonEncode(taskMap)}");
      }
      csvData = csvData + systemData.toString();
    }

    String timeStamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    String fileName = isFullBackup 
        ? "LexFlow_TAM_YEDEK_$timeStamp.csv" 
        : "LexFlow_Finans_Raporu_$timeStamp.csv";

    if (kIsWeb) {
      final bytes = utf8.encode(csvData);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      String? path = await FilePicker.platform.getDirectoryPath();
      if (path != null) {
        final file = File('$path/$fileName');
        await file.writeAsBytes([0xEF, 0xBB, 0xBF] + utf8.encode(csvData));
      }
    }
  }

  // --- IMPORT İŞLEMİ (Zaten düzeltilmişti ama tam dosya için buraya da ekledim) ---
  Future<Map<String, dynamic>?> importFromCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true, 
      );

      if (result != null) {
        String fileContent;
        if (kIsWeb) {
          fileContent = utf8.decode(result.files.first.bytes!);
        } else {
          final file = File(result.files.single.path!);
          fileContent = await file.readAsString();
        }

        // KESİN ÇÖZÜM: Dosya içeriğindeki tüm satır sonlarını \n formatına zorluyoruz.
        fileContent = fileContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

        List<String> mainParts = fileContent.split(_sectionSeparator);
        String csvPart = mainParts[0].trim();
        String? systemPart = mainParts.length > 1 ? mainParts[1] : null;

        List<List<dynamic>> csvTable = const CsvToListConverter(eol: '\n', shouldParseNumbers: true).convert(csvPart);
        
        debugPrint("Tespit edilen satır sayısı: ${csvTable.length}");

        List<Expense> importedExpenses = [];
        for (int i = 1; i < csvTable.length; i++) {
           if (csvTable[i].length >= 11) {
             try {
               importedExpenses.add(Expense.fromCsvRow(csvTable[i]));
             } catch (e) {
               debugPrint("Satır atlandı: $e");
             }
           }
        }

        String? newUserName, newLawFirmName, newEmail, newPhone;
        List<Map<String, dynamic>> newTasksJson = [];

        if (systemPart != null) {
          List<String> systemLines = LineSplitter.split(systemPart).toList();
          for (var line in systemLines) {
            line = line.trim();
            if (line.isEmpty) continue;
            if (line.startsWith("{")) {
               try {
                 var jsonMap = jsonDecode(line);
                 newUserName = jsonMap['userName'];
                 newLawFirmName = jsonMap['lawFirmName'];
                 newEmail = jsonMap['email'];
                 newPhone = jsonMap['phone'];
               } catch (e) {
                 debugPrint("Profil json hatası: $e");
               }
            } else if (line.startsWith("TASK|")) {
              try {
                newTasksJson.add(jsonDecode(line.substring(5)));
              } catch (e) {
                debugPrint("Görev json hatası: $e");
              }
            }
          }
        }
        return {
          'expenses': importedExpenses,
          'userName': newUserName,
          'lawFirmName': newLawFirmName,
          'email': newEmail,
          'phone': newPhone,
          'tasks': newTasksJson 
        };
      }
    } catch (e) {
      debugPrint("Genel import hatası: $e");
      return null;
    }
    return null;
  }

  Future<void> applyImportedData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    if (data['userName'] != null) await prefs.setString('fullName', data['userName']);
    if (data['lawFirmName'] != null) await prefs.setString('officeName', data['lawFirmName']);
    if (data['email'] != null) await prefs.setString('email', data['email']);
    if (data['phone'] != null) await prefs.setString('phone', data['phone']);

    if (data['tasks'] != null) {
      await prefs.setString('tasks', jsonEncode(data['tasks']));
    }

    if (data['expenses'] != null) {
      List<Expense> expenses = List<Expense>.from(data['expenses']);
      await overwriteExpenses(expenses);
    }
  }
}