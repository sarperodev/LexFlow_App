import 'dart:io';
import 'dart:ui'; // Gaussian Blur için
import 'dart:convert';
import 'package:flutter/cupertino.dart'; // iOS widget'ları
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
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

// --- TASARIM SABİTLERİ ---
const Color kBrandBlue = Color(0xFF007AFF); // iOS Mavisi
const double kRadius = 14.0;

// --- RENK YÖNETİMİ (KARANLIK MOD İÇİN) ---
bool isDarkMode(BuildContext context) => MediaQuery.of(context).platformBrightness == Brightness.dark;

Color getBackgroundColor(BuildContext context) => isDarkMode(context) ? Colors.black : const Color(0xFFF2F2F7);
Color getSurfaceColor(BuildContext context) => isDarkMode(context) ? const Color(0xFF1C1C1E) : Colors.white;
Color getTextColor(BuildContext context) => isDarkMode(context) ? Colors.white : Colors.black;
Color getInputColor(BuildContext context) => isDarkMode(context) ? const Color(0xFF2C2C2E) : const Color(0xFFEFEFF4);

// --- 1. ÖZEL WIDGET: BUZLU CAM BAŞLIK (GLASS APP BAR) ---
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final double height;

  const GlassAppBar({super.key, required this.title, this.actions, this.leading, this.height = kToolbarHeight});

  @override
  Widget build(BuildContext context) {
    final bool isDark = isDarkMode(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          color: isDark ? Colors.black.withValues(alpha: 0.75) : Colors.white.withValues(alpha: 0.75),
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: height,
              child: Row(
                children: [
                  leading ?? (Navigator.canPop(context)
                    ? GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.transparent,
                          child: const Icon(CupertinoIcons.back, color: kBrandBlue, size: 28)
                        )
                      )
                    : const SizedBox(width: 10)),
                  Expanded(
                    child: DefaultTextStyle(
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 17, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                      child: Center(child: title),
                    ),
                  ),
                  Row(mainAxisSize: MainAxisSize.min, children: actions ?? [const SizedBox(width: 40)]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  @override
  Size get preferredSize => Size.fromHeight(height);
}

// --- 2. ÖZEL WIDGET: HAVADA DURAN GÖLGELİ BUTON ---
class FloatingIOSButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  const FloatingIOSButton({super.key, required this.text, required this.onPressed, this.color = kBrandBlue, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        color: color,
        borderRadius: BorderRadius.circular(kRadius),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
            Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16, fontFamily: 'Inter')),
          ],
        ),
      ),
    );
  }
}

// --- 3. iOS STİLİ INPUT DEKORASYONU ---
InputDecoration iosInputStyle(BuildContext context, String label, {String? helperText}) {
  final isDark = isDarkMode(context);
  return InputDecoration(
    labelText: label,
    helperText: helperText,
    helperStyle: const TextStyle(color: kBrandBlue, fontWeight: FontWeight.bold),
    filled: true,
    fillColor: getInputColor(context),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBrandBlue, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
    floatingLabelStyle: const TextStyle(color: kBrandBlue),
  );
}

// --- YARDIMCI FONKSİYONLAR: iOS PICKERS (TAMAM BUTONLU) ---
Future<void> showIOSDatePicker(BuildContext context, {
  required DateTime initialDate,
  required Function(DateTime) onDateTimeChanged,
  DateTime? minimumDate,
  DateTime? maximumDate,
}) async {
  final isDark = isDarkMode(context);
  final effectiveMinDate = minimumDate ?? DateTime(1900);
  final effectiveMaxDate = maximumDate ?? DateTime(2100);

  await showCupertinoModalPopup(
    context: context,
    builder: (BuildContext builder) {
      return Container(
        height: 280,
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        child: Column(
          children: [
            // Toolbar
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.bold, color: kBrandBlue)),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
            ),
            // Picker
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initialDate,
                maximumDate: effectiveMaxDate,
                minimumDate: effectiveMinDate,
                onDateTimeChanged: onDateTimeChanged,
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showIOSTimePicker(BuildContext context, {required TimeOfDay initialTime, required Function(TimeOfDay) onTimeChanged}) async {
  final isDark = isDarkMode(context);
  DateTime tempDate = DateTime(2022, 1, 1, initialTime.hour, initialTime.minute);
  await showCupertinoModalPopup(
    context: context,
    builder: (BuildContext builder) {
      return Container(
        height: 280,
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        child: Column(
          children: [
             // Toolbar
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.bold, color: kBrandBlue)),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
            ),
            // Picker
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: tempDate,
                onDateTimeChanged: (val) => onTimeChanged(TimeOfDay.fromDateTime(val)),
              ),
            ),
          ],
        ),
      );
    },
  );
}


