import 'package:flutter/material.dart';
import '../../database_helper.dart';

class MasterUserPage extends StatefulWidget {
  const MasterUserPage({super.key});

  @override
  State<MasterUserPage> createState() => _MasterUserPageState();
}

class _MasterUserPageState extends State<MasterUserPage> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _roles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final users = await DatabaseHelper.instance.getAllUsers();
    final roles = await DatabaseHelper.instance.getRoles();
    setState(() {
      _users = users;
      _roles = roles;
      _isLoading = false;
    });
  }

  void _showUserForm({Map<String, dynamic>? user}) {
    final isEdit = user != null;
    final nameController = TextEditingController(text: isEdit ? user['usr_name'] : '');
    final usernameController = TextEditingController(text: isEdit ? user['usr_username'] : '');
    final passwordController = TextEditingController(text: isEdit ? user['usr_password'] : '');
    final phoneController = TextEditingController(text: isEdit ? user['usr_phone'] : '');
    int? selectedRoleId = isEdit ? user['usr_role_id'] : (_roles.isNotEmpty ? _roles.first['rol_id'] : null);
    int isActive = isEdit ? user['usr_is_active'] : 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(isEdit ? 'Edit User' : 'Tambah User Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                ),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  enabled: !isEdit, // Username biasanya unik dan tidak diubah
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'No. Telepon'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<int>(
                  value: selectedRoleId,
                  decoration: const InputDecoration(labelText: 'Role / Hak Akses'),
                  items: _roles.map((role) {
                    return DropdownMenuItem<int>(
                      value: role['rol_id'],
                      child: Text(role['rol_name']),
                    );
                  }).toList(),
                  onChanged: (val) => setModalState(() => selectedRoleId = val),
                ),
                const SizedBox(height: 15),
                SwitchListTile(
                  title: const Text('Status Aktif'),
                  value: isActive == 1,
                  onChanged: (val) => setModalState(() => isActive = val ? 1 : 0),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
            ElevatedButton(
              onPressed: () async {
                final userData = {
                  'usr_role_id': selectedRoleId,
                  'usr_name': nameController.text,
                  'usr_username': usernameController.text,
                  'usr_password': passwordController.text,
                  'usr_phone': phoneController.text,
                  'usr_is_active': isActive,
                };

                if (isEdit) {
                  await DatabaseHelper.instance.updateUser(user['usr_id'], userData);
                } else {
                  await DatabaseHelper.instance.addUser(userData);
                }
                
                if (!mounted) return;
                Navigator.pop(context);
                _loadData();
              },
              child: const Text('SIMPAN'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserForm(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('Belum ada data user.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final bool isActive = user['usr_is_active'] == 1;
                    
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive ? Colors.blue[100] : Colors.grey[300],
                          child: Icon(Icons.person, color: isActive ? Colors.blue : Colors.grey),
                        ),
                        title: Text(user['usr_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${user['rol_name']} | @${user['usr_username']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green[50] : Colors.red[50],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isActive ? 'AKTIF' : 'NON-AKTIF',
                                style: TextStyle(
                                  fontSize: 10, 
                                  color: isActive ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showUserForm(user: user),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
