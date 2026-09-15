import 'package:flutter/material.dart';

class MasterProductPage extends StatelessWidget {
  const MasterProductPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Master Product')),
      body: const Center(child: Text('Master Product Page - Admin Only')),
    );
  }
}
