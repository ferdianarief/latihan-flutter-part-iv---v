class Product {
  int id;
  String name;
  int? buyPrice;
  int? sellPrice;
  int? discount;
  int? stock;
  int? minimumStock;
  String? barcode;
  DateTime? dateAdded;

  Product({
    required this.id,
    required this.name,
    this.buyPrice,
    this.sellPrice,
    this.discount,
    this.stock,
    this.minimumStock,
    this.barcode,
    this.dateAdded,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'buyPrice': buyPrice,
      'sellPrice': sellPrice,
      'discount': discount,
      'stock': stock,
      'minimumStock': minimumStock,
      'barcode': barcode,
      'dateAdded': dateAdded?.toIso8601String(),
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      buyPrice: json['buyPrice'],
      sellPrice: json['sellPrice'],
      discount: json['discount'],
      stock: json['stock'],
      minimumStock: json['minimumStock'],
      barcode: json['barcode'],
      dateAdded: json['dateAdded'] != null
          ? DateTime.parse(json['dateAdded'])
          : null,
    );
  }

  // Helper method to format date for display
  String get formattedDateAdded {
    if (dateAdded == null) return '-';
    return '${dateAdded!.day.toString().padLeft(2, '0')}/'
        '${dateAdded!.month.toString().padLeft(2, '0')}/'
        '${dateAdded!.year}';
  }
}
