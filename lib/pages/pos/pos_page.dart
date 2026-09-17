import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:async';
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

  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Widget _buildProductImage(String? fileName, {double size = 100}) {
    if (fileName == null || fileName.isEmpty) return Icon(Icons.fastfood, size: size / 2, color: Colors.grey);
    return FutureBuilder<File?>(
      future: DatabaseHelper.instance.getLocalProductImage(fileName),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) return Image.file(snapshot.data!, fit: BoxFit.cover);
        return Image.asset('assets/img/$fileName', fit: BoxFit.cover, errorBuilder: (c, e, s) => Icon(Icons.fastfood, size: size / 2, color: Colors.grey));
      },
    );
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
    await DatabaseHelper.instance.addToCart(widget.user['usr_id'], product['prd_sku'], 1, product['prd_selling_price'], product['prd_cost_price']);
    _refreshCart();
  }

  void _updateQty(int cartId, int newQty) async {
    if (newQty <= 0) return; 
    await DatabaseHelper.instance.updateCartQty(widget.user['usr_id'], cartId, newQty);
    _refreshCart();
  }

  void _deleteItem(int cartId) async {
    await DatabaseHelper.instance.removeFromCart(widget.user['usr_id'], cartId);
    _refreshCart();
  }

  void _refreshCart() async {
    final cart = await DatabaseHelper.instance.getActiveCart(widget.user['usr_id']);
    setState(() {
      _cartItems = cart;
      _calculateTotal();
    });
  }

  void _calculateTotal() => _total = _cartItems.fold(0, (sum, item) => sum + (item['cart_subtotal'] ?? 0));

  void _showManualQtyDialog(int cartId, int currentQty, String productName) {
    final controller = TextEditingController(text: currentQty.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Qty: $productName', style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Masukkan Jumlah'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
          ElevatedButton(onPressed: () {
            int? val = int.tryParse(controller.text);
            if (val != null && val > 0) { _updateQty(cartId, val); Navigator.pop(context); }
          }, child: const Text('SIMPAN')),
        ],
      ),
    );
  }

  void _showPaymentDialog() {
    final TextEditingController paidController = TextEditingController();
    double paidAmount = 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          double change = paidAmount - _total;
          bool isEnough = paidAmount >= _total;
          return AlertDialog(
            title: const Text('Proses Pembayaran'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total: ${_currencyFormat.format(_total)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                TextField(
                  controller: paidController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
                  decoration: const InputDecoration(labelText: 'Uang Dibayar', prefixText: 'Rp ', border: OutlineInputBorder()),
                  onChanged: (value) => setModalState(() => paidAmount = double.tryParse(value.replaceAll('.', '')) ?? 0),
                ),
                const SizedBox(height: 12),
                if (!isEnough && paidAmount > 0) Text('Kurang: ${_currencyFormat.format(_total - paidAmount)}', style: const TextStyle(color: Colors.red)),
                if (isEnough) Text('Kembalian: ${_currencyFormat.format(change)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
              ElevatedButton(onPressed: isEnough ? () async {
                await DatabaseHelper.instance.processPayment(userId: widget.user['usr_id'], subtotal: _total, paidAmount: paidAmount, changeAmount: change);
                Navigator.pop(context); _showSuccessDialog(change); _refreshCart();
              } : null, child: const Text('KONFIRMASI')),
            ],
          );
        }
      ),
    );
  }

  void _showSuccessDialog(double change) {
    Timer? timer;
    showDialog(context: context, builder: (context) {
      timer = Timer(const Duration(seconds: 2), () => Navigator.canPop(context) ? Navigator.pop(context) : null);
      return AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 50),
        title: const Text('Berhasil!'),
        content: change > 0 ? Text('Kembalian: ${_currencyFormat.format(change)}', textAlign: TextAlign.center) : null,
      );
    }).then((_) => timer?.cancel());
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final isMobile = screenWidth < 600;

    int crossAxisCount = 1;
    if (screenWidth > 1100) crossAxisCount = 4;
    else if (screenWidth > 800) crossAxisCount = 3;
    else if (screenWidth > 500) crossAxisCount = 2;

    return Column(
      children: [
        // FILTER KATEGORI
        Container(
          width: double.infinity,
          height: 50,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              const SizedBox(width: 8),
              _buildCategoryButton(null, 'Semua'),
              ..._mainCategories.map((catName) => _buildCategoryButton(catName, catName)),
              const SizedBox(width: 8),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            children: [
              // ================= KIRI: GALERI PRODUK =================
              Expanded(
                flex: (isMobile && isPortrait) ? 1 : 2,
                child: _isLoading ? const Center(child: CircularProgressIndicator()) : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: isMobile ? 0.9 : 0.8,
                    crossAxisSpacing: 8, mainAxisSpacing: 8,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final p = _products[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: InkWell(
                        onTap: () => _addToCart(p),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _buildProductImage(p['prd_image'])),
                            Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['prd_name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 11 : 13)),
                                  Text('[${p['prd_sku']}]', style: const TextStyle(fontSize: 8, color: Colors.grey)),
                                  Text(_currencyFormat.format(p['prd_selling_price']), style: TextStyle(color: Colors.blue, fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.bold)),
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
              const VerticalDivider(width: 1),
              // ================= KANAN: DETAIL KERANJANG =================
              Expanded(
                flex: (isMobile && isPortrait) ? 1 : 1, 
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Keranjang', style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.bold))),
                      Expanded(
                        child: _cartItems.isEmpty ? const Center(child: Text("Kosong", style: TextStyle(fontSize: 12, color: Colors.grey))) : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _cartItems.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _cartItems[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(item['prd_name'], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 11 : 14))),
                                      IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _deleteItem(item['cart_id'])),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Menggunakan Row dengan MainAxisAlignment.spaceBetween agar harga ke kanan
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Kontrol Qty
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: Icon(Icons.remove_circle_outline, color: item['cart_qty'] > 1 ? Colors.orange : Colors.grey, size: 24), onPressed: item['cart_qty'] > 1 ? () => _updateQty(item['cart_id'], item['cart_qty'] - 1) : null),
                                          InkWell(
                                            onTap: () => _showManualQtyDialog(item['cart_id'], item['cart_qty'], item['prd_name']),
                                            child: Container(margin: const EdgeInsets.symmetric(horizontal: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(4)), child: Text('${item['cart_qty']}', style: TextStyle(fontSize: isMobile ? 13 : 16, fontWeight: FontWeight.bold, color: Colors.blue))),
                                          ),
                                          IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 24), onPressed: () => _updateQty(item['cart_id'], item['cart_qty'] + 1)),
                                        ],
                                      ),
                                      // Harga Subtotal - Sekarang dipaksa ke sisi kanan
                                      Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(_currencyFormat.format(item['cart_subtotal']), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: isMobile ? 12 : 15)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))]),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                              children: [
                                const Text('Total', style: TextStyle(fontSize: 12)), 
                                Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(_currencyFormat.format(_total), style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold, color: Colors.blue))))
                              ]
                            ),
                            const SizedBox(height: 8),
                            SizedBox(width: double.infinity, height: 45, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: _total > 0 ? _showPaymentDialog : null, child: Text('BAYAR', style: TextStyle(fontSize: isMobile ? 14 : 18, fontWeight: FontWeight.bold)))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(color: isSelected ? Colors.blue : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? Colors.blue : Colors.grey[200]!)),
        child: Center(child: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
      ),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) return newValue;
    double value = double.parse(newValue.text.replaceAll('.', ''));
    final formatter = NumberFormat.decimalPattern('id_ID');
    String newText = formatter.format(value);
    return newValue.copyWith(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}
