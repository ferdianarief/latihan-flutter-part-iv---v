import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'kasirq.db');
    return await openDatabase(path, version: 1, onCreate: _createDatabase);
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        buy_price INTEGER,
        sell_price INTEGER,
        discount INTEGER DEFAULT 0,
        stock INTEGER DEFAULT 0,
        minimumStock INTEGER DEFAULT 0,
        barcode TEXT
      )
    ''');

    // Insert sample data
    await db.insert('products', {
      'name': 'Produk A',
      'buy_price': 15000,
      'sell_price': 20000,
      'stock': 50,
      'discount': 0,
      'barcode': '1234567890123',
    });

    await db.insert('products', {
      'name': 'Produk N',
      'buy_price': 1000,
      'sell_price': 2000,
      'stock': 50,
      'discount': 0,
      'barcode': '123456789012',
    });
  }

  // Product CRUD operations
  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products');
    return List.generate(maps.length, (i) {
      return Product(
        id: maps[i]['id'],
        name: maps[i]['name'],
        buyPrice: maps[i]['buy_price'],
        sellPrice: maps[i]['sell_price'],
        discount: maps[i]['discount'],
        stock: maps[i]['stock'],
        minimumStock: maps[i]['minimumStock'],
        barcode: maps[i]['barcode'],
      );
    });
  }

  Future<Product?> getProductById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Product(
        id: maps[0]['id'],
        name: maps[0]['name'],
        buyPrice: maps[0]['buy_price'],
        sellPrice: maps[0]['sell_price'],
        discount: maps[0]['discount'],
        stock: maps[0]['stock'],
        minimumStock: maps[0]['minimumStock'],
        barcode: maps[0]['barcode'],
      );
    }
    return null;
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('products', {
      'name': product.name,
      'buy_price': product.buyPrice,
      'sell_price': product.sellPrice,
      'discount': product.discount,
      'stock': product.stock,
      'barcode': product.barcode,
    });
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update(
      'products',
      {
        'name': product.name,
        'buy_price': product.buyPrice,
        'sell_price': product.sellPrice,
        'discount': product.discount,
        'stock': product.stock,
        'minimumStock': product.minimumStock,
        'barcode': product.barcode,
      },
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateStock(int productId, int newStock) async {
    final db = await database;
    return await db.update(
      'products',
      {'stock': newStock},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'name LIKE ? OR barcode LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );

    return List.generate(maps.length, (i) {
      return Product(
        id: maps[i]['id'],
        name: maps[i]['name'],
        buyPrice: maps[i]['buy_price'],
        sellPrice: maps[i]['sell_price'],
        discount: maps[i]['discount'],
        stock: maps[i]['stock'],
        minimumStock: maps[i]['minimumStock'],
        barcode: maps[i]['barcode'],
      );
    });
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