// AAÜT 2026 GÜNCEL LİSTESİ
const Map<String, double> aaut2026Listesi = {
  "BÜRODA SÖZLÜ DANIŞMA (İLK BİR SAATE KADAR)": 4000.0,
  "ÇAĞRI ÜZERİNE GİDİLEN YERDE SÖZLÜ DANIŞMA": 7000.0,
  "YAZILI DANIŞMA (İLK BİR SAATE KADAR)": 7000.0,
  "HER TÜRLÜ DİLEKÇE YAZILMASI, İHBARNAME, İHTARNAME, PROTESTO DÜZENLENMESİ": 6000.0,
  "KİRA SÖZLEŞMESİ VE BENZERİ BELGELERİN HAZIRLANMASI": 8000.0,
  "TÜZÜK, YÖNETMELİK, MİRAS SÖZLEŞMESİ, VASİYETNAME, VAKIF SENEDİ VE BENZERİ BELGELERİN HAZIRLANMASI": 32000.0,
  "ŞİRKET ANA SÖZLEŞMESİ, DEVİR VE BİRLEŞME VB. TİCARİ İŞLER": 21000.0,
  "ARABAULUCULUK FAALİYETİNİN ANLAŞMAZLIK İLE SONUÇLANMASI HALİNDE": 8000.0,
  "DURUM BELGELENDİRİLMESİ, ÖDEME TAHSİLİ, BELGE ÖRNEK ÇIKARILMASI": 6000.0,
  "HAKKIN DOĞUMU, TESPİTİ, TESCİLİ, NAKLİ, DEĞİŞTİRİLMESİ, SONA ERDİRİLMESİ VEYA KORUNMASI": 12000.0,
  "İPOTEK TESİSİ VEYA KALDIRILMASI DAHİL OLMAK ÜZERE BİR HAKKIN DOĞUMU VEYA SONA ERDİRİLMESİ İŞLEMLERİ NEDENİYLE SÜREKLİ SÖZLEŞME İLE ÇALIŞILAN BANKALAR, FİNANS KURULUŞLARI VE BENZERLERİNE VERİLEN HER BİR HUKUKİ YARDIM": 3000.0,
  "ŞİRKET KURULUŞU, TACİRLERİN RUHSAT VE VATANDAŞLIK İŞLERİ": 60000.0,
  "VERGİ KOMİSYONLARINDA TAKİP EDİLEN İŞLER": 24000.0,
  "ULUSLARARASI YARGI YERLERİ (DURUŞMASIZ)": 110000.0,
  "ULUSLARARASI YARGI YERLERİ (DURUŞMALI)": 200000.0,
  "İL VE İLÇE TÜKETİCİ HAKEM HEYETLERİ, SEBZE VE MEYVE HAL HAKEM HEYETLERİ NEZDİNDE SUNULACAK HUKUKİ YARDIMLAR": 7000.0,
  "YAPI KOOPERATİFLERİNDE BULUNDURULMASI ZORUNLU SÖZLEŞMELİ AVUKATLARA AYLIK ÖDENECEK ÜCRET": 27000.0,
  "ANONİM ŞİRKETLERDE BULUNDURULMASI ZORUNLU SÖZLEŞMELİ AVUKATLARA AYLIK ÖDENECEK ÜCRET": 45000.0,
  "İHTİYATİ HACİZ, İHTİYATİ TEDBİR, DELİL TESPİTİ (DURUŞMASIZ)": 10000.0,
  "İHTİYATİ HACİZ, İHTİYATİ TEDBİR, DELİL TESPİTİ (DURUŞMALI)": 12500.0,
  "ÖZEL KİŞİ VE TÜZEL KİŞİLERİN SÖZLEŞMELİ AVUKATLARINA ÖDEYECEĞİ ÜCRET": 33000.0,
  "KAMU KURUM VE KURULUŞLARININ SÖZLEŞMELİ AVUKATLARINA ÖDEYECEĞİ ÜCRET": 3000.0,
  "ORTAKLIĞIN GİDERİLMESİ SATIŞ MEMURLUĞU İŞLERİ": 18000.0,
  "ORTAKLIĞIN GİDERİLMESİ VE TAKSİM DAVALARI": 40000.0,
  "VERGİ MAHKEMELERİNDE TAKİP EDİLEN DAVALAR (DURUŞMASIZ)": 30000.0,
  "VERGİ MAHKEMELERİNDE TAKİP EDİLEN DAVALAR (DURUŞMALI)": 40000.0,
  "TÜKETİCİ MAHKEMELERİNDE GÖRÜLEN KREDİ TAKSİTLERİNİN VEYA FAİZİNİN UYARLANMASI DAVALARI": 20000.0,
  "İCRA DAİRELERİNDE YAPILAN TAKİPLER": 9000.0,
  "İCRA MAHKEMELERİNDE TAKİP EDİLEN İŞLER": 11000.0,
  "İCRA MAHKEMELERİNDE DAVA VE DURUŞMALI İŞLER": 18000.0,
  "TAHLİYEYE İLİŞKİN İCRA TAKİPLERİ": 20000.0,
  "İCRA MAHKEMELERİ CEZA İŞLERİ": 15000.0,
  "ÇOCUK TESLİMİ VE ÇOCUKLA KİŞİSEL İLİŞKİ KURULMASINA DAİR İLAM VE TEDBİR KARARLARININ YERİNE GETİRİLMESİNE MUHALEFETTEN KAYNAKLANAN İŞLER": 16000.0,
  "SULH HUKUK MAHKEMELERİNDE TAKİP EDİLEN DAVALAR": 30000.0,
  "SULH CEZA HAKİMLİKLERİ VE İNFAZ HAKİMLİKLERİ": 18000.0,
  "ASLİYE MAHKEMELERİNDE TAKİP EDİLEN DAVALAR": 45000.0,
  "TÜKETİCİ MAHKEMELERİNDE TAKİP EDİLEN DAVALAR": 22500.0,
  "FİKRİ VE SINAİ HAKLAR MAHKEMELERİNDE DAVALAR": 55000.0,
  "AĞIR CEZA MAHKEMELERİNDE TAKİP EDİLEN DAVALAR": 65000.0,
  "ÇOCUK MAHKEMELERİNDE TAKİP EDİLEN DAVALAR": 45000.0,
  "İDARE VE VERGİ MAHKEMELERİNDE TAKİP EDİLEN DAVALAR (DURUŞMASIZ)": 30000.0,
  "İDARE VE VERGİ MAHKEMELERİNDE TAKİP EDİLEN DAVALAR (DURUŞMALI)": 40000.0,
  "ADLİ VE İDARİ YARGI İSTİNAF TAKİPLERİ İLE İLGİLİ İŞLER (İLK DERECEDE GÖRÜLEN DAVALAR)": 35000.0,
  "ADLİ VE İDARİ YARGI İSTİNAF TAKİPLERİ İLE İLGİLİ İŞLER (YALNIZCA BİR DURUŞMASI OLAN İŞLER)": 22000.0,
  "ADLİ VE İDARİ YARGI İSTİNAF TAKİPLERİ İLE İLGİLİ İŞLER (BİRDEN FAZLA DURUŞMASI OLAN VEYA KEŞİF GİBİ SAİR İŞLEMLER BULUNAN İŞLER)": 42000.0,
  "SAYIŞTAYDA GÖRÜLEN HESAP YARGILAMALARI (DURUŞMASIZ)": 34000.0,
  "SAYIŞTAYDA GÖRÜLEN HESAP YARGILAMALARI (DURUŞMALI)": 65000.0,
  "YARGITAYDA İLK DERECEDE GÖRÜLEN DAVALAR": 65000.0,
  "DANIŞTAYDA İLK DERECEDE GÖRÜLEN DAVALAR (DURUŞMASIZ)": 40000.0,
  "DANIŞTAYDA İLK DERECEDE GÖRÜLEN DAVALAR (DURUŞMALI)": 65000.0,
  "UYUŞMAZLIK MAHKEMESİNDEKİ DAVALAR": 40000.0,
  "ANAYASA MAHKEMESİNDE GÖRÜLEN DAVA VE İŞLER (YÜCE DİVAN SIFATI İLE BAKILAN DAVALAR)": 120000.0,
  "ANAYASA MAHKEMESİ BİREYSEL BAŞVURU (DURUŞMASIZ)": 40000.0,
  "ANAYASA MAHKEMESİ BİREYSEL BAŞVURU (DURUŞMALI)": 80000.0,
  "DİĞER DAVA VE İŞLER": 90000.0,
};

// TAKİP EDEN SAAT ÜCRETLERİ (2026 GÜNCEL)
const Map<String, double> aautTakipEdenSaat = {
  "BÜRODA SÖZLÜ DANIŞMA (İLK BİR SAATE KADAR)": 1800.0, 
  "ÇAĞRI ÜZERİNE GİDİLEN YERDE SÖZLÜ DANIŞMA": 3500.0, 
  "YAZILI DANIŞMA (İLK BİR SAATE KADAR)": 3500.0, 
};

double calculateAautAmount(String type, int hours) {
  double base = aaut2026Listesi[type] ?? 0;
  if (aautTakipEdenSaat.containsKey(type) && hours > 1) {
    return base + ((hours - 1) * aautTakipEdenSaat[type]!); 
  }
  return base;
}

String formatCurrency(double amount) {
  return NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2).format(amount);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LexFlowApp());
}

