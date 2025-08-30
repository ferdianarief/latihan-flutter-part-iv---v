import '../models/product.dart';
import '../helpers/database_helper.dart';

class ProductService {
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal();

  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<List<Product>> getAllProducts() async {
    return await _databaseHelper.getAllProducts();
  }

  Future<Product?> getProductById(int id) async {
    return await _databaseHelper.getProductById(id);
  }

  Future<bool> addProduct(Product product) async {
    try {
      final id = await _databaseHelper.insertProduct(product);
      return id > 0;
    } catch (e) {
      print('Error adding product: $e');
      return false;
    }
  }

  Future<bool> updateProduct(Product updatedProduct) async {
    try {
      final rowsAffected = await _databaseHelper.updateProduct(updatedProduct);
      return rowsAffected > 0;
    } catch (e) {
      print('Error updating product: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(int id) async {
    try {
      final rowsAffected = await _databaseHelper.deleteProduct(id);
      return rowsAffected > 0;
    } catch (e) {
      print('Error deleting product: $e');
      return false;
    }
  }

  Future<bool> updateStock(int productId, int newStock) async {
    try {
      final rowsAffected = await _databaseHelper.updateStock(
        productId,
        newStock,
      );
      return rowsAffected > 0;
    } catch (e) {
      print('Error updating stock: $e');
      return false;
    }
  }

  Future<List<Product>> searchProducts(String query) async {
    try {
      return await _databaseHelper.searchProducts(query);
    } catch (e) {
      print('Error searching products: $e');
      return [];
    }
  }
}
