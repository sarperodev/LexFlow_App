import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart'; 
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; 
import 'package:printing/printing.dart';
import 'package:flutter/services.dart'; 
import 'expense_model.dart';
import 'csv_service.dart';

// AAÜT 2025 MAKTU ÜCRET HARİTASI (İLK SAAT VEYA MAKTU TUTARLAR)
const Map<String, double> aaut2025Listesi = {
  "BÜRODA SÖZLÜ DANIŞMA (İLK BİR SAATE KADAR)": 3500.0,
  "ÇAĞRI ÜZERİNE GİDİLEN YERDE SÖZLÜ DANIŞMA": 6000.0,
  "YAZILI DANIŞMA (İLK BİR SAATE KADAR)": 6000.0,
  "HER TÜRLÜ DİLEKÇE YAZILMASI, İHBARNAME, İHTARNAME": 4500.0,
  "KİRA SÖZLEŞMESİ VE BENZERİ BELGELERİN HAZIRLANMASI": 6000.0,
  "TÜZÜK, YÖNETMELİK, VASİYETNAME, MİRAS SÖZLEŞMESİ": 24000.0,
  "ŞİRKET ANA SÖZLEŞMESİ, DEVİR VE BİRLEŞME İŞLERİ": 16000.0,
  "DURUM BELGELENDİRME, ÖDEME TAHSİLİ, ÖRNEK ÇIKARMA": 5000.0,
  "HAKKIN DOĞUMU, TESPİTİ, TESCİLİ VE KORUNMASI": 9000.0,
  "ŞİRKET KURULUŞU, RUHSAT VE VATANDAŞLIK İŞLERİ": 45000.0,
  "VERGİ UZLAŞMA KOMİSYONLARINDA TAKİP EDİLEN İŞLER": 18000.0,
  "ULUSLARARASI YARGI YERLERİ (DURUŞMASIZ)": 80000.0,
  "ULUSLARARASI YARGI YERLERİ (DURUŞMALI)": 150000.0,
  "İHTİYATİ HACİZ, İHTİYATİ TEDBİR, DELİL TESPİTİ (DURUŞMASIZ)": 7500.0,
  "İHTİYATİ HACİZ, İHTİYATİ TEDBİR, DELİL TESPİTİ (DURUŞMALI)": 9500.0,
  "ORTAKLIĞIN GİDERİLMESİ SATIŞ MEMURLUĞU İŞLERİ": 12500.0,
  "ORTAKLIĞIN GİDERİLMESİ VE TAKSİM DAVALARI": 28500.0,
  "İCRA DAİRELERİNDE YAPILAN TAKİPLER": 6000.0,
  "İCRA MAHKEMELERİNDE TAKİP EDİLEN İŞLER": 7000.0,
  "İCRA MAHKEMELERİNDE DAVA VE DURUŞMALI İŞLER": 12000.0,
  "TAHLİYEYE İLİŞKİN İCRA TAKİPLERİ": 13500.0,
  "İCRA MAHKEMELERİ CEZA İŞLERİ": 10000.0,
  "SULH HUKUK MAHKEMELERİNDE TAKİP EDİLEN DAVALAR": 18000.0,
  "SULH CEZA HAKİMLİKLERİ VE İNFAZ HAKİMLİKLERİ": 13500.0,
  "ASLİYE MAHKEMELERİNDE TAKİP EDİLEN DAVALAR": 30000.0,
  "TÜKETİCİ MAHKEMELERİNDE TAKİP EDİLEN DAVALAR": 15000.0,
  "TÜKETİCİ MAHKEMELERİ KREDİ UYARLAMA DAVALARI": 14000.0,
  "FİKRİ VE SINAİ HAKLAR MAHKEMELERİNDE DAVALAR": 40000.0,
  "AĞIR CEZA MAHKEMELERİNDE TAKİP EDİLEN DAVALAR": 48000.0,
  "ÇOCUK MAHKEMELERİNDE TAKİP EDİLEN DAVALAR": 30000.0,
  "İDARE VE VERGİ MAHKEMELERİNDE DURUŞMASIZ DAVALAR": 18000.0,
  "İDARE VE VERGİ MAHKEMELERİNDE DURUŞMALI DAVALAR": 36000.0,
  "BAM İSTİNAF DAVALARI (DURUŞMALI BİR İŞ)": 16000.0,
  "YARGITAYDA İLK DERECEDE GÖRÜLEN DAVALAR": 46500.0,
  "DANIŞTAYDA İLK DERECEDE GÖRÜLEN DAVALAR (DURUŞMASIZ)": 28000.0,
  "DANIŞTAYDA İLK DERECEDE GÖRÜLEN DAVALAR (DURUŞMALI)": 56000.0,
  "ANAYASA MAHKEMESİ BİREYSEL BAŞVURU (DURUŞMASIZ)": 30000.0,
  "ANAYASA MAHKEMESİ BİREYSEL BAŞVURU (DURUŞMALI)": 60000.0,
  "UYUŞMAZLIK MAHKEMESİNDEKİ DAVALAR": 30000.0,
};