class LexFlowApp extends StatelessWidget {
  const LexFlowApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LexFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: kBrandBlue, brightness: Brightness.light, surface: Colors.white),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(seedColor: kBrandBlue, brightness: Brightness.dark, surface: Colors.black),
      ),
      themeMode: ThemeMode.system, // Sistem temasına göre otomatik geçiş
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
    final isDark = isDarkMode(context);
    return Scaffold(
      extendBodyBehindAppBar: true, 
      backgroundColor: getBackgroundColor(context),
      appBar: GlassAppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset('assets/logo.svg', width: 24, height: 24, colorFilter: const ColorFilter.mode(kBrandBlue, BlendMode.srcIn)),
            const SizedBox(width: 8),
            Text('LexFlow', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5, color: getTextColor(context))),
          ],
        ),
        leading: const SizedBox(), 
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.settings, color: kBrandBlue), 
            onPressed: () async { 
              await Navigator.push(context, CupertinoPageRoute(builder: (context) => const SettingsPage())); 
              _loadInitialData(); 
            }
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 110, 16, 20), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFinancialSummary(),
            const SizedBox(height: 30),
            Text("Hızlı İşlemler", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: getTextColor(context))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildQuickAction(context, "Masraf", CupertinoIcons.minus_circle, false),
                _buildQuickAction(context, "Tahsilat", CupertinoIcons.add_circled, true),
                _buildQuickAction(context, "Analiz", CupertinoIcons.graph_square, false),
                _buildQuickAction(context, "Görevler", CupertinoIcons.check_mark_circled, false),
              ],
            ),
            const SizedBox(height: 20),
            // YENİ: AAÜT Hesaplama Butonu
            GestureDetector(
              onTap: () {
                Navigator.push(context, CupertinoPageRoute(builder: (context) => const AAUCCalculationPage()));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                decoration: BoxDecoration(
                  color: kBrandBlue,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: kBrandBlue.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(CupertinoIcons.doc_text_search, color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text("Asgari Ücret Tarifesi Hesapla", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Son Hareketler", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: getTextColor(context))),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () async { await Navigator.push(context, CupertinoPageRoute(builder: (context) => const AllTransactionsPage())); _refreshExpenses(); }, 
                  child: const Text("Tümü", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))
                ),
              ],
            ),
            const SizedBox(height: 8),
            _recentExpenses.isEmpty
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text("Henüz işlem bulunmuyor.", style: TextStyle(color: Colors.grey))))
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentExpenses.length > 5 ? 5 : _recentExpenses.length,
                  separatorBuilder: (c, i) => Divider(height: 1, indent: 60, color: isDark ? Colors.grey.shade800 : null),
                  itemBuilder: (context, index) => _buildTransactionCard(_recentExpenses[index]),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummary() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kBrandBlue, 
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kBrandBlue.withValues(alpha: 0.4), 
            blurRadius: 20, 
            offset: const Offset(0, 10)
          )
        ],
      ),
      child: Column(children: [
        Text(officeName.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Text(formatCurrency(_totalIncome - _totalExpense), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: -1)),
        const SizedBox(height: 4),
        const Text("Net Bakiye", style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _summaryItem("Gelir", _totalIncome, Colors.white),
          Container(width: 1, height: 30, color: Colors.white24),
          _summaryItem("Gider", _totalExpense, Colors.white.withValues(alpha: 0.85)),
        ])
      ]),
    );
  }

  Widget _summaryItem(String label, double val, Color color) => Column(children: [Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)), Text(formatCurrency(val), style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 16))]);

  Widget _buildTransactionCard(Expense item) {
    final isDark = isDarkMode(context);
    return ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 4),
    onTap: () async { await Navigator.push(context, CupertinoPageRoute(builder: (context) => TransactionDetailPage(transaction: item))); _refreshExpenses(); }, 
    leading: Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: item.isIncome ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1), 
        borderRadius: BorderRadius.circular(14)
      ),
      child: Icon(item.isIncome ? CupertinoIcons.arrow_down_left : CupertinoIcons.arrow_up_right, color: item.isIncome ? Colors.green : Colors.red, size: 22)
    ), 
    title: Text(item.clientName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: getTextColor(context))), 
    subtitle: Text("${item.city} • ${item.type}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)), 
    trailing: Text("${item.isIncome ? '+' : '-'}${formatCurrency(item.amount)}", style: TextStyle(color: item.isIncome ? Colors.green : (isDark ? Colors.white : Colors.black), fontWeight: FontWeight.bold, fontSize: 15))
  );
  }

  Widget _buildQuickAction(BuildContext context, String label, IconData icon, bool isIncomeAction) {
    final isDark = isDarkMode(context);
    return GestureDetector(
    onTap: () async {
      if (label == "Görevler") {
        await Navigator.push(context, CupertinoPageRoute(builder: (context) => const TasksPage()));
      } else if (label == "Analiz") {
        await Navigator.push(context, CupertinoPageRoute(builder: (context) => const FinancialAnalysisPage()));
      } else {
        await Navigator.push(context, CupertinoPageRoute(builder: (context) => TransactionFormPage(isIncome: isIncomeAction)));
      }
      _refreshExpenses();
    },
    child: Column(children: [
      Container(
        height: 64, width: 64, 
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white, 
          borderRadius: BorderRadius.circular(20), 
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))]
        ), 
        child: Icon(icon, color: kBrandBlue, size: 28)
      ), 
      const SizedBox(height: 10), 
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: getTextColor(context)))
    ]),
  );
  }
}

// YENİ: AAÜT Hesaplama Sayfası (GÜNCELLENDİ: Arama ve Liste Entegre Edildi)
class AAUCCalculationPage extends StatefulWidget {
  const AAUCCalculationPage({super.key});

  @override
  State<AAUCCalculationPage> createState() => _AAUCCalculationPageState();
}

class _AAUCCalculationPageState extends State<AAUCCalculationPage> {
  String? _selectedType;
  int _hours = 1;
  double _calculatedAmount = 0;
  String _searchQuery = ""; // Arama sorgusu için değişken

