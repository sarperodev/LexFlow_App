class Expense {
  final String id;
  final String date;
  final bool isIncome; 
  final String clientName; 
  final String city; 
  final String jurisdictionType; 
  final String fullAuthority;    
  final String caseNumber;       
  final String type;             
  final double amount;           
  final String description;      

  Expense({
    required this.id,
    required this.date,
    required this.isIncome,
    required this.clientName,
    required this.city,
    required this.jurisdictionType,
    required this.fullAuthority,
    required this.caseNumber,
    required this.type,
    required this.amount,
    required this.description,
  });

  List<dynamic> toCsvRow() {
    return [id, date, isIncome.toString(), clientName, city, jurisdictionType, fullAuthority, caseNumber, type, amount, description];
  }

  factory Expense.fromCsvRow(List<dynamic> row) {
    return Expense(
      id: row[0].toString(),
      date: row[1].toString(),
      isIncome: row[2].toString().toLowerCase() == 'true',
      clientName: row.length > 3 ? row[3].toString() : "Belirtilmedi",
      city: row.length > 4 ? row[4].toString() : "Belirtilmedi",
      jurisdictionType: row.length > 5 ? row[5].toString() : "Belirtilmedi",
      fullAuthority: row.length > 6 ? row[6].toString() : "Belirtilmedi",
      caseNumber: row.length > 7 ? row[7].toString() : "0000/000",
      type: row.length > 8 ? row[8].toString() : "Diğer",
      amount: row.length > 9 ? (double.tryParse(row[9].toString()) ?? 0.0) : 0.0,
      description: row.length > 10 ? row[10].toString() : "",
    );
  }
}