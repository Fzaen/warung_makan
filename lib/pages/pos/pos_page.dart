import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database_helper.dart';

class PosPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const PosPage({super.key, required this.user});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  List<String> _mainCategories = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _cartItems = [];
  String? _selectedMainCategory;
  double _total = 0;
  bool _isLoading = true;

  // Format IDR: Titik sebagai pemisah ribuan, tanpa desimal
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    setState(() => _isLoading = true);
    try {
      final mainCats = await DatabaseHelper.instance.getMainCategories();
      final prods = await DatabaseHelper.instance.getProductsByMainCategory(null);
      final cart = await DatabaseHelper.instance.getActiveCart(widget.user['usr_id']);
      
      setState(() {
        _mainCategories = mainCats;
        _products = prods;
        _cartItems = cart;
        _calculateTotal();
      });
    } catch (e) {
      debugPrint("Error loading POS data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterByMainCategory(String? mainCat) async {
    setState(() => _isLoading = true);
    final prods = await DatabaseHelper.instance.getProductsByMainCategory(mainCat);
    setState(() {
      _selectedMainCategory = mainCat;
      _products = prods;
      _isLoading = false;
    });
  }

  void _addToCart(Map<String, dynamic> product) async {
    await DatabaseHelper.instance.addToCart(
      widget.user['usr_id'],
      product['prd_sku'],
      1,
      product['prd_selling_price'],
    );
    _refreshCart();
  }

  void _updateQty(int cartId, int newQty) async {
    await DatabaseHelper.instance.updateCartQty(cartId, newQty);
    _refreshCart();
  }

  void _deleteItem(int cartId) async {
    await DatabaseHelper.instance.removeFromCart(cartId);
    _refreshCart();
  }

  void _refreshCart() async {
    final cart = await DatabaseHelper.instance.getActiveCart(widget.user['usr_id']);
    setState(() {
      _cartItems = cart;
      _calculateTotal();
    });
  }

  void _calculateTotal() {
    _total = _cartItems.fold(0, (sum, item) => sum + (item['cart_subtotal'] ?? 0));
  }

  void _showManualQtyDialog(int cartId, int currentQty, String productName) {
    final controller = TextEditingController(text: currentQty.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Qty: $productName'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Masukkan Jumlah'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
          ElevatedButton(
            onPressed: () {
              int? val = int.tryParse(controller.text);
              if (val != null) {
                _updateQty(cartId, val);
                Navigator.pop(context);
              }
            },
            child: const Text('SIMPAN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildCategoryButton(null, 'Semua'),
                    ..._mainCategories.map((catName) => _buildCategoryButton(catName, catName)),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(child: Text("Tidak ada produk"))
                    : GridView.builder(
                        padding: const EdgeInsets.all(10),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final p = _products[index];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            elevation: 3,
                            child: InkWell(
                              onTap: () => _addToCart(p),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Image.asset(
                                      'assets/img/${p['prd_image']}',
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Container(
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.broken_image, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p['prd_name'], 
                                          maxLines: 2, 
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        const SizedBox(height: 4),
                                        Text(_currencyFormat.format(p['prd_selling_price']), 
                                          style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        
        const VerticalDivider(width: 1),

        Expanded(
          flex: 1,
          child: Container(
            color: Colors.grey[50],
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Keranjang Belanja', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: _cartItems.isEmpty
                      ? const Center(child: Text("Keranjang Kosong"))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _cartItems.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _cartItems[index];
                            int cartId = item['cart_id'];
                            int qty = item['cart_qty'];
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(item['prd_name'], 
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_forever, color: Colors.red, size: 22),
                                        onPressed: () => _deleteItem(cartId),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_currencyFormat.format(item['cart_price']), style: const TextStyle(color: Colors.grey)),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
                                            onPressed: () => _updateQty(cartId, qty - 1),
                                          ),
                                          InkWell(
                                            onTap: () => _showManualQtyDialog(cartId, qty, item['prd_name']),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Colors.grey[300]!),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '$qty',
                                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                            onPressed: () => _updateQty(cartId, qty + 1),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(_currencyFormat.format(item['cart_subtotal']), 
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 14)),
                          Flexible(
                            child: Text(_currencyFormat.format(_total), 
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                          onPressed: _total > 0 ? () {} : null,
                          child: const Text('BAYAR SEKARANG', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryButton(String? catName, String label) {
    bool isSelected = _selectedMainCategory == catName;
    return GestureDetector(
      onTap: () => _filterByMainCategory(catName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        margin: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.blue : Colors.grey[300]!),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87, 
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
            ),
          ),
        ),
      ),
    );
  }
}
