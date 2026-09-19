import 'package:flutter/material.dart';
import '../../database_helper.dart';

class MasterCategoryPage extends StatefulWidget {
  const MasterCategoryPage({super.key});

  @override
  State<MasterCategoryPage> createState() => _MasterCategoryPageState();
}

class _MasterCategoryPageState extends State<MasterCategoryPage> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getCategories();
    setState(() {
      _categories = data;
      _isLoading = false;
    });
  }

  void _showForm(Map<String, dynamic>? category) {
    final nameController = TextEditingController(text: category?['cat_name']);
    final subController = TextEditingController(text: category?['cat_subname']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? 'Tambah Kategori' : 'Edit Kategori'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Kategori (cth: Makanan)')),
            TextField(controller: subController, decoration: const InputDecoration(labelText: 'Sub (cth: Khas)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
          ElevatedButton(
            onPressed: () async {
              if (category == null) {
                await DatabaseHelper.instance.addCategory(nameController.text, subController.text);
              } else {
                await DatabaseHelper.instance.updateCategory(category['cat_id'], nameController.text, subController.text);
              }
              Navigator.pop(context);
              _loadCategories();
            },
            child: const Text('SIMPAN'),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(int id) async {
    int res = await DatabaseHelper.instance.deleteCategory(id);
    if (res == -1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal: Kategori masih digunakan oleh produk!')));
    } else {
      _loadCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final c = _categories[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  title: Text(c['cat_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Sub: ${c['cat_subname']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showForm(c)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteCategory(c['cat_id'])),
                    ],
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}