// TAKİP EDEN SAAT ÜCRETLERİ (AAÜT BİRİNCİ KISIM)
const Map<String, double> aautTakipEdenSaat = {
  "BÜRODA SÖZLÜ DANIŞMA (İLK BİR SAATE KADAR)": 1500.0, // 
  "ÇAĞRI ÜZERİNE GİDİLEN YERDE SÖZLÜ DANIŞMA": 3000.0, // 
  "YAZILI DANIŞMA (İLK BİR SAATE KADAR)": 3000.0, // 
};

double calculateAautAmount(String type, int hours) {
  double base = aaut2025Listesi[type] ?? 0;
  if (aautTakipEdenSaat.containsKey(type) && hours > 1) {
    return base + ((hours - 1) * aautTakipEdenSaat[type]!); // 
  }
  return base;
}

String formatCurrency(double amount) {
  return NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2).format(amount);
}

String toTitleCase(String text) {
  if (text.isEmpty) return text;
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LexFlowApp());
}

class LexFlowApp extends StatelessWidget {
  const LexFlowApp({super.key});
  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF13538A);
    return MaterialApp(
      title: 'LexFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: brandBlue, brightness: Brightness.light, surface: Colors.white),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(seedColor: brandBlue, brightness: Brightness.dark, surface: const Color(0xFF121212)),
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

// --- ANA SAYFA ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String officeName = "Yükleniyor...";
  List<Expense> _recentExpenses = [];
  double _totalIncome = 0;
  double _totalExpense = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() { officeName = prefs.getString('officeName') ?? "Hukuk Bürosu Belirtilmedi"; });
    }
    _refreshExpenses();
  }

  Future<void> _refreshExpenses() async {
    final expenses = await CsvService().getAllExpenses();
    double income = 0;
    double expense = 0;
    for (var e in expenses) {
      if (e.isIncome) { income += e.amount; } else { expense += e.amount; }
    }
    if (mounted) {
      setState(() { 
        _recentExpenses = expenses.reversed.toList(); 
        _totalIncome = income;
        _totalExpense = expense;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset('assets/logo.svg', width: 28, height: 28, colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.onSurface, BlendMode.srcIn)),
            const SizedBox(width: 10),
            const Text('LexFlow', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())); _loadInitialData(); })],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFinancialSummary(),
            const SizedBox(height: 24),
            const Text("Hızlı İşlemler", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildQuickAction(context, "Masraf", Icons.add_card, false),
                _buildQuickAction(context, "Tahsilat", Icons.account_balance_wallet, true),
                _buildQuickAction(context, "Analiz", Icons.analytics_outlined, false),
                _buildQuickAction(context, "Görevler", Icons.checklist_rtl_rounded, false),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Son İşlemler", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (context) => const AllTransactionsPage())); _refreshExpenses(); }, child: const Text("Tümünü Göster")),
              ],
            ),
            const SizedBox(height: 12),
            _recentExpenses.isEmpty
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text("Henüz işlem bulunmuyor.", style: TextStyle(color: Colors.grey))))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentExpenses.length > 5 ? 5 : _recentExpenses.length,
                  itemBuilder: (context, index) => _buildTransactionCard(_recentExpenses[index]),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummary() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF13538A), borderRadius: BorderRadius.circular(25)),
      child: Column(children: [
        Text(officeName, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        const Text("Net Durum", style: TextStyle(color: Colors.white, fontSize: 16)),
        Text(formatCurrency(_totalIncome - _totalExpense), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _summaryItem("Kazanç", _totalIncome, Colors.greenAccent),
          Container(width: 1, height: 40, color: Colors.white24),
          _summaryItem("Masraf", _totalExpense, Colors.orangeAccent),
        ])
      ]),
    );
  }

  Widget _summaryItem(String label, double val, Color color) => Column(children: [Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)), Text(formatCurrency(val), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16))]);

  Widget _buildTransactionCard(Expense item) => Card(child: ListTile(onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (context) => TransactionDetailPage(transaction: item))); _refreshExpenses(); }, leading: Icon(item.isIncome ? Icons.south_west : Icons.north_east, color: item.isIncome ? Colors.green : Colors.red), title: Text(item.clientName, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("${item.city} ${item.fullAuthority}"), trailing: Text("${item.isIncome ? '+' : '-'}${formatCurrency(item.amount)}", style: TextStyle(color: item.isIncome ? Colors.green : Colors.red, fontWeight: FontWeight.bold))));

  Widget _buildQuickAction(BuildContext context, String label, IconData icon, bool isIncomeAction) => GestureDetector(
    onTap: () async {
  if (label == "Görevler") {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const TasksPage()));
  } else if (label == "Analiz") {
    // SÜSLÜ PARANTEZ EKLENDİ
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const FinancialAnalysisPage()));
  } else if (label == "Masraf" || label == "Tahsilat") {
    // SÜSLÜ PARANTEZ EKLENDİ
    await Navigator.push(context, MaterialPageRoute(builder: (context) => TransactionFormPage(isIncome: isIncomeAction)));
  }
  _refreshExpenses();
},
    child: Column(children: [Container(height: 65, width: 65, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1))), child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28)), const SizedBox(height: 8), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))]),
  );
}

