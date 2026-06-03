// lib/models/product.dart

class Product {
  final int? id;
  final String name;
  final String category; // 'SS' or 'Brass' or any custom
  final String padii;
  final int productWeightG;
  final double sellPricePerKg;
  final bool soldByPiece;
  final String unit; // 'kg' or 'pcs'
  // Individual cost fields for editing
  final double costLabour;
  final double costPlasma;
  final double costVettu;
  final double costWelding;
  final double costRunner;
  final double costVarai;
  final double costPolish;
  final double costMaterial;
  final bool isActive;

  const Product({
    this.id,
    required this.name,
    required this.category,
    required this.padii,
    required this.productWeightG,
    required this.sellPricePerKg,
    required this.soldByPiece,
    required this.unit,
    this.costLabour = 0,
    this.costPlasma = 0,
    this.costVettu = 0,
    this.costWelding = 0,
    this.costRunner = 0,
    this.costVarai = 0,
    this.costPolish = 0,
    this.costMaterial = 0,
    this.isActive = true,
  });

  double get totalCostPerProduct =>
      costLabour + costPlasma + costVettu + costWelding +
      costRunner + costVarai + costPolish + costMaterial;

  double get costPerKg => totalCostPerProduct * (1000 / productWeightG);
  double get profitPerKg => sellPricePerKg - costPerKg;
  double get profitPerPiece => profitPerKg * (productWeightG / 1000);
  double get profitPerUnit => soldByPiece ? profitPerPiece : profitPerKg;
  double profitForQty(double qty) => qty * profitPerUnit;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'padii': padii,
    'product_weight_g': productWeightG,
    'sell_price_per_kg': sellPricePerKg,
    'sold_by_piece': soldByPiece ? 1 : 0,
    'unit': unit,
    'cost_labour': costLabour,
    'cost_plasma': costPlasma,
    'cost_vettu': costVettu,
    'cost_welding': costWelding,
    'cost_runner': costRunner,
    'cost_varai': costVarai,
    'cost_polish': costPolish,
    'cost_material': costMaterial,
    'is_active': isActive ? 1 : 0,
  };

  factory Product.fromMap(Map<String, dynamic> m) => Product(
    id: m['id'] as int?,
    name: m['name'] as String,
    category: m['category'] as String,
    padii: m['padii'] as String? ?? '',
    productWeightG: m['product_weight_g'] as int,
    sellPricePerKg: (m['sell_price_per_kg'] as num).toDouble(),
    soldByPiece: (m['sold_by_piece'] as int) == 1,
    unit: m['unit'] as String,
    costLabour: (m['cost_labour'] as num?)?.toDouble() ?? 0,
    costPlasma: (m['cost_plasma'] as num?)?.toDouble() ?? 0,
    costVettu: (m['cost_vettu'] as num?)?.toDouble() ?? 0,
    costWelding: (m['cost_welding'] as num?)?.toDouble() ?? 0,
    costRunner: (m['cost_runner'] as num?)?.toDouble() ?? 0,
    costVarai: (m['cost_varai'] as num?)?.toDouble() ?? 0,
    costPolish: (m['cost_polish'] as num?)?.toDouble() ?? 0,
    costMaterial: (m['cost_material'] as num?)?.toDouble() ?? 0,
    isActive: (m['is_active'] as int? ?? 1) == 1,
  );

  Product copyWith({
    int? id, String? name, String? category, String? padii,
    int? productWeightG, double? sellPricePerKg, bool? soldByPiece,
    String? unit, double? costLabour, double? costPlasma, double? costVettu,
    double? costWelding, double? costRunner, double? costVarai,
    double? costPolish, double? costMaterial, bool? isActive,
  }) => Product(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    padii: padii ?? this.padii,
    productWeightG: productWeightG ?? this.productWeightG,
    sellPricePerKg: sellPricePerKg ?? this.sellPricePerKg,
    soldByPiece: soldByPiece ?? this.soldByPiece,
    unit: unit ?? this.unit,
    costLabour: costLabour ?? this.costLabour,
    costPlasma: costPlasma ?? this.costPlasma,
    costVettu: costVettu ?? this.costVettu,
    costWelding: costWelding ?? this.costWelding,
    costRunner: costRunner ?? this.costRunner,
    costVarai: costVarai ?? this.costVarai,
    costPolish: costPolish ?? this.costPolish,
    costMaterial: costMaterial ?? this.costMaterial,
    isActive: isActive ?? this.isActive,
  );
}