  @override
  Widget build(BuildContext context) {
    final textColor = getTextColor(context);
    // Arama ve liste mantığı:
    final filteredKeys = aaut2026Listesi.keys.where((k) => k.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: getBackgroundColor(context),
      appBar: const GlassAppBar(title: Text("AAÜT Hesaplama")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 110, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: getSurfaceColor(context),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("İşlem Türü Ara ve Seçin", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  
                  // ARAMA INPUTU
                  TextField(
                    decoration: iosInputStyle(context, "Kelime yazın..."), 
                    onChanged: (v) => setState(() => _searchQuery = v) // Her tuş vuruşunda listeyi filtreler
                  ),
                  const SizedBox(height: 15),

                  // FİLTRELENMİŞ LİSTE
                  Container(
                    height: 200,
                    decoration: BoxDecoration(color: getInputColor(context), borderRadius: BorderRadius.circular(12)),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: filteredKeys.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (c, i) {
                        final key = filteredKeys[i];
                        final isSelected = _selectedType == key;
                        return ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          tileColor: isSelected ? kBrandBlue.withValues(alpha: 0.1) : null,
                          title: Text(key, style: TextStyle(fontSize: 13, color: isSelected ? kBrandBlue : textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          onTap: () => setState(() { 
                            _selectedType = key; 
                            _calculatedAmount = calculateAautAmount(key, _hours); 
                          }),
                        );
                      }
                    ),
                  ),

                  if (_selectedType != null && aautTakipEdenSaat.containsKey(_selectedType)) ...[
                    const SizedBox(height: 20),
                    Text("Süre (Saat)", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: getInputColor(context), borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          dropdownColor: getInputColor(context),
                          value: _hours,
                          items: List.generate(10, (i) => i + 1).map((h) => DropdownMenuItem(value: h, child: Text("$h SAAT", style: TextStyle(color: textColor)))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _hours = v!;
                              _calculatedAmount = calculateAautAmount(_selectedType!, _hours);
                            });
                          }
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),
            if (_selectedType != null)
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: kBrandBlue,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: kBrandBlue.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10))]
                ),
                child: Column(
                  children: [
                    const Text("ASGARİ ÜCRET TUTARI", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 10),
                    Text(formatCurrency(_calculatedAmount), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_selectedType!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
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

  // GÖREV SİLME ONAY DİYALOĞU
  Future<void> _confirmDelete(int index, Task task) async {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Uyarı"),
        content: const Text("Bu görevi gerçekten silmek istiyor musunuz?"),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İPTAL", style: TextStyle(color: Colors.blueGrey)),
          ),
          CupertinoDialogAction(
            child: const Text("SİL", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onPressed: () {
              setState(() { _tasks.removeAt(index); });
              _save();
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }


  void _addTask() async {
    final tc = TextEditingController(); 
    DateTime selDate = DateTime.now(); 
    TimeOfDay selTime = TimeOfDay.now();
    
    // iOS Style Modal Sheet for Task Entry
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        final isDark = isDarkMode(ctx);
        return Material(
          type: MaterialType.transparency, // Arka planı şeffaf yap
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                // Klavye açıldığında içeriği yukarı itmek için padding kullanıyoruz.
                padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Yeni Görev Ekle", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: getTextColor(ctx)), textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    // TextField'a autofocus ekleyerek klavyenin hemen açılmasını sağlıyoruz.
                    TextField(controller: tc, autofocus: true, decoration: iosInputStyle(ctx, "Görev / Not")),
                    const SizedBox(height: 16),
                  
                    // Tarih Seçimi
                    GestureDetector(
                      onTap: () {
                        FocusScope.of(ctx).unfocus();
                        // Gelecek tarihleri seçebilmek için maximumDate'i 2100 yılına ayarlıyoruz.
                        showIOSDatePicker(
                          ctx,
                          initialDate: selDate,
                          maximumDate: DateTime(2100), 
                          onDateTimeChanged: (val) => setState(() => selDate = val)
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16), 
                        decoration: BoxDecoration(color: getInputColor(ctx), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(CupertinoIcons.calendar, color: kBrandBlue),
                            Text(DateFormat('dd.MM.yyyy').format(selDate), style: TextStyle(fontWeight: FontWeight.bold, color: getTextColor(ctx))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Saat Seçimi
                    GestureDetector(
                      onTap: () {
                        FocusScope.of(ctx).unfocus();
                        showIOSTimePicker(ctx, initialTime: selTime, onTimeChanged: (val) => setState(() => selTime = val));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16), 
                        decoration: BoxDecoration(color: getInputColor(ctx), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(CupertinoIcons.time, color: kBrandBlue),
                            Text(selTime.format(ctx), style: TextStyle(fontWeight: FontWeight.bold, color: getTextColor(ctx))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            child: const Text("İptal", style: TextStyle(color: Colors.red)),
                            onPressed: () => Navigator.pop(ctx)
                          )
                        ),
                        Expanded(
                          child: FloatingIOSButton(
                            text: "KAYDET", 
                            onPressed: () {
                              if (tc.text.isNotEmpty) { 
                                setState(() { 
                                  _tasks.add(Task(id: const Uuid().v4(), title: tc.text, isDone: false, dateTime: DateTime(selDate.year, selDate.month, selDate.day, selTime.hour, selTime.minute))); 
                                  _tasks.sort((a, b) => a.dateTime.compareTo(b.dateTime)); 
                                }); 
                                _save(); 
                                Navigator.pop(ctx); 
                              } 
                            }
                          )
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    backgroundColor: getBackgroundColor(context),
    appBar: const GlassAppBar(title: Text("Hukuki Görevler")),
    floatingActionButton: FloatingActionButton(backgroundColor: kBrandBlue, onPressed: _addTask, child: const Icon(Icons.add, color: Colors.white)),
    body: Padding(
      padding: const EdgeInsets.only(top: 100),
      child: _tasks.isEmpty ? Center(child: Text("Bekleyen görev bulunmuyor.", style: TextStyle(color: Colors.grey.shade600))) : ListView.separated(
        itemCount: _tasks.length, 
        separatorBuilder: (c,i) => const Divider(height: 1),
        itemBuilder: (context, index) {
        final t = _tasks[index];
        return ListTile(
          leading: Transform.scale(scale: 1.2, child: Checkbox(activeColor: kBrandBlue, shape: const CircleBorder(), value: t.isDone, onChanged: (v) { setState(() { t.isDone = v!; }); _save(); })),
          title: Text(t.title, style: TextStyle(decoration: t.isDone ? TextDecoration.lineThrough : null, color: t.isDone ? Colors.grey : getTextColor(context))),
          subtitle: Text(DateFormat('dd.MM.yyyy - HH:mm').format(t.dateTime), style: TextStyle(color: t.dateTime.isBefore(DateTime.now()) && !t.isDone ? Colors.red : Colors.grey, fontSize: 12)),
          trailing: IconButton(icon: const Icon(CupertinoIcons.trash, color: Colors.red), onPressed: () => _confirmDelete(index, t)),
        );
      }),
    ),
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
  List<String> _chartDates = []; // X ekseni için tarihler
  List<Expense> _rawSortedList = []; // Ham veri
  int _selectedTimeRange = 2; // 0: Hafta, 1: Ay, 2: Yıl (Varsayılan)

  @override void initState() { super.initState(); _loadData(); }

  void _loadData() async {
    final list = await CsvService().getAllExpenses();
    if (list.isEmpty) return;
    // Tarihe göre sırala
    list.sort((a, b) => DateFormat("dd.MM.yyyy").parse(a.date).compareTo(DateFormat("dd.MM.yyyy").parse(b.date)));
    if (mounted) {
      setState(() {
        _rawSortedList = list;
      });
      _process();
    }
  }

  void _process() {
    if (_rawSortedList.isEmpty) return;

    // 1. Filtreleme (Zaman Aralığına Göre)
    DateTime now = DateTime.now();
    DateTime startDate;
    switch (_selectedTimeRange) {
      case 0: startDate = now.subtract(const Duration(days: 7)); break; // 1 Hafta
      case 1: startDate = now.subtract(const Duration(days: 30)); break; // 1 Ay
      case 2: default: startDate = now.subtract(const Duration(days: 365)); break; // 1 Yıl
    }

    List<Expense> filteredList = _rawSortedList.where((e) {
      DateTime dt = DateFormat("dd.MM.yyyy").parse(e.date);
      // Başlangıç tarihinden sonraki verileri al (veya aynı gün)
      return dt.isAfter(startDate.subtract(const Duration(days: 1)));
    }).toList();

    // 2. Pasta Grafik Verisi Hazırla
    Map<String, double> dist = {};
    for (var e in filteredList) {
      String key = "${e.type} (${e.isIncome ? 'GELİR' : 'GİDER'})";
      dist[key] = (dist[key] ?? 0) + e.amount;
    }

    // 3. Çizgi Grafik Verisi Hazırla
    double cumulativeNet = 0;
    List<FlSpot> spots = [];
    List<String> dates = [];
    
    if (filteredList.isNotEmpty) {
       // Eğer filtrelenmiş listede veri varsa kümülatif hesapla
      for (int i = 0; i < filteredList.length; i++) {
        cumulativeNet += filteredList[i].isIncome ? filteredList[i].amount : -filteredList[i].amount;
        spots.add(FlSpot(i.toDouble(), cumulativeNet));
        // Tarihi sadece gün ve ay olarak al (örn: 05.01) yer kazanmak için
        dates.add(filteredList[i].date.substring(0, 5)); 
      }
    } else if (_rawSortedList.isNotEmpty) {
       // Filtre sonucu boşsa ama genelde veri varsa, son durumu 0 noktasında göster
       // Bu durum, seçili aralıkta işlem yoksa grafiğin boş kalmasını engeller.
       spots.add(const FlSpot(0, 0));
       dates.add(DateFormat('dd.MM').format(now));
    }


    if (mounted) setState(() { distribution = dist; _lineSpots = spots; _chartDates = dates; });
  }

  Widget _buildTimeRangeSegment() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: CupertinoSlidingSegmentedControl<int>(
        children: const {
          0: Text('1 Hafta'),
          1: Text('1 Ay'),
          2: Text('1 Yıl'),
        },
        groupValue: _selectedTimeRange,
        onValueChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedTimeRange = value;
            });
            _process();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final textColor = getTextColor(context);
    return Scaffold(
    extendBodyBehindAppBar: true,
    backgroundColor: getBackgroundColor(context),
    appBar: const GlassAppBar(title: Text("Mali Analiz")),
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 110, 20, 20),
      child: Column(children: [
        Text("Gelir/Gider Dağılımı", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 20),
        // 3D Efektli Pasta Grafik Konteyneri
        Container(
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            // Hafif bir gölge ile kabartma efekti
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
               BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white,
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ]
          ),
          child: distribution.isEmpty
            ? Center(child: Text("Bu aralıkta veri yok", style: TextStyle(color: textColor)))
            : PieChart(PieChartData(
                sectionsSpace: 2, // Dilimler arası boşluk
                centerSpaceRadius: 40, // Ortası delik (Donut)
                sections: distribution.entries.map((e) => PieChartSectionData(
                color: e.key.contains('GELİR') ? Colors.green : Colors.red.withValues(alpha: 0.8),
                value: e.value,
                title: e.key.split(' ')[0],
                radius: 65,
                titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                badgeWidget: _Badge(
                  e.key.contains('GELİR') ? CupertinoIcons.arrow_down_left : CupertinoIcons.arrow_up_right,
                  size: 16,
                  borderColor: e.key.contains('GELİR') ? Colors.green : Colors.red,
                ),
                badgePositionPercentageOffset: .98,
              )).toList())),
        ),
        const SizedBox(height: 30),
        const Divider(),
         Text("Net Durum Grafiği", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
         // Zaman Aralığı Seçici
         _buildTimeRangeSegment(),
        SizedBox(
          height: 220,
          width: double.infinity,
          child: _lineSpots.isEmpty
            ? Center(child: Text("Veri yetersiz", style: TextStyle(color: textColor)))
            : LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false), // Izgarayı gizle
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) {
                         // Tooltip'te tarih ve tutarı göster
                         final date = _chartDates[s.x.toInt()];
                         return LineTooltipItem("$date\n${formatCurrency(s.y)}", const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
                      }).toList()
                    )
                  ),
                  titlesData: FlTitlesData(
                    // Sol Eksen (Tutar)
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45, getTitlesWidget: (v, m) => Text(NumberFormat.compact(locale: "tr").format(v), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)))),
                    // Alt Eksen (Tarih)
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1, // Her veri noktası için bir başlık potansiyeli
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          // Sadece geçerli indeksler ve belirli aralıklarla tarih göster (sıkışıklığı önlemek için)
                          if (index >= 0 && index < _chartDates.length) {
                            // Veri yoğunluğuna göre etiket sıklığını ayarla
                            int labelFrequency = (_chartDates.length > 20) ? 4 : (_chartDates.length > 10 ? 2 : 1);
                            if (index % labelFrequency == 0 || index == _chartDates.length - 1) {
                               return Padding(
                                 padding: const EdgeInsets.only(top: 6.0),
                                 child: Text(_chartDates[index], style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
                               );
                            }
                          }
                          return const SizedBox();
                        },
                      )
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _lineSpots,
                      isCurved: true,
                      color: kBrandBlue,
                      barWidth: 3,
                      dotData: const FlDotData(show: false), // Noktaları gizle, sadece çizgiyi göster
                      belowBarData: BarAreaData(show: true, color: kBrandBlue.withValues(alpha: 0.15))
                    )
                  ]
                )
              ),
        ),
        const SizedBox(height: 30),
        ...distribution.entries.map((e) => ListTile(title: Text(e.key, style: TextStyle(color: textColor)), trailing: Text(formatCurrency(e.value), style: TextStyle(fontWeight: FontWeight.bold, color: e.key.contains('GELİR') ? Colors.green : Colors.red)))),
      ])
    )
  );
  }
}
// Pasta grafik üzerindeki ikonlar için yardımcı widget
class _Badge extends StatelessWidget {
  const _Badge(this.icon, {required this.size, required this.borderColor});
  final IconData icon;
  final double size;
  final Color borderColor;
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: PieChart.defaultDuration,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), offset: const Offset(1, 1), blurRadius: 2), // withOpacity yerine withValues kullanıldı
        ],
      ),
      padding: EdgeInsets.all(size * .15),
      child: Center(child: Icon(icon, size: size * 0.6, color: borderColor)),
    );
  }
}