// --- GÖREVLER MODÜLÜ ---
class Task {
  final String id; String title; bool isDone; DateTime dateTime;
  Task({required this.id, required this.title, required this.isDone, required this.dateTime});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'isDone': isDone, 'dateTime': dateTime.toIso8601String()};
  factory Task.fromJson(Map<String, dynamic> json) => Task(id: json['id'], title: json['title'], isDone: json['isDone'], dateTime: DateTime.parse(json['dateTime']));
}

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});
  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  List<Task> _tasks = [];
  @override void initState() { super.initState(); _load(); }
  void _load() async { 
    final p = await SharedPreferences.getInstance(); final String? s = p.getString('tasks'); 
    if (s != null) { final List l = jsonDecode(s); if (mounted) setState(() { _tasks = l.map((e) => Task.fromJson(e)).toList(); _tasks.sort((a, b) => a.dateTime.compareTo(b.dateTime)); }); } 
  }
  void _save() async { final p = await SharedPreferences.getInstance(); await p.setString('tasks', jsonEncode(_tasks.map((e) => e.toJson()).toList())); }

  void _addTask() async {
    final tc = TextEditingController(); DateTime selDate = DateTime.now(); TimeOfDay selTime = TimeOfDay.now();
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Yeni Görev Ekle"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: tc, decoration: const InputDecoration(labelText: "Görev / Not")),
        ListTile(leading: const Icon(Icons.event), title: const Text("Tarih"), trailing: StatefulBuilder(builder: (ctx, ss) => Text(DateFormat('dd.MM.yyyy').format(selDate))), onTap: () async { final d = await showDatePicker(context: ctx, initialDate: selDate, firstDate: DateTime.now(), lastDate: DateTime(2100)); if (d != null) setState(() => selDate = d); }),
        ListTile(leading: const Icon(Icons.access_time), title: const Text("Saat"), trailing: StatefulBuilder(builder: (ctx, ss) => Text(selTime.format(ctx))), onTap: () async { final t = await showTimePicker(context: ctx, initialTime: selTime); if (t != null) setState(() => selTime = t); }),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")), ElevatedButton(onPressed: () { if (tc.text.isNotEmpty) { setState(() { _tasks.add(Task(id: const Uuid().v4(), title: tc.text, isDone: false, dateTime: DateTime(selDate.year, selDate.month, selDate.day, selTime.hour, selTime.minute))); _tasks.sort((a, b) => a.dateTime.compareTo(b.dateTime)); }); _save(); Navigator.pop(ctx); } }, child: const Text("Kaydet"))],
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Hukuki Görevler")),
    floatingActionButton: FloatingActionButton(onPressed: _addTask, child: const Icon(Icons.add_task)),
    body: _tasks.isEmpty ? const Center(child: Text("Bekleyen görev bulunmuyor.")) : ListView.builder(itemCount: _tasks.length, itemBuilder: (context, index) {
      final t = _tasks[index];
      return ListTile(
        leading: Checkbox(value: t.isDone, onChanged: (v) { setState(() { t.isDone = v!; }); _save(); }),
        title: Text(t.title, style: TextStyle(decoration: t.isDone ? TextDecoration.lineThrough : null, color: t.isDone ? Colors.grey : null)),
        subtitle: Text(DateFormat('dd.MM.yyyy - HH:mm').format(t.dateTime), style: TextStyle(color: t.dateTime.isBefore(DateTime.now()) && !t.isDone ? Colors.red : Colors.grey, fontSize: 12)),
        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () { setState(() { _tasks.removeAt(index); }); _save(); }),
      );
    }),
  );
}

// --- MALİ ANALİZ ---
class FinancialAnalysisPage extends StatefulWidget {
  const FinancialAnalysisPage({super.key});
  @override
  State<FinancialAnalysisPage> createState() => _FinancialAnalysisPageState();
}

class _FinancialAnalysisPageState extends State<FinancialAnalysisPage> {
  Map<String, double> distribution = {};
  List<FlSpot> _lineSpots = [];
  
  @override void initState() { super.initState(); _process(); }

