import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../database_helper.dart';
import 'master_category_page.dart';

class MasterProductPage extends StatefulWidget {
  const MasterProductPage({super.key});

  @override
  State<MasterProductPage> createState() => _MasterProductPageState();
}

class _MasterProductPageState extends State<MasterProductPage> {
  int _subSelectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Navigasi Khusus saat masuk menu Produk (Home, POS dsb hilang)
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: _subSelectedIndex == 0 
              ? const ProductListView() 
              : const MasterCategoryPage(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1))),
        child: BottomNavigationBar(
          currentIndex: _subSelectedIndex,
          onTap: (i) => setState(() => _subSelectedIndex = i),
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.fastfood), label: 'Item Produk'),
            BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Kategori'),
          ],
        ),
      ),
    );
  }
}

class ProductListView extends StatefulWidget {
  const ProductListView({super.key});

  @override
  State<ProductListView> createState() => _ProductListViewState();
}

class _ProductListViewState extends State<ProductListView> {
  List<Map<String, dynamic>> _products = [];
  List<String> _mainCategories = [];
  String? _selectedCategory;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final cats = await DatabaseHelper.instance.getMainCategories();
    setState(() => _mainCategories = cats);
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getAllProducts(
      mainCategory: _selectedCategory,
      query: _searchController.text
    );
    setState(() {
      _products = data;
      _isLoading = false;
    });
  }

  void _showForm(Map<String, dynamic>? product) async {
    final categories = await DatabaseHelper.instance.getCategories();
    if (categories.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tambahkan kategori terlebih dahulu!')));
      return;
    }

    final nameController = TextEditingController(text: product?['prd_name']);
    final costController = TextEditingController(text: product?['prd_cost_price']?.toString());
    final sellController = TextEditingController(text: product?['prd_selling_price']?.toString());
    int? selectedCatId = product?['prd_category_id'];
    String? currentImage = product?['prd_image'];
    File? newImageFile;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setModalState) {
        return AlertDialog(
          title: Text(product == null ? 'Tambah Produk' : 'Edit Produk'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery);
                    if (picked != null) setModalState(() => newImageFile = File(picked.path));
                  },
                  child: Container(
                    height: 100, width: 100,
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                    child: newImageFile != null 
                      ? Image.file(newImageFile!, fit: BoxFit.cover) 
                      : (currentImage != null 
                          ? Image.asset('assets/img/$currentImage', fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.add_a_photo)) 
                          : const Icon(Icons.add_a_photo)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedCatId,
                  decoration: const InputDecoration(labelText: 'Pilih Kategori'),
                  items: categories.map((c) => DropdownMenuItem<int>(value: c['cat_id'], child: Text('${c['cat_name']} - ${c['cat_subname']}'))).toList(),
                  onChanged: (val) => setModalState(() => selectedCatId = val),
                ),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nama Produk')),
                TextField(controller: costController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'HPP (Modal)')),
                TextField(controller: sellController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga Jual')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
            ElevatedButton(
              onPressed: () async {
                if (selectedCatId == null || nameController.text.isEmpty) return;
                String? imageName = currentImage;
                if (newImageFile != null) imageName = await DatabaseHelper.instance.saveProductImage(newImageFile!);

                if (product == null) {
                  final cat = categories.firstWhere((c) => c['cat_id'] == selectedCatId);
                  final sku = await DatabaseHelper.instance.generateNextSku(cat['cat_name']);
                  await DatabaseHelper.instance.addProduct({
                    'prd_sku': sku, 'prd_category_id': selectedCatId, 'prd_name': nameController.text.toUpperCase(),
                    'prd_cost_price': double.tryParse(costController.text) ?? 0, 'prd_selling_price': double.tryParse(sellController.text) ?? 0,
                    'prd_image': imageName, 'prd_is_active': 1,
                  });
                } else {
                  await DatabaseHelper.instance.updateProduct(product['prd_sku'], {
                    'prd_category_id': selectedCatId, 'prd_name': nameController.text.toUpperCase(),
                    'prd_cost_price': double.tryParse(costController.text) ?? 0, 'prd_selling_price': double.tryParse(sellController.text) ?? 0,
                    'prd_image': imageName,
                  });
                }
                Navigator.pop(context); _loadProducts();
              },
              child: const Text('SIMPAN'),
            ),
          ],
        );
      }),
    );
  }

  void _toggleStatus(String sku, int currentStatus) async {
    await DatabaseHelper.instance.updateProduct(sku, {'prd_is_active': currentStatus == 1 ? 0 : 1});
    _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Produk', style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => _loadProducts(),
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau SKU...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true, fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              // Category Filter Scrollable
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    FilterChip(
                      label: const Text('Semua'),
                      selected: _selectedCategory == null,
                      onSelected: (v) { setState(() => _selectedCategory = null); _loadProducts(); },
                    ),
                    ..._mainCategories.map((c) => Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: FilterChip(
                        label: Text(c),
                        selected: _selectedCategory == c,
                        onSelected: (v) { setState(() => _selectedCategory = c); _loadProducts(); },
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : ListView.builder(
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final p = _products[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: SizedBox(width: 50, child: p['prd_image'] != null ? Image.asset('assets/img/${p['prd_image']}', fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.fastfood)) : const Icon(Icons.fastfood)),
                  title: Text(p['prd_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('[${p['prd_sku']}] Rp ${p['prd_selling_price']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(value: p['prd_is_active'] == 1, onChanged: (v) => _toggleStatus(p['prd_sku'], p['prd_is_active'])),
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _showForm(p)),
                    ],
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showForm(null), child: const Icon(Icons.add)),
    );
  }
}
