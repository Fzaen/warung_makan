import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../database_helper.dart';

class MasterProductPage extends StatefulWidget {
  const MasterProductPage({super.key});

  @override
  State<MasterProductPage> createState() => _MasterProductPageState();
}

class _MasterProductPageState extends State<MasterProductPage> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  String? _filterCategory;
  bool _isLoading = true;
  
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final prods = await DatabaseHelper.instance.getAllProducts(
      mainCategory: _filterCategory,
      query: _searchController.text
    );
    final cats = await DatabaseHelper.instance.getCategories();
    setState(() {
      _products = prods;
      _categories = cats;
      _isLoading = false;
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadData();
    });
  }

  Widget _buildProductImage(String? fileName, {double size = 50}) {
    if (fileName == null || fileName.isEmpty) return Icon(Icons.fastfood, size: size, color: Colors.grey);
    return FutureBuilder<File?>(
      future: DatabaseHelper.instance.getLocalProductImage(fileName),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) return Image.file(snapshot.data!, width: size, height: size, fit: BoxFit.cover);
        return Image.asset('assets/img/$fileName', width: size, height: size, fit: BoxFit.cover, errorBuilder: (c, e, s) => Icon(Icons.fastfood, size: size, color: Colors.grey));
      },
    );
  }

  void _showProductForm({Map<String, dynamic>? product}) {
    final isEdit = product != null;
    final skuController = TextEditingController(text: isEdit ? product['prd_sku'] : '');
    final nameController = TextEditingController(text: isEdit ? product['prd_name'] : '');
    final costPriceController = TextEditingController(text: isEdit ? product['prd_cost_price'].toString() : '');
    final sellingPriceController = TextEditingController(text: isEdit ? product['prd_selling_price'].toString() : '');
    final unitController = TextEditingController(text: isEdit ? product['prd_unit'] : 'pcs');
    String? selectedMainCat = isEdit ? product['cat_name'] : null;
    int? selectedSubCatId = isEdit ? product['prd_category_id'] : null;
    int isActive = isEdit ? (product['prd_is_active'] ?? 1) : 1;
    String? currentImage = isEdit ? product['prd_image'] : null;
    File? newImageFile;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          List<String> mainCats = _categories.map((c) => c['cat_name'] as String).toSet().toList();
          List<Map<String, dynamic>> subCats = selectedMainCat == null ? [] : _categories.where((c) => c['cat_name'] == selectedMainCat).toList();
          return AlertDialog(
            title: Text(isEdit ? 'Edit Produk' : 'Tambah Produk Baru', style: const TextStyle(fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final img = await picker.pickImage(source: ImageSource.gallery);
                      if (img != null) setModalState(() => newImageFile = File(img.path));
                    },
                    child: Container(height: 100, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: newImageFile != null ? Image.file(newImageFile!, fit: BoxFit.cover) : (currentImage != null ? _buildProductImage(currentImage, size: 80) : const Icon(Icons.add_a_photo))),
                  ),
                  DropdownButtonFormField<String>(value: selectedMainCat, decoration: const InputDecoration(labelText: 'Kategori Utama'), items: mainCats.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(), onChanged: isEdit ? null : (val) async { if (val != null) { String nextSku = await DatabaseHelper.instance.generateNextSku(val); setModalState(() { selectedMainCat = val; selectedSubCatId = null; skuController.text = nextSku; }); } }),
                  DropdownButtonFormField<int>(value: selectedSubCatId, decoration: const InputDecoration(labelText: 'Sub Kategori'), items: subCats.map((cat) => DropdownMenuItem<int>(value: cat['cat_id'], child: Text(cat['cat_subname'] ?? '-'))).toList(), onChanged: (val) => setModalState(() => selectedSubCatId = val)),
                  TextField(controller: skuController, decoration: const InputDecoration(labelText: 'SKU'), enabled: false),
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nama Produk')),
                  Row(children: [Expanded(child: TextField(controller: costPriceController, decoration: const InputDecoration(labelText: 'Hrg Modal'), keyboardType: TextInputType.number)), const SizedBox(width: 10), Expanded(child: TextField(controller: sellingPriceController, decoration: const InputDecoration(labelText: 'Hrg Jual'), keyboardType: TextInputType.number))]),
                  TextField(controller: unitController, decoration: const InputDecoration(labelText: 'Satuan')),
                  SwitchListTile(title: const Text('Aktif'), value: isActive == 1, onChanged: (val) => setModalState(() => isActive = val ? 1 : 0)),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')), ElevatedButton(onPressed: (selectedSubCatId == null || skuController.text.isEmpty) ? null : () async { String? finalImage = currentImage; if (newImageFile != null) finalImage = await DatabaseHelper.instance.saveProductImage(newImageFile!); final productData = { 'prd_sku': skuController.text, 'prd_category_id': selectedSubCatId, 'prd_name': nameController.text, 'prd_cost_price': double.tryParse(costPriceController.text) ?? 0, 'prd_selling_price': double.tryParse(sellingPriceController.text) ?? 0, 'prd_unit': unitController.text, 'prd_image': finalImage, 'prd_is_active': isActive }; if (isEdit) await DatabaseHelper.instance.updateProduct(product['prd_sku'], productData); else await DatabaseHelper.instance.addProduct(productData); Navigator.pop(context); _loadData(); }, child: const Text('SIMPAN'))],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isMobile ? 100 : 110, // Berikan ruang untuk search bar
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          children: [
            // Baris 1: Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(null, 'Semua'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Makanan', 'Makanan'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Minuman', 'Minuman'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Cemilan', 'Cemilan'),
                ],
              ),
            ),
            // Baris 2: Search Bar Minimalis
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
              child: SizedBox(
                height: 35,
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Cari produk atau SKU...',
                    prefixIcon: const Icon(Icons.search, size: 16),
                    suffixIcon: _searchController.text.isNotEmpty 
                      ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () { _searchController.clear(); _loadData(); }) 
                      : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey[300]!)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey[300]!)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showProductForm(), child: const Icon(Icons.add)),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _products.isEmpty ? const Center(child: Text('Kosong.')) : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final p = _products[index];
          final bool isActive = (p['prd_is_active'] ?? 1) == 1;
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: _buildProductImage(p['prd_image'], size: isMobile ? 40 : 50)),
              title: Text(p['prd_name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 13 : 14)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SKU: ${p['prd_sku']} | ${p['cat_name']}', style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                Text('Jual: ${_currencyFormat.format(p['prd_selling_price'])}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 11)),
              ]),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: isActive ? Colors.green[50] : Colors.red[50], borderRadius: BorderRadius.circular(8)), child: Text(isActive ? 'AKTIF' : 'NON', style: TextStyle(fontSize: 9, color: isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _showProductForm(product: p)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String? category, String label) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      selected: _filterCategory == category,
      onSelected: (selected) { setState(() => _filterCategory = selected ? category : null); _loadData(); },
    );
  }
}