// --- TÜM İŞLEMLER ---
class AllTransactionsPage extends StatefulWidget {
  const AllTransactionsPage({super.key});
  @override
  State<AllTransactionsPage> createState() => _AllTransactionsPageState();
}

class _AllTransactionsPageState extends State<AllTransactionsPage> {
  List<Expense> allEx = [];
  List<Expense> filteredEx = [];
  String query = "";
  String natureFilter = "Tümü";
  DateTimeRange? dateRange;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final res = await CsvService().getAllExpenses();
    if (mounted) {
      setState(() {
        allEx = res;
        _apply();
      });
    }
  }

  void _apply() {
    List<Expense> temp = List.from(allEx);
    if (natureFilter == "Gelir") temp = temp.where((e) => e.isIncome).toList();
    if (natureFilter == "Gider") temp = temp.where((e) => !e.isIncome).toList();
    if (query.isNotEmpty) {
      temp = temp.where((e) => e.clientName.toLowerCase().contains(query.toLowerCase())).toList();
    }
    if (dateRange != null) {
      temp = temp.where((e) {
        DateTime dt = DateFormat("dd.MM.yyyy").parse(e.date);
        return dt.isAfter(dateRange!.start.subtract(const Duration(days: 1))) &&
            dt.isBefore(dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }
    if (mounted) {
      setState(() {
        filteredEx = temp.reversed.toList();
      });
    }
  }

  void _deleteSelected() async {
    bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
            title: const Text("Kayıtları Sil"),
            content: Text("${_selectedIds.length} adet kayıt silinecektir."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("İptal")),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Sil"))
            ]));
    if (confirm == true) {
      await CsvService().deleteExpenses(_selectedIds.toList());
      if (mounted) {
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
        _load();
      }
    }
  }

  // --- IMPORT / EXPORT MANTIKLARI ---
  Future<void> _importData() async {
    Map<String, dynamic>? data = await CsvService().importFromCsv();
    if (data == null) return;
    // Veri türünden bağımsız olarak kullanıcıya seçenek sun
    if (!mounted) return;
    _showImportChoiceDialog(data);
  }

  // YENİ: İçe Aktarma Seçim Diyaloğu
  void _showImportChoiceDialog(Map<String, dynamic> data) {
    // isDark değişkeni kaldırıldı
    int expenseCount = (data['expenses'] as List? ?? []).length;
    bool isFullBackup = data['userName'] != null;

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Yedek Dosyası Algılandı"),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            children: [
              Text("Bu dosya $expenseCount adet finansal işlem ${isFullBackup ? 've profil/görev verileri ' : ''}içeriyor."),
              const SizedBox(height: 12),
              const Text("Nasıl devam etmek istersiniz?", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal"),
          ),
          // SEÇENEK 1: BİRLEŞTİR (Merge) - Önerilen, Güvenli
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(ctx);
              _performExpenseMerge(data);
            },
            // Mavi renk (standart aksiyon)
            child: const Text("BİRLEŞTİR (Önerilen)"),
          ),
           // SEÇENEK 2: SIFIRLA & YÜKLE (Full Restore) - Yıkıcı
          CupertinoDialogAction(
            isDestructiveAction: true, // Kırmızı renk
            onPressed: () {
              Navigator.pop(ctx);
              // Tam yedek değilse bile sadece finansal verileri sıfırlayıp yükler
              _performFullRestore(data);
            },
            child: const Text("SIFIRLA & YÜKLE (Dikkat)"),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Dışa Aktarma Seçeneği', style: TextStyle(color: kBrandBlue, fontWeight: FontWeight.bold)),
          children: [
            SimpleDialogOption(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              child: const Row(children: [Icon(CupertinoIcons.table_fill, color: Colors.green), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Excel Raporu", style: TextStyle(fontWeight: FontWeight.bold)), Text("Finansal veriler.", style: TextStyle(fontSize: 12, color: Colors.grey))]))]),
              onPressed: () { Navigator.pop(context); _performExport(isBackup: false); },
            ),
            const Divider(),
            SimpleDialogOption(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              child: const Row(children: [Icon(CupertinoIcons.cloud_upload_fill, color: kBrandBlue), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Tam Sistem Yedeği", style: TextStyle(fontWeight: FontWeight.bold)), Text("Profil ve Görevler dahil.", style: TextStyle(fontSize: 12, color: Colors.grey))]))]),
              onPressed: () { Navigator.pop(context); _performExport(isBackup: true); },
            ),
          ],
        );
      },
    );
  }

  Future<void> _performExport({required bool isBackup}) async {
    final prefs = await SharedPreferences.getInstance();
    List<Expense> freshExpenses = await CsvService().getAllExpenses();
    if (freshExpenses.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veri yok.")));
      }
      return;
    }
    String userName = prefs.getString('fullName') ?? "";
    String lawFirmName = prefs.getString('officeName') ?? "";
    String email = prefs.getString('email') ?? "";
    String phone = prefs.getString('phone') ?? "";
    List<Map<String, dynamic>> tasksJson = [];
    String? tasksString = prefs.getString('tasks');
    if (tasksString != null) {
      List<dynamic> decoded = jsonDecode(tasksString);
      tasksJson = decoded.map((e) => e as Map<String, dynamic>).toList();
    }
    await CsvService().exportToCsv(expenses: freshExpenses, userName: userName, lawFirmName: lawFirmName, email: email, phone: phone, tasksJson: tasksJson, isFullBackup: isBackup);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isBackup ? "Tam Yedek Alındı." : "Rapor Oluşturuldu."), backgroundColor: Colors.green));
  }

  Future<void> _performFullRestore(Map<String, dynamic> data) async {
    // CsvService().applyImportedData(data) fonksiyonunun mevcut verileri silip
    // yenilerini eklediğini varsayıyoruz (Sıfırlama mantığı).
    await CsvService().applyImportedData(data);
    if (mounted) {
      _load();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sistem tamamen geri yüklendi."), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _performExpenseMerge(Map<String, dynamic> data) async {
    List<Expense> newItems = List<Expense>.from(data['expenses']);
    // CsvService().mergeExpenses(newItems) fonksiyonunun ID kontrolü yaparak
    // sadece yeni kayıtları eklediğini varsayıyoruz (Birleştirme mantığı).
    await CsvService().mergeExpenses(newItems);
    if (mounted) {
      _load();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yeni kayıtlar birleştirildi."), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: getBackgroundColor(context),
        appBar: GlassAppBar(
          title: Text(_isSelectionMode ? "${_selectedIds.length} Seçildi" : "Tüm İşlemler"),
          leading: _isSelectionMode ? IconButton(icon: const Icon(CupertinoIcons.xmark, color: Colors.black), onPressed: () => setState(() { _isSelectionMode = false; _selectedIds.clear(); })) : null,
          actions: [
            if (_isSelectionMode)
              IconButton(icon: const Icon(CupertinoIcons.trash, color: Colors.red), onPressed: _deleteSelected),
            if (!_isSelectionMode)
              IconButton(icon: const Icon(CupertinoIcons.cloud_upload, color: kBrandBlue), onPressed: () {
                 showCupertinoModalPopup(context: context, builder: (ctx) => CupertinoActionSheet(
                   actions: [
                     CupertinoActionSheetAction(onPressed: () { Navigator.pop(ctx); _exportData(); }, child: const Text("Dışa Aktar")),
                     CupertinoActionSheetAction(onPressed: () { Navigator.pop(ctx); _importData(); }, child: const Text("İçe Aktar")),
                   ],
                   cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), isDestructiveAction: true, child: const Text("İptal")),
                 ));
              })
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.only(top: 100),
          child: Column(children: [
            if (!_isSelectionMode)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    TextField(decoration: iosInputStyle(context, "Müvekkil Ara...", helperText: null), onChanged: (v) { query = v; _apply(); }),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          CupertinoButton(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: isDarkMode(context) ? Colors.grey.shade800 : Colors.grey.shade200, borderRadius: BorderRadius.circular(20), onPressed: () async { final res = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (res != null && mounted) { setState(() { dateRange = res; _apply(); }); } }, child: Text("Tarih Aralığı", style: TextStyle(color: isDarkMode(context) ? Colors.white : Colors.black, fontSize: 13))),
                          const SizedBox(width: 8),
                          FilterChip(label: const Text("Gelir"), selected: natureFilter == "Gelir", onSelected: (s) { natureFilter = s ? "Gelir" : "Tümü"; _apply(); }),
                          const SizedBox(width: 8),
                          FilterChip(label: const Text("Gider"), selected: natureFilter == "Gider", onSelected: (s) { natureFilter = s ? "Gider" : "Tümü"; _apply(); }),
                        ]))
                  ])),
            Expanded(
                child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredEx.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = filteredEx[index];
                      // YENİ: Renkli Kutu İkonlu ListTile (Tüm İşlemler Sayfası İçin)
                      return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          onLongPress: () { setState(() { _isSelectionMode = true; _selectedIds.add(item.id); }); },
                          onTap: () {
                            if (_isSelectionMode) {
                              setState(() { if (_selectedIds.contains(item.id)) { _selectedIds.remove(item.id); if (_selectedIds.isEmpty) _isSelectionMode = false; } else { _selectedIds.add(item.id); } });
                            } else {
                              Navigator.push(context, CupertinoPageRoute(builder: (context) => TransactionDetailPage(transaction: item)));
                            }
                          },
                          leading: _isSelectionMode
                              ? Icon(_selectedIds.contains(item.id) ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle, color: kBrandBlue)
                              : Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(
                                    color: item.isIncome ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14)
                                  ),
                                  child: Icon(item.isIncome ? CupertinoIcons.arrow_down_left : CupertinoIcons.arrow_up_right, color: item.isIncome ? Colors.green : Colors.red, size: 22)
                                ),
                          title: Text(item.clientName, style: TextStyle(fontWeight: FontWeight.w600, color: getTextColor(context))),
                          subtitle: Text(item.date, style: TextStyle(color: Colors.grey.shade600)),
                          trailing: Text("${item.isIncome ? '+' : '-'}${formatCurrency(item.amount)}", style: TextStyle(color: item.isIncome ? Colors.green : (isDarkMode(context) ? Colors.white : Colors.black), fontWeight: FontWeight.bold)));
                    }))
          ]),
        ),
      );
}