  void _process() async {
    final list = await CsvService().getAllExpenses();
    if (list.isEmpty) return;

    Map<String, double> dist = {};
    for (var e in list) {
      String key = "${e.type} (${e.isIncome ? 'GELİR' : 'GİDER'})";
      dist[key] = (dist[key] ?? 0) + e.amount;
    }

    list.sort((a, b) => DateFormat("dd.MM.yyyy").parse(a.date).compareTo(DateFormat("dd.MM.yyyy").parse(b.date)));
    double cumulativeNet = 0;
    List<FlSpot> spots = [];
    for (int i = 0; i < list.length; i++) {
      cumulativeNet += list[i].isIncome ? list[i].amount : -list[i].amount;
      spots.add(FlSpot(i.toDouble(), cumulativeNet));
    }

    if (mounted) setState(() { distribution = dist; _lineSpots = spots; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Mali Analiz")), 
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20), 
      child: Column(children: [
        const Text("Gelir/Gider Dağılım Analizi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        SizedBox(
  height: 250, 
  child: distribution.isEmpty 
    ? const Center(child: Text("Veri bulunamadı")) 
    : PieChart(PieChartData(sections: distribution.entries.map((e) => PieChartSectionData(
        // .withOpacity(0.7) YERİNE .withValues(alpha: 0.7) KULLANILDI
        color: e.key.contains('GELİR') ? Colors.green : Colors.red.withValues(alpha: 0.7), 
        value: e.value, 
        title: e.key.split(' ')[0], 
        radius: 60, 
        titleStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)
      )).toList()))
),
        const SizedBox(height: 30),
        const Divider(),
        const Text("Net Durum Değişim Grafiği (Zaman Bazlı)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        SizedBox(height: 200, width: double.infinity, child: _lineSpots.isEmpty ? const Center(child: Text("Veri yetersiz")) : LineChart(LineChartData(
          lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(formatCurrency(s.y), const TextStyle(color: Colors.white))).toList())),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 60, getTitlesWidget: (v, m) => Text(v.toStringAsFixed(0), style: const TextStyle(fontSize: 10)))),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
        lineBarsData: [LineChartBarData(spots: _lineSpots, isCurved: true, color: const Color(0xFF13538A), barWidth: 3, belowBarData: BarAreaData(show: true, color: const Color(0xFF13538A).withValues(alpha: 0.1)))]))),        const SizedBox(height: 30),
        ...distribution.entries.map((e) => ListTile(title: Text(e.key), trailing: Text(formatCurrency(e.value), style: TextStyle(fontWeight: FontWeight.bold, color: e.key.contains('GELİR') ? Colors.green : Colors.red)))),
      ])
    )
  );
}

// --- TÜM İŞLEMLER ---
class AllTransactionsPage extends StatefulWidget {
  const AllTransactionsPage({super.key});
  @override
  State<AllTransactionsPage> createState() => _AllTransactionsPageState();
}

class _AllTransactionsPageState extends State<AllTransactionsPage> {
  List<Expense> allEx = []; List<Expense> filteredEx = []; String query = ""; String natureFilter = "Tümü"; 
  DateTimeRange? dateRange; bool _isSelectionMode = false; final Set<String> _selectedIds = {}; 

  @override void initState() { super.initState(); _load(); }
  void _load() async { final res = await CsvService().getAllExpenses(); if (mounted) setState(() { allEx = res; _apply(); }); }
  void _apply() {
    List<Expense> temp = List.from(allEx);
    if (natureFilter == "Gelir") temp = temp.where((e) => e.isIncome).toList();
    if (natureFilter == "Gider") temp = temp.where((e) => !e.isIncome).toList();
    if (query.isNotEmpty) temp = temp.where((e) => e.clientName.toLowerCase().contains(query.toLowerCase())).toList();
    if (dateRange != null) temp = temp.where((e) { DateTime dt = DateFormat("dd.MM.yyyy").parse(e.date); return dt.isAfter(dateRange!.start.subtract(const Duration(days: 1))) && dt.isBefore(dateRange!.end.add(const Duration(days: 1))); }).toList();
    if (mounted) setState(() { filteredEx = temp.reversed.toList(); });
  }

  void _deleteSelected() async {
    bool? confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text("Kayıtları Sil"), content: Text("${_selectedIds.length} adet kayıt silinecektir."), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("İptal")), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Sil"))]));
    if (confirm == true) { await CsvService().deleteExpenses(_selectedIds.toList()); if (mounted) { setState(() { _selectedIds.clear(); _isSelectionMode = false; }); _load(); } }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leadingWidth: _isSelectionMode ? 100 : null,
      leading: Row(mainAxisSize: MainAxisSize.min, children: [ const BackButton(), if (_isSelectionMode) Checkbox(value: _selectedIds.length == filteredEx.length && filteredEx.isNotEmpty, onChanged: (val) { setState(() { if (val!) { _selectedIds.addAll(filteredEx.map((e) => e.id)); } else { _selectedIds.clear(); _isSelectionMode = false; } }); }) ]),
      title: Text(_isSelectionMode ? "${_selectedIds.length} Seçildi" : "Tüm İşlemler"),
      actions: [
        if (_isSelectionMode) IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _deleteSelected),
        if (!_isSelectionMode) PopupMenuButton<String>(icon: const Icon(Icons.import_export), onSelected: (v) async {
          if (v == 'export') { await Navigator.push(context, MaterialPageRoute(builder: (context) => const ExportSelectionPage())); _load(); }
          else {
            FilePickerResult? res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
            if (res != null) {
              final file = File(res.files.single.path!); final content = await file.readAsString();
              final rows = const CsvToListConverter().convert(content); List<Expense> imported = [];
              for (int i = 1; i < rows.length; i++) { if (rows[i].length >= 11) imported.add(Expense.fromCsvRow(rows[i])); }
              await CsvService().mergeExpenses(imported); if (mounted) _load();
            }
          }
        }, itemBuilder: (context) => [const PopupMenuItem(value: 'import', child: Text("İçeri Aktarma")), const PopupMenuItem(value: 'export', child: Text("Kayıtları Dışarı Aktarma"))])
      ],
    ),
    body: Column(children: [
      if (!_isSelectionMode) Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        TextField(decoration: const InputDecoration(hintText: "Müvekkil Ara...", border: OutlineInputBorder()), onChanged: (v) { query = v; _apply(); }),
        const SizedBox(height: 8),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          ActionChip(label: const Text("Tarih Aralığı"), onPressed: () async { final res = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (res != null && mounted) setState(() { dateRange = res; _apply(); }); }),
          const SizedBox(width: 8), FilterChip(label: const Text("Gelir"), selected: natureFilter == "Gelir", onSelected: (s) { natureFilter = s ? "Gelir" : "Tümü"; _apply(); }),
          const SizedBox(width: 8), FilterChip(label: const Text("Gider"), selected: natureFilter == "Gider", onSelected: (s) { natureFilter = s ? "Gider" : "Tümü"; _apply(); }),
        ]))
      ])),
      Expanded(child: ListView.builder(itemCount: filteredEx.length, itemBuilder: (context, index) {
        final item = filteredEx[index]; bool showHeader = index == 0 || filteredEx[index].date != filteredEx[index - 1].date;
        return Column(children: [
          if (showHeader) Container(width: double.infinity, padding: const EdgeInsets.all(12), color: Colors.grey.withValues(alpha: 0.1), child: Text(item.date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          ListTile(onLongPress: () { setState(() { _isSelectionMode = true; _selectedIds.add(item.id); }); }, onTap: () { if (_isSelectionMode) { setState(() { if (_selectedIds.contains(item.id)) { _selectedIds.remove(item.id); if (_selectedIds.isEmpty) _isSelectionMode = false; } else { _selectedIds.add(item.id); } }); } else { Navigator.push(context, MaterialPageRoute(builder: (context) => TransactionDetailPage(transaction: item))); } }, leading: _isSelectionMode ? Checkbox(value: _selectedIds.contains(item.id), onChanged: (v) { setState(() { if (v!) { _selectedIds.add(item.id); } else { _selectedIds.remove(item.id); if (_selectedIds.isEmpty) _isSelectionMode = false; } }); }) : Icon(item.isIncome ? Icons.south_west : Icons.north_east, color: item.isIncome ? Colors.green : Colors.red), title: Text(item.clientName, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("${item.city} ${item.fullAuthority}"), trailing: Text("${item.isIncome ? '+' : '-'}${formatCurrency(item.amount)}", style: TextStyle(color: item.isIncome ? Colors.green : Colors.red, fontWeight: FontWeight.bold))),
        ]);
      }))
    ]),
  );
}

