import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/product_card.dart';

class ProductScreen extends StatefulWidget {
  @override
  _ProductScreenState createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final ProductService _productService = ProductService();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  final TextEditingController _searchController = TextEditingController();

  // Controllers for input form
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _sellPriceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _minimumStokController = TextEditingController();

  // Focus nodes
  final FocusNode _sellPriceFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isSubmitting = false;

  // Pagination variables
  int _currentPage = 0;
  int _itemsPerPage = 5;
  int get _totalPages => (_filteredProducts.length / _itemsPerPage).ceil();

  List<Product> get _currentPageProducts {
    int startIndex = _currentPage * _itemsPerPage;
    int endIndex = (startIndex + _itemsPerPage).clamp(
      0,
      _filteredProducts.length,
    );
    return _filteredProducts.sublist(startIndex, endIndex);
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _discountController.text = '0'; // Default discount value
    _minimumStokController.text = '100'; // Default minimum stock value
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await _productService.getAllProducts();
      setState(() {
        _products = products;
        _filteredProducts = products;
        _currentPage = 0; // Reset to first page
      });
    } catch (e) {
      print('Error loading products: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading products: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _searchProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _products;
      } else {
        _filteredProducts = _products.where((product) {
          return product.name.toLowerCase().contains(query.toLowerCase()) ||
              (product.barcode != null && product.barcode!.contains(query));
        }).toList();
      }
      _currentPage = 0; // Reset to first page when searching
    });
  }

  Future<void> _scanBarcode() async {
    // Check camera permission
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Izin kamera diperlukan untuk scan barcode')),
        );
        return;
      }
    }

    // Navigate to scanner screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BarcodeScannerScreen()),
    );

    if (result != null && result is String) {
      // Set the scanned barcode to the text field
      _barcodeController.text = result;
      // Move focus to sell price field
      FocusScope.of(context).requestFocus(_sellPriceFocusNode);
    }
  }

  Future<void> _addProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final product = Product(
        id: 0, // Auto increment
        name: _nameController.text.trim(),
        barcode: _barcodeController.text.trim(),
        sellPrice: int.parse(_sellPriceController.text),
        discount: int.parse(_discountController.text),
        minimumStock: int.parse(_minimumStokController.text),
        // dateAdded will be handled in the service/database layer
      );

      final success = await _productService.addProduct(product);

      if (success) {
        // Clear form
        _nameController.clear();
        _barcodeController.clear();
        _sellPriceController.clear();
        _discountController.text = '0';
        _minimumStokController.text = '0';

        // Reload products
        await _loadProducts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Produk berhasil ditambahkan')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal menambahkan produk')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _editProduct(Product product) {
    showDialog(
      context: context,
      builder: (context) => ProductEditDialog(product: product),
    ).then((result) {
      if (result == true) {
        _loadProducts();
      }
    });
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Produk'),
        content: Text('Apakah Anda yakin ingin menghapus ${product.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _productService.deleteProduct(product.id);
      if (success) {
        _loadProducts();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Produk berhasil dihapus')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal menghapus produk')));
        }
      }
    }
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      setState(() {
        _currentPage++;
      });
    }
  }

  Widget _buildInputForm() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tambah Produk Baru',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            SizedBox(height: 16),
            // Product Name Field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nama Produk *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama produk wajib diisi';
                }
                return null;
              },
            ),
            SizedBox(height: 12),
            // Barcode Field
            TextFormField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: 'Barcode',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                suffixIcon: IconButton(
                  onPressed: _scanBarcode,
                  icon: Icon(Icons.qr_code_scanner),
                  tooltip: 'Scan Barcode',
                  color: Colors.green[600],
                ),
              ),
            ),
            SizedBox(height: 12),
            // Price and Discount Row - Responsive
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 100) {
                  // Wide screen - show in row
                  return Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _sellPriceController,
                          focusNode: _sellPriceFocusNode,
                          decoration: InputDecoration(
                            labelText: 'Harga Jual *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            prefixText: 'Rp ',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Harga jual wajib diisi';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Harga harus berupa angka';
                            }
                            if (int.parse(value) <= 0) {
                              return 'Harga harus lebih dari 0';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _discountController,
                          decoration: InputDecoration(
                            labelText: 'Diskon *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            suffixText: '%',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Diskon wajib diisi';
                            }
                            final discount = int.tryParse(value);
                            if (discount == null) {
                              return 'Diskon harus berupa angka';
                            }
                            if (discount < 0 || discount > 100) {
                              return 'Diskon harus antara 0-100%';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _minimumStokController,
                          decoration: InputDecoration(
                            labelText: 'Stok Minimum',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Diskon wajib diisi';
                            }
                            final mimimumStok = int.tryParse(value);
                            if (mimimumStok == null) {
                              return 'Stok minimum harus berupa angka';
                            }
                            if (mimimumStok < 0) {
                              return 'Minimum stok tidak boleh negatif';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  );
                } else {
                  // Narrow screen - show in column
                  return Column(
                    children: [
                      TextFormField(
                        controller: _sellPriceController,
                        focusNode: _sellPriceFocusNode,
                        decoration: InputDecoration(
                          labelText: 'Harga Jual *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          prefixText: 'Rp ',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Harga jual wajib diisi';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Harga harus berupa angka';
                          }
                          if (int.parse(value) <= 0) {
                            return 'Harga harus lebih dari 0';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 12),
                      TextFormField(
                        controller: _discountController,
                        decoration: InputDecoration(
                          labelText: 'Diskon *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          suffixText: '%',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Diskon wajib diisi';
                          }
                          final discount = int.tryParse(value);
                          if (discount == null) {
                            return 'Diskon harus berupa angka';
                          }
                          if (discount < 0 || discount > 100) {
                            return 'Diskon harus antara 0-100%';
                          }
                          return null;
                        },
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _minimumStokController,
                          decoration: InputDecoration(
                            labelText: 'Stok Minimum',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Diskon wajib diisi';
                            }
                            final mimimumStok = int.tryParse(value);
                            if (mimimumStok == null) {
                              return 'Stok minimum harus berupa angka';
                            }
                            if (mimimumStok < 0) {
                              return 'Minimum stok tidak boleh negatif';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
            SizedBox(height: 16),
            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _addProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Menyimpan...'),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add),
                          SizedBox(width: 8),
                          Text('Tambah Produk'),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  'Daftar Produk',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ),
              Text(
                'Total: ${_filteredProducts.length} produk',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: _searchProducts,
            decoration: InputDecoration(
              hintText: 'Cari berdasarkan nama atau barcode...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          SizedBox(height: 16),
          // Product List
          Expanded(
            child: _isLoading
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _filteredProducts.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            _searchController.text.isNotEmpty
                                ? 'Tidak ada produk yang ditemukan'
                                : 'Belum ada produk',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _currentPageProducts.length,
                    separatorBuilder: (context, index) => Divider(height: 1),
                    itemBuilder: (context, index) {
                      final product = _currentPageProducts[index];
                      return ProductCard(
                        product: product,
                        onEdit: () => _editProduct(product),
                        onDelete: () => _deleteProduct(product),
                      );
                    },
                  ),
          ),

          // Pagination
          if (_totalPages > 1) ...[
            SizedBox(height: 8),
            Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _currentPage > 0 ? _previousPage : null,
                        icon: Icon(Icons.chevron_left),
                      ),
                      ...List.generate(_totalPages, (index) {
                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: 2),
                          child: index == _currentPage
                              ? Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green[600],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : TextButton(
                                  onPressed: () => _goToPage(index),
                                  child: Text('${index + 1}'),
                                ),
                        );
                      }),
                      IconButton(
                        onPressed: _currentPage < _totalPages - 1
                            ? _nextPage
                            : null,
                        icon: Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Halaman ${_currentPage + 1} dari $_totalPages',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Kelola Produk'),
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Input Form Section
              _buildInputForm(),

              // Product List Section with minimum height
              Container(
                height: MediaQuery.of(context).size.height * 0.6,
                child: _buildProductList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _barcodeController.dispose();
    _sellPriceController.dispose();
    _discountController.dispose();
    _minimumStokController.dispose();
    _sellPriceFocusNode.dispose();
    super.dispose();
  }
}

// Barcode Scanner Screen
class BarcodeScannerScreen extends StatefulWidget {
  @override
  _BarcodeScannerScreenState createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _screenOpened = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    cameraController = MobileScannerController(
      // detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Barcode/QR Code'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _toggleTorch,
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.yellow : Colors.grey,
            ),
            tooltip: 'Toggle Flash',
          ),
          IconButton(
            onPressed: _switchCamera,
            icon: Icon(Icons.cameraswitch),
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: cameraController, onDetect: _foundBarcode),
          // Overlay untuk memberikan panduan visual
          Container(
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5)),
            child: Stack(
              children: [
                // Area transparan untuk scanning
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),
                // Corner indicators
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    child: Stack(
                      children: [
                        // Top left corner
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.green, width: 4),
                                left: BorderSide(color: Colors.green, width: 4),
                              ),
                            ),
                          ),
                        ),
                        // Top right corner
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.green, width: 4),
                                right: BorderSide(
                                  color: Colors.green,
                                  width: 4,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Bottom left corner
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.green,
                                  width: 4,
                                ),
                                left: BorderSide(color: Colors.green, width: 4),
                              ),
                            ),
                          ),
                        ),
                        // Bottom right corner
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.green,
                                  width: 4,
                                ),
                                right: BorderSide(
                                  color: Colors.green,
                                  width: 4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Instruksi
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          color: Colors.white,
                          size: 48,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Arahkan kamera ke barcode atau QR code',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Pastikan barcode berada dalam area hijau',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTorch() async {
    try {
      await cameraController.toggleTorch();
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (e) {
      print('Error toggling torch: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat mengaktifkan flash')),
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    try {
      await cameraController.switchCamera();
    } catch (e) {
      print('Error switching camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Tidak dapat mengganti kamera')));
      }
    }
  }

  void _foundBarcode(BarcodeCapture capture) {
    if (!_screenOpened) {
      final String? code = capture.barcodes.first.rawValue;
      if (code != null && code.isNotEmpty) {
        _screenOpened = true;
        // Berikan feedback visual
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Barcode berhasil dipindai: $code'),
              duration: Duration(milliseconds: 500),
              backgroundColor: Colors.green,
            ),
          );

          // Delay sedikit agar user bisa melihat feedback
          Future.delayed(Duration(milliseconds: 300), () {
            if (mounted) {
              Navigator.pop(context, code);
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}

// Separate dialog for editing products
class ProductEditDialog extends StatefulWidget {
  final Product product;

  const ProductEditDialog({Key? key, required this.product}) : super(key: key);

  @override
  _ProductEditDialogState createState() => _ProductEditDialogState();
}

class _ProductEditDialogState extends State<ProductEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _discountController = TextEditingController();
  final _minimumStokController = TextEditingController();
  final _stockController = TextEditingController();
  final _barcodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.product.name;
    _buyPriceController.text = widget.product.buyPrice?.toString() ?? '';
    _sellPriceController.text = widget.product.sellPrice?.toString() ?? '';
    _discountController.text = widget.product.discount?.toString() ?? '0';
    _minimumStokController.text =
        widget.product.minimumStock?.toString() ?? '0';
    _stockController.text = widget.product.stock?.toString() ?? '0';
    _barcodeController.text = widget.product.barcode ?? '';
  }

  Future<void> _scanBarcodeForEdit() async {
    // Check camera permission
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Izin kamera diperlukan untuk scan barcode'),
            ),
          );
        }
        return;
      }
    }

    // Navigate to scanner screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BarcodeScannerScreen()),
    );

    if (result != null && result is String) {
      // Set the scanned barcode to the text field
      _barcodeController.text = result;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Produk'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Produk',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nama produk harus diisi';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _barcodeController,
                  decoration: InputDecoration(
                    labelText: 'Barcode',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      onPressed: _scanBarcodeForEdit,
                      icon: Icon(Icons.qr_code_scanner),
                      tooltip: 'Scan Barcode',
                      color: Colors.green[600],
                    ),
                  ),
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _sellPriceController,
                  decoration: InputDecoration(
                    labelText: 'Harga Jual',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _minimumStokController,
                  decoration: InputDecoration(
                    labelText: 'Stok Minimum',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _discountController,
                  decoration: InputDecoration(
                    labelText: 'Diskon (%)',
                    suffixText: '%',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final discount = int.tryParse(value);
                      if (discount == null) {
                        return 'Diskon harus berupa angka';
                      }
                      if (discount < 0 || discount > 100) {
                        return 'Diskon harus antara 0-100%';
                      }
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[600],
            foregroundColor: Colors.white,
          ),
          child: Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveProduct,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text('Simpan'),
        ),
      ],
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final product = Product(
        id: widget.product.id,
        name: _nameController.text,
        barcode: _barcodeController.text.isEmpty
            ? null
            : _barcodeController.text,
        buyPrice: _buyPriceController.text.isEmpty
            ? null
            : int.tryParse(_buyPriceController.text),
        sellPrice: _sellPriceController.text.isEmpty
            ? null
            : int.tryParse(_sellPriceController.text),
        stock: _stockController.text.isEmpty
            ? 0
            : int.tryParse(_stockController.text) ?? 0,
        discount: _discountController.text.isEmpty
            ? 0
            : int.tryParse(_discountController.text) ?? 0,
        minimumStock: _minimumStokController.text.isEmpty
            ? 0
            : int.tryParse(_minimumStokController.text) ?? 0,
      );
      final service = ProductService();
      final success = await service.updateProduct(product);

      if (success) {
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Produk berhasil diperbarui')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal memperbarui produk')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _discountController.dispose();
    _minimumStokController.dispose();
    _stockController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }
}