// --- KAYIT SEÇİMİ (EXPORT SAYFASI) ---
class ExportSelectionPage extends StatefulWidget {
  const ExportSelectionPage({super.key});
  @override
  State<ExportSelectionPage> createState() => _ExportSelectionPageState();
}

class _ExportSelectionPageState extends State<ExportSelectionPage> {
  // Eski logic korundu, sadece AppBar güncellendi.
  List<Expense> all = []; List<Expense> filtered = []; final Set<String> selectedIds = {};
  @override void initState() { super.initState(); _load(); }
  void _load() async { final res = await CsvService().getAllExpenses(); if (mounted) setState(() { all = res; filtered = res; }); }
  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    backgroundColor: getBackgroundColor(context),
    appBar: const GlassAppBar(title: Text("Kayıt Seçimi")),
    body: Padding(
      padding: const EdgeInsets.fromLTRB(20, 110, 20, 20),
      child: Column(children: [
        TextField(decoration: iosInputStyle(context, "Ara..."), onChanged: (q) => setState(() { filtered = all.where((e) => e.clientName.toLowerCase().contains(q.toLowerCase())).toList(); })),
        CheckboxListTile(title: Text("Hepsini Seç", style: TextStyle(fontWeight: FontWeight.bold, color: getTextColor(context))), value: filtered.isNotEmpty && selectedIds.length == filtered.length, onChanged: (v) { setState(() { if (v!) { selectedIds.addAll(filtered.map((e) => e.id)); } else { selectedIds.clear(); } }); }),
        const Divider(),
        Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder: (context, index) { final item = filtered[index]; return CheckboxListTile(title: Text(item.clientName, style: TextStyle(color: getTextColor(context))), subtitle: Text("${item.date} - ${item.type}"), value: selectedIds.contains(item.id), onChanged: (v) { setState(() { if (v!) { selectedIds.add(item.id); } else { selectedIds.remove(item.id); } }); }); })),
        FloatingIOSButton(text: "DIŞARI AKTAR", onPressed: selectedIds.isEmpty ? null : () async {
          // ... Eski export mantığı aynen burada ...
           final records = all.where((e) => selectedIds.contains(e.id)).toList();
            List<List<dynamic>> csvData = [['ID', 'Tarih', 'IsIncome', 'Client', 'City', 'Yargi Turu', 'Tam Merci', 'Dosya No', 'Tur', 'Tutar', 'Aciklama']];
            for (var r in records) { csvData.add(r.toCsvRow()); }
            String csvString = const ListToCsvConverter().convert(csvData);
            if (kIsWeb) {
              final bytes = utf8.encode(csvString); final blob = html.Blob([bytes]); final url = html.Url.createObjectUrlFromBlob(blob);
              html.AnchorElement(href: url)..setAttribute("download", "LexFlow_Yedek_${DateTime.now().millisecondsSinceEpoch}.csv")..click(); html.Url.revokeObjectUrl(url); if (context.mounted) Navigator.pop(context);
            } else {
              String? path = await FilePicker.platform.getDirectoryPath(); if (path == null || !mounted) return;
              final file = File('$path/LexFlow_Yedek_${DateTime.now().millisecondsSinceEpoch}.csv'); await file.writeAsString(csvString);
              if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("DOSYA KAYDEDİLDİ: ${file.path}"))); Navigator.pop(context); }
            }
        })
      ]),
    ));
}