// --- KAYIT SEÇİMİ ---
class ExportSelectionPage extends StatefulWidget {
  const ExportSelectionPage({super.key});
  @override
  State<ExportSelectionPage> createState() => _ExportSelectionPageState();
}

class _ExportSelectionPageState extends State<ExportSelectionPage> {
  List<Expense> all = []; List<Expense> filtered = []; final Set<String> selectedIds = {}; 
  @override void initState() { super.initState(); _load(); }
  void _load() async { final res = await CsvService().getAllExpenses(); if (mounted) setState(() { all = res; filtered = res; }); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Kayıt Seçimi")), body: Column(children: [
    Padding(padding: const EdgeInsets.all(12), child: TextField(decoration: const InputDecoration(hintText: "Müvekkil Ara...", border: OutlineInputBorder()), onChanged: (q) => setState(() { filtered = all.where((e) => e.clientName.toLowerCase().contains(q.toLowerCase())).toList(); }))),
    CheckboxListTile(title: const Text("Hepsini Seç", style: TextStyle(fontWeight: FontWeight.bold)), value: filtered.isNotEmpty && selectedIds.length == filtered.length, onChanged: (v) { setState(() { if (v!) { selectedIds.addAll(filtered.map((e) => e.id)); } else { selectedIds.clear(); } }); }),
    const Divider(),
    Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder: (context, index) { final item = filtered[index]; return CheckboxListTile(title: Text(item.clientName), subtitle: Text("${item.date} - ${item.type}"), value: selectedIds.contains(item.id), onChanged: (v) { setState(() { if (v!) { selectedIds.add(item.id); } else { selectedIds.remove(item.id); } }); }); })),
    Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: selectedIds.isEmpty ? null : () async { 
      String? path = await FilePicker.platform.getDirectoryPath(); if (path == null || !mounted) return; 
      final records = all.where((e) => selectedIds.contains(e.id)).toList(); List<List<dynamic>> csvData = [['ID', 'Tarih', 'IsIncome', 'Client', 'City', 'Yargi Turu', 'Tam Merci', 'Dosya No', 'Tur', 'Tutar', 'Aciklama']]; 
      for (var r in records) { csvData.add(r.toCsvRow()); } 
      final file = File('$path/LexFlow_Yedek_${DateTime.now().millisecondsSinceEpoch}.csv'); await file.writeAsString(const ListToCsvConverter().convert(csvData)); 
      if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("DOSYA KAYDEDİLDİ: ${file.path}"))); Navigator.pop(context); }    }, child: const Text("Dışarı Aktar"))))
  ]));
}

