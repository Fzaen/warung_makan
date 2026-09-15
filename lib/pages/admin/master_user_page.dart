import 'package:flutter/material.dart';

class MasterUserPage extends StatelessWidget {
  const MasterUserPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Master User')),
      body: const Center(child: Text('Master User Page - Admin Only')),
    );
  }
}