// --- İŞLEM FORMU (TAMAMEN iOS STYLE & TAM ŞEHİR LİSTESİ) ---
class TransactionFormPage extends StatefulWidget {
  final bool isIncome;
  const TransactionFormPage({super.key, required this.isIncome});
  @override
  State<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends State<TransactionFormPage> {
  final _clientC = TextEditingController(); final _caseC = TextEditingController(); final _amountC = TextEditingController(); final _descC = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? selCity, selJuris, selUnit, selType; String selUnitNo = "1";
  int _selectedHours = 1;

  final List<String> cities = [
    "ADANA", "ADIYAMAN", "AFYONKARAHİSAR", "AĞRI", "AKSARAY", "AMASYA", "ANKARA", "ANTALYA", "ARDAHAN", "ARTVİN", "AYDIN",
    "BALIKESİR", "BARTIN", "BATMAN", "BAYBURT", "BİLECİK", "BİNGÖL", "BİTLİS", "BOLU", "BURDUR", "BURSA",
    "ÇANAKKALE", "ÇANKIRI", "ÇORUM",
    "DENİZLİ", "DİYARBAKIR", "DÜZCE",
    "EDİRNE", "ELAZIĞ", "ERZİNCAN", "ERZURUM", "ESKİŞEHİR",
    "GAZİANTEP", "GİRESUN", "GÜMÜŞHANE",
    "HAKKARİ", "HATAY",
    "IĞDIR", "ISPARTA", "İSTANBUL", "İZMİR",
    "KAHRAMANMARAŞ", "KARABÜK", "KARAMAN", "KARS", "KASTAMONU", "KAYSERİ", "KIRIKKALE", "KIRKLARELİ", "KIRŞEHİR", "KİLİS", "KOCAELİ", "KONYA", "KÜTAHYA",
    "MALATYA", "MANİSA", "MARDİN", "MERSİN", "MUĞLA", "MUŞ",
    "NEVŞEHİR", "NİĞDE",
    "ORDU", "OSMANİYE",
    "RİZE",
    "SAKARYA", "SAMSUN", "SİİRT", "SİNOP", "SİVAS",
    "ŞANLIURFA", "ŞIRNAK",
    "TEKİRDAĞ", "TOKAT", "TRABZON", "TUNCELİ",
    "UŞAK",
    "VAN",
    "YALOVA", "YOZGAT",
    "ZONGULDAK",
    "DİĞER"
  ];

  final Map<String, List<String>> uyap = {
    'CEZA': ['ASLİYE CEZA MAHKEMESİ', 'AĞIR CEZA MAHKEMESİ', 'SULH CEZA HAKİMLİĞİ', 'ÇOCUK MAHKEMESİ'],
    'HUKUK': ['ASLİYE HUKUK MAHKEMESİ', 'ASLİYE TİCARET MAHKEMESİ', 'AİLE MAHKEMESİ', 'İŞ MAHKEMESİ', 'TÜKETİCİ MAHKEMESİ', 'SULH HUKUK MAHKEMESİ'],
    'İCRA': ['İCRA DAİRESİ'],
    'İDARİ YARGI': ['İDARE MAHKEMESİ', 'VERGİ MAHKEMESİ'],
    'DİĞER': ['DİĞER MERCİ']
  };

  void _validateAAUT() {
    if (!widget.isIncome || selType == null || _amountC.text.isEmpty) {
      return;
    }
    double entered = double.tryParse(_amountC.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
    double minFee = calculateAautAmount(selType!, _selectedHours);
    if (entered < minFee && entered > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.orange, content: Text("UYARI: ASGARİ TUTAR (${formatCurrency(minFee)}) ALTINDASINIZ.")));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    backgroundColor: getBackgroundColor(context),
    appBar: GlassAppBar(title: Text(widget.isIncome ? "Yeni Gelir" : "Yeni Gider")),
    body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 110, 20, 40), child: LayoutBuilder(builder: (context, constraints) => Column(children: [
    
    // iOS DATE PICKER
    GestureDetector(
      onTap: () => showIOSDatePicker(context, initialDate: _selectedDate, onDateTimeChanged: (d) => setState(() => _selectedDate = d)),
      child: Container(
        padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: getInputColor(context), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("İşlem Tarihi", style: TextStyle(color: Colors.grey)), Text(DateFormat('dd.MM.yyyy').format(_selectedDate), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: getTextColor(context)))])
      ),
    ),
    const SizedBox(height: 16),
    TextField(controller: _clientC, decoration: iosInputStyle(context, "Müvekkil Adı")),
    const SizedBox(height: 12),
    // Şehir Dropdown (iOS görünümlü)
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: getInputColor(context), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, dropdownColor: getInputColor(context), hint: const Text("Şehir"), value: selCity, items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: getTextColor(context))))).toList(), onChanged: (v) => setState(() => selCity = v))),
    ),
    const SizedBox(height: 12),
    // Yargı Türü Dropdown
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: getInputColor(context), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, dropdownColor: getInputColor(context), hint: const Text("Yargı Türü"), value: selJuris, items: uyap.keys.map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(color: getTextColor(context))))).toList(), onChanged: (v) => setState(() { selJuris = v; selUnit = null; }))),
    ),
    if (selJuris != null) ...[
      const SizedBox(height: 12),
      Row(children: [
        Container(
          width: 80, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: getInputColor(context), borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(dropdownColor: getInputColor(context), value: selUnitNo, items: List.generate(99, (i) => (i+1).toString()).map((n) => DropdownMenuItem(value: n, child: Text(n, style: TextStyle(color: getTextColor(context))))).toList(), onChanged: (v) => setState(() => selUnitNo = v!))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: getInputColor(context), borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, dropdownColor: getInputColor(context), hint: const Text("Birim"), value: selUnit, items: uyap[selJuris]!.map((u) => DropdownMenuItem(value: u, child: Text(u, style: TextStyle(color: getTextColor(context))))).toList(), onChanged: (v) => setState(() => selUnit = v))),
        )),
      ]),
    ],
    const SizedBox(height: 12),
    TextField(controller: _caseC, decoration: iosInputStyle(context, "Dosya No (2025/123)")),
    const SizedBox(height: 12),
    if (widget.isIncome) ...[
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: getInputColor(context), borderRadius: BorderRadius.circular(12)),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, dropdownColor: getInputColor(context), hint: const Text("Gelir Türü"), value: selType, items: aaut2026Listesi.keys.map((k) => DropdownMenuItem(value: k, child: Text(k, style: TextStyle(fontSize: 10, color: getTextColor(context))))).toList(), onChanged: (v) { setState(() { selType = v; _amountC.text = calculateAautAmount(v!, _selectedHours).toStringAsFixed(0); }); })),
      ),
      if (selType != null && aautTakipEdenSaat.containsKey(selType)) ...[
        const SizedBox(height: 12),
         Container(
          padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: getInputColor(context), borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(child: DropdownButton<int>(isExpanded: true, dropdownColor: getInputColor(context), value: _selectedHours, items: List.generate(10, (i) => i+1).map((h) => DropdownMenuItem(value: h, child: Text("$h SAAT", style: TextStyle(color: getTextColor(context))))).toList(), onChanged: (v) => setState(() { _selectedHours = v!; _amountC.text = calculateAautAmount(selType!, _selectedHours).toStringAsFixed(0); }))),
        ),
      ]
    ] else ...[
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: getInputColor(context), borderRadius: BorderRadius.circular(12)),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, dropdownColor: getInputColor(context), hint: const Text("Masraf Türü"), value: selType, items: ["HARÇ", "YOL", "TEBLİGAT", "BİLİRKİŞİ", "DİĞER"].map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(color: getTextColor(context))))).toList(), onChanged: (v) => setState(() => selType = v))),
      ),
    ],
    const SizedBox(height: 12),
    TextField(
      controller: _amountC, 
      keyboardType: TextInputType.number, 
      onEditingComplete: _validateAAUT,
      decoration: iosInputStyle(context, "Tutar (₺)", helperText: (widget.isIncome && selType != null) ? "AAÜT: ${formatCurrency(calculateAautAmount(selType!, _selectedHours))}" : null)
    ),
    const SizedBox(height: 12),
    TextField(controller: _descC, decoration: iosInputStyle(context, "Notlar")),
    const SizedBox(height: 40),
    FloatingIOSButton(
      text: "KAYDET", 
      color: widget.isIncome ? Colors.green : Colors.red,
      onPressed: () async { 
      if (_clientC.text.isEmpty || _amountC.text.isEmpty) {
        return;
      } 
      String finalType = (widget.isIncome && aautTakipEdenSaat.containsKey(selType)) ? "$_selectedHours SAAT $selType" : (selType ?? "GENEL");
      await CsvService().saveExpense(Expense(id: const Uuid().v4(), date: DateFormat('dd.MM.yyyy').format(_selectedDate), isIncome: widget.isIncome, clientName: _clientC.text.trim().toUpperCase(), city: selCity ?? "BELİRTİLMEDİ", jurisdictionType: selJuris ?? "BELİRTİLMEDİ", fullAuthority: "$selUnitNo. ${selUnit ?? ''}", caseNumber: _caseC.text.toUpperCase(), type: finalType, amount: double.tryParse(_amountC.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0, description: _descC.text.toUpperCase())); 
      if (context.mounted) {
        Navigator.pop(context);
      }
    }),
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
      extendBodyBehindAppBar: true,
      backgroundColor: getBackgroundColor(context),
      appBar: const GlassAppBar(title: Text("Detay")),
      body: Padding(padding: const EdgeInsets.fromLTRB(20, 110, 20, 20), child: Column(children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: getSurfaceColor(context), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))]),
          child: Column(children: [
            Text(transaction.date, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            Text(formatCurrency(transaction.amount), style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: transaction.isIncome ? Colors.green : Colors.red)),
            const SizedBox(height: 20),
            const Divider(),
            _row(context, "Müvekkil", transaction.clientName),
            _row(context, "Tür", transaction.type),
            _row(context, "Merci", fullCourtText),
            _row(context, "Açıklama", transaction.description),
          ]),
        ),
        const Spacer(),
        FloatingIOSButton(text: "MAKBUZ PAYLAŞ", icon: CupertinoIcons.share, onPressed: () async {
           final pdf = pw.Document(); final p = await SharedPreferences.getInstance();
           final String lawyerName = p.getString('fullName') ?? ""; 
           final fontData = await rootBundle.load("assets/fonts/Inter_18pt-Regular.ttf"); final ttfFont = pw.Font.ttf(fontData);
           pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a5, theme: pw.ThemeData.withFont(base: ttfFont), build: (pw.Context context) => pw.Center(child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
             pw.Text("MASRAF MAKBUZU", style: const pw.TextStyle(fontSize: 20)),
             pw.SizedBox(height: 20),
             pw.Text("Avukat: $lawyerName"), 
             pw.Text("Tutar: ${formatCurrency(transaction.amount)}")
           ]))));
           await Printing.sharePdf(bytes: await pdf.save(), filename: 'Makbuz.pdf');
        }),
      ])),
    );
  }
  Widget _row(BuildContext context, String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(k, style: const TextStyle(color: Colors.grey)), Flexible(child: Text(v, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, color: getTextColor(context))))]));
}