// --- İŞLEM FORMU ---
class TransactionFormPage extends StatefulWidget {
  final bool isIncome;
  const TransactionFormPage({super.key, required this.isIncome});
  @override
  State<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends State<TransactionFormPage> {
  final _clientC = TextEditingController(); final _caseC = TextEditingController(); final _amountC = TextEditingController(); final _descC = TextEditingController(); 
  DateTime _selectedDate = DateTime.now(); bool _isToday = true; String? selCity, selJuris, selUnit, selType; String selUnitNo = "1";
int _selectedHours = 1;

  final List<String> cities = [
    "ADANA", "ANKARA", "BURSA", "İSTANBUL", "İZMİR", 
    "ADDIYAMAN", "AFYONKARAHİSAR", "AĞRI", "AKSARAY", "AMASYA", "ANTALYA", "ARDAHAN", "ARTVİN", "AYDIN", "BALIKESİR", "BARTIN", "BATMAN", "BAYBURT", "BİLECİK", "BİNGÖL", "BİTLİS", "BOLU", "BURDUR", "ÇANAKKALE", "ÇANKIRI", "ÇORUM", "DENİZLİ", "DİYARBAKIR", "DÜZCE", "EDİRNE", "ELAZIĞ", "ERZİNCAN", "ERZURUM", "ESKİŞEHİR", "GAZİANTEP", "GİRESUN", "GÜMÜŞHANE", "HAKKARİ", "HATAY", "IĞDIR", "ISPARTA", "KAHRAMANMARAŞ", "KARABÜK", "KARAMAN", "KARS", "KASTAMONU", "KAYSERİ", "KİLİS", "KIRIKKALE", "KIRKLARELİ", "KIRŞEHİR", "KOCAELİ", "KONYA", "KÜTAHYA", "MALATYA", "MANİSA", "MARDİN", "MERSİN", "MUĞLA", "MUŞ", "NEVŞEHİR", "NİĞDE", "ORDU", "OSMANİYE", "RİZE", "SAKARYA", "SAMSUN", "ŞANLIURFA", "SİİRT", "SİNOP", "ŞIRNAK", "SİVAS", "TEKİRDAĞ", "TOKAT", "TRABZON", "TUNCELİ", "UŞAK", "VAN", "YALOVA", "YOZGAT", "ZONGULDAK"
  ];

  final Map<String, List<String>> uyap = {
    'CEZA': ['ASLİYE CEZA MAHKEMESİ', 'AĞIR CEZA MAHKEMESİ', 'SULH CEZA HAKİMLİĞİ', 'ÇOCUK MAHKEMESİ'],
    'HUKUK': ['ASLİYE HUKUK MAHKEMESİ', 'ASLİYE TİCARET MAHKEMESİ', 'AİLE MAHKEMESİ', 'İŞ MAHKEMESİ', 'TÜKETİCİ MAHKEMESİ', 'SULH HUKUK MAHKEMESİ'],
    'İCRA': ['İCRA DAİRESİ'], 'İDARİ YARGI': ['İDARE MAHKEMESİ', 'VERGİ MAHKEMESİ'], 'DİĞER': ['DİĞER MERCİ'],
  };

  void _validateAAUT() {
    if (!widget.isIncome || selType == null || _amountC.text.isEmpty) return;
    double entered = double.tryParse(_amountC.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
    double minFee = calculateAautAmount(selType!, _selectedHours);
    if (entered < minFee && entered > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.orange, content: Text("UYARI: GİRDİĞİNİZ TUTAR AAÜT 2025 ASGARİ TUTARININ (${formatCurrency(minFee)}) ALTINDADIR.")));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.isIncome ? "YENİ KAZANÇ KAYDI" : "YENİ MASRAF KAYDI")), 
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: LayoutBuilder(builder: (context, constraints) => Column(children: [
    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(15)), child: Row(children: [Expanded(child: GestureDetector(onTap: () async { final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime.now()); if (d != null && mounted) setState(() { _selectedDate = d; _isToday = false; }); }, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("İŞLEM TARİHİ", style: TextStyle(fontSize: 12, color: Colors.grey)), Text(DateFormat('dd.MM.yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]))), const Text("BUGÜN", style: TextStyle(fontWeight: FontWeight.w600)), Checkbox(value: _isToday, onChanged: (v) { setState(() { _isToday = v!; if (_isToday) _selectedDate = DateTime.now(); }); })])),
    const SizedBox(height: 16),
    TextField(controller: _clientC, decoration: const InputDecoration(labelText: "MÜVEKKİL AD SOYAD", border: OutlineInputBorder())),
    const SizedBox(height: 12),
    DropdownMenu<String>(width: constraints.maxWidth, label: const Text("ŞEHİR"), enableFilter: true, dropdownMenuEntries: cities.map((c) => DropdownMenuEntry(value: c, label: c)).toList(), onSelected: (v) => setState(() => selCity = v)),
    const SizedBox(height: 12),
    DropdownMenu<String>(width: constraints.maxWidth, label: const Text("YARGI TÜRÜ"), dropdownMenuEntries: uyap.keys.map((t) => DropdownMenuEntry(value: t, label: t)).toList(), onSelected: (v) => setState(() { selJuris = v; selUnit = null; })),
    if (selJuris != null) ...[
      Padding(padding: const EdgeInsets.only(top: 12), child: Row(children: [
        SizedBox(width: 80, child: DropdownButtonFormField<String>(initialValue: selUnitNo, items: List.generate(99, (i) => (i+1).toString()).map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(), onChanged: (v) => setState(() => selUnitNo = v!), decoration: const InputDecoration(labelText: "NO", border: OutlineInputBorder()))),
        const SizedBox(width: 10),
        Expanded(child: DropdownMenu<String>(width: constraints.maxWidth - 90, label: const Text("YARGI BİRİMİ"), enableFilter: true, dropdownMenuEntries: uyap[selJuris]!.map((u) => DropdownMenuEntry(value: u, label: u)).toList(), onSelected: (v) => setState(() => selUnit = v))),
      ])),
    ],
    const SizedBox(height: 12),
    TextField(controller: _caseC, decoration: const InputDecoration(labelText: "DOSYA ESAS NO (ÖRN: 2025/100)", border: OutlineInputBorder())),
    const SizedBox(height: 12),
    if (widget.isIncome) ...[
      DropdownButtonFormField<String>(
        isExpanded: true,
        decoration: const InputDecoration(labelText: "GELİR TÜRÜ (AAÜT 2025)", border: OutlineInputBorder()), 
        items: aaut2025Listesi.keys.map((k) => DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontSize: 10)))).toList(), 
        onChanged: (v) { setState(() { selType = v; _amountC.text = calculateAautAmount(v!, _selectedHours).toStringAsFixed(0); }); }
      ),
      if (selType != null && aautTakipEdenSaat.containsKey(selType))
        Padding(padding: const EdgeInsets.only(top: 12), child: DropdownButtonFormField<int>(initialValue: _selectedHours, decoration: const InputDecoration(labelText: "SAAT SEÇİMİ", border: OutlineInputBorder()), items: List.generate(10, (i) => i + 1).map((h) => DropdownMenuItem(value: h, child: Text("$h SAAT"))).toList(), onChanged: (v) => setState(() { _selectedHours = v!; _amountC.text = calculateAautAmount(selType!, _selectedHours).toStringAsFixed(0); }))),
    ] else ...[
      DropdownButtonFormField<String>(items: ["HARÇ", "YOL", "TEBLİGAT", "BİLİRKİŞİ", "DİĞER"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: (v) => selType = v, decoration: const InputDecoration(labelText: "MASRAF TÜRÜ", border: OutlineInputBorder())),
    ],
    const SizedBox(height: 12),
    TextField(controller: _amountC, keyboardType: TextInputType.number, textInputAction: TextInputAction.done, onSubmitted: (_) => _validateAAUT(), decoration: InputDecoration(labelText: "TUTAR (₺)", helperText: (widget.isIncome && selType != null) ? "(AAÜT: ${formatCurrency(calculateAautAmount(selType!, _selectedHours))})" : null, helperStyle: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold), border: const OutlineInputBorder())),
    const SizedBox(height: 12),
    TextField(controller: _descC, decoration: const InputDecoration(labelText: "NOTLAR", border: OutlineInputBorder())),
    const SizedBox(height: 30),
    SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: widget.isIncome ? Colors.green : Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: () async { 
      if (_clientC.text.isEmpty || _amountC.text.isEmpty) return; 
      String finalType = (widget.isIncome && aautTakipEdenSaat.containsKey(selType)) ? "$_selectedHours SAAT $selType" : (selType ?? "GENEL");
      await CsvService().saveExpense(Expense(id: const Uuid().v4(), date: DateFormat('dd.MM.yyyy').format(_selectedDate), isIncome: widget.isIncome, clientName: _clientC.text.trim().toUpperCase(), city: selCity ?? "BELİRTİLMEDİ", jurisdictionType: selJuris ?? "BELİRTİLMEDİ", fullAuthority: "$selUnitNo. ${selUnit ?? ''}", caseNumber: _caseC.text.toUpperCase(), type: finalType, amount: double.tryParse(_amountC.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0, description: _descC.text.toUpperCase())); 
      if (context.mounted) Navigator.pop(context);
    }, child: const Text("KAYDET", style: TextStyle(fontWeight: FontWeight.bold)))),
  ]))));
}

