import 'package:flutter/material.dart';
import 'audit_log_page.dart';
import 'profit_report_page.dart';
import 'reprint_page.dart';
import 'item_sales_report_page.dart';

class ReportHubPage extends StatefulWidget {
  const ReportHubPage({super.key});

  @override
  State<ReportHubPage> createState() => _ReportHubPageState();
}

class _ReportHubPageState extends State<ReportHubPage> {
  int _currentSubIndex = 0;

  final List<Widget> _subPages = [
    const ProfitReportPage(),
    const ItemSalesReportPage(groupingType: 'item'),
    const ItemSalesReportPage(groupingType: 'category'),
    const ItemSalesReportPage(groupingType: 'subcategory'),
    const ReprintPage(),
    const AuditLogPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-Navbar Atas (Scrollable)
        Container(
          color: Colors.white,
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSubNavItem(0, Icons.bar_chart, 'Laba Rugi'),
                _buildSubNavItem(1, Icons.list_alt, 'Per Item'),
                _buildSubNavItem(2, Icons.category_outlined, 'Per Kategori'),
                _buildSubNavItem(3, Icons.account_tree_outlined, 'Per Sub-Kat'),
                _buildSubNavItem(4, Icons.print_outlined, 'Reprint'),
                _buildSubNavItem(5, Icons.history_edu, 'Audit'),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // Isi Halaman
        Expanded(
          child: _subPages[_currentSubIndex],
        ),
      ],
    );
  }

  Widget _buildSubNavItem(int index, IconData icon, String label) {
    bool isSelected = _currentSubIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentSubIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