// --- AYARLAR ---
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _n = TextEditingController(), _f = TextEditingController(), _e = TextEditingController(), _p = TextEditingController();
  @override void initState() { super.initState(); _load(); }
  void _load() async { final p = await SharedPreferences.getInstance(); setState(() { _n.text = p.getString('officeName') ?? ""; _f.text = p.getString('fullName') ?? ""; _e.text = p.getString('email') ?? ""; _p.text = p.getString('phone') ?? ""; }); }

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: getBackgroundColor(context),
        appBar: const GlassAppBar(title: Text("Profil")),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 110, 20, 20),
          child: Column(
            children: [
              TextField(controller: _n, decoration: iosInputStyle(context, "Büro Adı")),
              const SizedBox(height: 12),
              TextField(controller: _f, decoration: iosInputStyle(context, "Ad Soyad")),
              const SizedBox(height: 12),
              TextField(controller: _e, decoration: iosInputStyle(context, "E-Posta")),
              const SizedBox(height: 12),
              TextField(controller: _p, decoration: iosInputStyle(context, "Telefon")),
              const SizedBox(height: 30),
              FloatingIOSButton(text: "KAYDET", onPressed: () async {
                final p = await SharedPreferences.getInstance();
                await p.setString('officeName', _n.text); await p.setString('fullName', _f.text); await p.setString('email', _e.text); await p.setString('phone', _p.text);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }),
              const SizedBox(height: 20),
              CupertinoButton(child: const Text("Kullanım Kılavuzu"), onPressed: () => Navigator.push(context, CupertinoPageRoute(builder: (context) => const UsageGuidePage()))),
              const SizedBox(height: 30),
              // YENİ: Geliştirici ve Sürüm Bilgi Kutusu
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kBrandBlue,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: kBrandBlue.withValues(alpha: 0.35),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  children: const [
                    Text("LexFlow APP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 0.5)),
                    SizedBox(height: 8),
                    Text("Geliştirici: Av. Sarper ÖDEV", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                    SizedBox(height: 4),
                    Text("Uygulama Sürümü: v1.02", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class UsageGuidePage extends StatelessWidget {
  const UsageGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textColor = getTextColor(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: getBackgroundColor(context),
      appBar: const GlassAppBar(title: Text("Yardım")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 110, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header("LexFlow Platform Rehberi"),
            _paragraph("LexFlow, hem Android cihazlarda (APK) hem de tarayıcılarda (Web/PWA) çalışan hibrit bir yazılımdır.", textColor),
            const Divider(height: 30),
            
            _header("1. Android vs. Web Farkları"),
            _bullet("Veri Kaydı (Android):", "Veriler telefon hafızasında fiziksel dosya olarak tutulur. Uygulama silinmedikçe kaybolmaz.", textColor),
            _bullet("Veri Kaydı (Web/iOS):", "Veriler tarayıcının 'Local Storage' alanında tutulur. Tarayıcı geçmişi silinirse veriler gidebilir.", textColor),
            _bullet("Yedekleme:", "Android'de klasöre, Web'de 'İndirilenler' klasörüne kaydedilir.", textColor),
            
            const Divider(height: 30),
            _header("2. Web (iPhone/iPad) İçin Altın Kurallar"),
            _subHeader("A. Kurulum (PWA)", textColor),
            _paragraph("Safari'de 'Paylaş > Ana Ekrana Ekle' diyerek uygulamayı yükleyin. Bu, verileri daha güvenli bir alanda tutar.", textColor),
            _subHeader("B. Güvenlik Uyarısı ⚠️", textColor),
            _paragraph("ASLA 'Gizli Sekme' (Private Tab) kullanmayın. Sekme kapandığı an tüm veriler silinir.", textColor),
            _subHeader("C. Haftalık Sigorta", textColor),
            _paragraph("Her hafta 'Tüm İşlemler > Dışa Aktar' butonu ile verilerinizi yedekleyip iCloud/Drive'a atın.", textColor),

            const Divider(height: 30),
            _header("3. Cihazlar Arası Transfer"),
            _paragraph("Veriler bulutta değil, cihazınızda saklanır. Bilgisayardan telefona geçmek için 'Dışa Aktar' ve 'İçe Aktar' menülerini kullanabilirsiniz.", textColor),
          ],
        ),
      ),
    );
  }

  Widget _header(String text) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kBrandBlue)));
  
  Widget _subHeader(String text, Color color) => Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color)));
  
  Widget _paragraph(String text, Color color) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: TextStyle(fontSize: 14, height: 1.5, color: color)));
  
  Widget _bullet(String title, String text, Color color) => Padding(padding: const EdgeInsets.only(bottom: 6), child: RichText(text: TextSpan(style: TextStyle(color: color, fontSize: 14, height: 1.4), children: [TextSpan(text: "• $title ", style: const TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: text)])));
}