// --- İŞLEM DETAY ---
class TransactionDetailPage extends StatelessWidget {
  final Expense transaction;
  const TransactionDetailPage({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final String fullCourtText = "${transaction.city} ${transaction.fullAuthority} ${transaction.caseNumber}${transaction.caseNumber.contains('E.') ? '' : ' E.'}";
    return Scaffold(
      appBar: AppBar(title: const Text('İŞLEM DETAYI'), actions: [IconButton(icon: const Icon(Icons.share_rounded), onPressed: () async { 
        final pdf = pw.Document(); final p = await SharedPreferences.getInstance();
        final String lawyerName = p.getString('fullName') ?? ""; 
        final fontData = await rootBundle.load("assets/fonts/Inter_18pt-Regular.ttf"); final ttfFont = pw.Font.ttf(fontData);
        final boldFontData = await rootBundle.load("assets/fonts/Inter_18pt-Bold.ttf"); final ttfBoldFont = pw.Font.ttf(boldFontData);

        pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a5, theme: pw.ThemeData.withFont(base: ttfFont, bold: ttfBoldFont), build: (pw.Context context) => pw.Padding(padding: const pw.EdgeInsets.all(20), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Center(child: pw.Text("MASRAF MAKBUZU", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))), pw.Divider(), pw.SizedBox(height: 20),
          pw.Text("MÜVEKKİL: ${transaction.clientName}"), pw.Text("TARİH: ${transaction.date}"), pw.Text("İŞLEM TÜRÜ: ${transaction.type}"),
          pw.Text("YARGI BİRİMİ: $fullCourtText"),
          pw.SizedBox(height: 20),
          pw.Container(padding: const pw.EdgeInsets.all(10), color: PdfColors.grey200, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("ÖDEME TUTARI:"), pw.Text(formatCurrency(transaction.amount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18))])),
          pw.Spacer(),
          pw.Align(alignment: pw.Alignment.centerRight, child: pw.Column(children: [ pw.Text(lawyerName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)), pw.SizedBox(height: 4), pw.Text("İMZA / KAŞE", style: const pw.TextStyle(fontSize: 10)), ])),
        ])))); await Printing.sharePdf(bytes: await pdf.save(), filename: 'Makbuz_${transaction.date}.pdf');
      })]),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        _row("MÜVEKKİL", transaction.clientName), _row("TÜR", transaction.isIncome ? "GELİR" : "GİDER", c: transaction.isIncome ? Colors.green : Colors.red),
        _row("KATEGORİ", transaction.type), _row("MERCİ", fullCourtText, b: true),
        _row("TUTAR", formatCurrency(transaction.amount), b: true),
        const Spacer(),
        SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF13538A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: () async { 
          final pdf = pw.Document(); final p = await SharedPreferences.getInstance();
          final String lawyerName = p.getString('fullName') ?? ""; final fontData = await rootBundle.load("assets/fonts/Inter_18pt-Regular.ttf"); 
          final ttfFont = pw.Font.ttf(fontData); final boldFontData = await rootBundle.load("assets/fonts/Inter_18pt-Bold.ttf"); final ttfBoldFont = pw.Font.ttf(boldFontData);
          pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a5, theme: pw.ThemeData.withFont(base: ttfFont, bold: ttfBoldFont), build: (pw.Context context) => pw.Padding(padding: const pw.EdgeInsets.all(20), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Center(child: pw.Text("MASRAF MAKBUZU", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))), pw.Divider(), pw.SizedBox(height: 20),
            pw.Text("MÜVEKKİL: ${transaction.clientName}"), pw.Text("TARİH: ${transaction.date}"), pw.Text("İŞLEM TÜRÜ: ${transaction.type}"),
            pw.Text("YARGI BİRİMİ: $fullCourtText"), pw.SizedBox(height: 20),
            pw.Container(padding: const pw.EdgeInsets.all(10), color: PdfColors.grey200, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("ÖDEME TUTARI:"), pw.Text(formatCurrency(transaction.amount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18))])),
            pw.Spacer(),
            pw.Align(alignment: pw.Alignment.centerRight, child: pw.Column(children: [pw.Text(lawyerName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)), pw.SizedBox(height: 4), pw.Text("İMZA / KAŞE", style: const pw.TextStyle(fontSize: 10))])),
          ])))); if (context.mounted) await Printing.sharePdf(bytes: await pdf.save(), filename: 'Makbuz_${transaction.date}.pdf'); 
        }, icon: const Icon(Icons.picture_as_pdf), label: const Text("MAKBUZU PAYLAŞ"))),
      ])),
    );
  }
  Widget _row(String l, String v, {Color? c, bool b = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(fontWeight: FontWeight.w500)), Flexible(child: Text(v, textAlign: TextAlign.right, style: TextStyle(color: c, fontWeight: b ? FontWeight.bold : FontWeight.normal)))]));
}

