// lib/models/sale.dart
class Sale {
  final int? id;
  final int productId;
  final String productName; // stored for history even if product deleted
  final String productCategory;
  final double qty;
  final DateTime date;
  final double profit;

  const Sale({
    this.id,
    required this.productId,
    required this.productName,
    required this.productCategory,
    required this.qty,
    required this.date,
    required this.profit,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'product_id': productId,
    'product_name': productName,
    'product_category': productCategory,
    'qty': qty,
    'date': date.toIso8601String().substring(0, 10),
    'profit': profit,
  };

  factory Sale.fromMap(Map<String, dynamic> m) => Sale(
    id: m['id'] as int?,
    productId: m['product_id'] as int,
    productName: m['product_name'] as String? ?? '',
    productCategory: m['product_category'] as String? ?? '',
    qty: (m['qty'] as num).toDouble(),
    date: DateTime.parse(m['date'] as String),
    profit: (m['profit'] as num).toDouble(),
  );

  Sale copyWith({int? id}) => Sale(
    id: id ?? this.id,
    productId: productId,
    productName: productName,
    productCategory: productCategory,
    qty: qty,
    date: date,
    profit: profit,
  );
}