// --- AYARLAR ---
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _n = TextEditingController(),
      _f = TextEditingController(),
      _e = TextEditingController(),
      _p = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _n.text = p.getString('officeName') ?? "";
        _f.text = p.getString('fullName') ?? "";
        _e.text = p.getString('email') ?? "";
        _p.text = p.getString('phone') ?? "";
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text("PROFİL")),
        // Teknik Not: Ekran klavyesi açıldığında veya içerik uzadığında 
        // taşma hatasını önlemek için SingleChildScrollView eklendi.
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                  controller: _n,
                  decoration: const InputDecoration(
                      labelText: "BÜRO ADI", border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: _f,
                  decoration: const InputDecoration(
                      labelText: "AVUKAT AD SOYAD", border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: _e,
                  decoration: const InputDecoration(
                      labelText: "KURUMSAL E-POSTA", border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: _p,
                  decoration: const InputDecoration(
                      labelText: "İŞ TELEFONU", border: OutlineInputBorder())),
              const SizedBox(height: 24),
              SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                      onPressed: () async {
                        final p = await SharedPreferences.getInstance();
                        await p.setString('officeName', _n.text);
                        await p.setString('fullName', _f.text);
                        await p.setString('email', _e.text);
                        await p.setString('phone', _p.text);
                        // Linter Notu: Asenkron işlem sonrası context güvenliği için 
                        // context.mounted kontrolü eklendi.
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text("DEĞİŞİKLİKLERİ KAYDET"))),
              
              // --- GELİŞTİRİCİ KÜNYESİ (DEVELOPER CREDITS) ---
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF13538A), // Marka mavisi
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Column(
                  children: [
                    Text(
                      "LexFlow APP",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Geliştirici: Sarper Ödev",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Sürüm: 1.00",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}