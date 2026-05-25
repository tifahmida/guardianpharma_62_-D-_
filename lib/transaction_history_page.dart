import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pharmacy_wrapper_page.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> sales = [];
  bool loading = true;
  String selectedFilter = 'Today';

  final List<String> filters = ['Today', 'This Week', 'This Month', 'All Time'];

  double totalRevenue = 0;
  int totalTransactions = 0;
  int totalStrips = 0;
  int totalBoxes = 0;
  int totalCartons = 0;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  String _formatDate(String iso) {
    final dt = DateTime.parse(iso).toUtc().add(const Duration(hours: 6));
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatTime(String iso) {
    final dt = DateTime.parse(iso).toUtc().add(const Duration(hours: 6));
    final h = dt.hour;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0
        ? 12
        : h > 12
        ? h - 12
        : h;
    return '${h12.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _loadSales() async {
    setState(() => loading = true);
    try {
      final now = DateTime.now().toUtc();
      final todayStart = DateTime.utc(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime.utc(now.year, now.month, 1);
      final pharmacyId = PharmacySession.pharmacyId ?? '';

      List<Map<String, dynamic>> res = [];

      if (selectedFilter == 'Today') {
        final r = await supabase
            .from('sales')
            .select('*, profiles(full_name)')
            .eq('pharmacy_id', pharmacyId)
            .gte('created_at', todayStart.toIso8601String())
            .order('created_at', ascending: false);
        res = List<Map<String, dynamic>>.from(r);
      } else if (selectedFilter == 'This Week') {
        final r = await supabase
            .from('sales')
            .select('*, profiles(full_name)')
            .eq('pharmacy_id', pharmacyId)
            .gte('created_at', weekStart.toIso8601String())
            .order('created_at', ascending: false);
        res = List<Map<String, dynamic>>.from(r);
      } else if (selectedFilter == 'This Month') {
        final r = await supabase
            .from('sales')
            .select('*, profiles(full_name)')
            .eq('pharmacy_id', pharmacyId)
            .gte('created_at', monthStart.toIso8601String())
            .order('created_at', ascending: false);
        res = List<Map<String, dynamic>>.from(r);
      } else {
        final r = await supabase
            .from('sales')
            .select('*, profiles(full_name)')
            .eq('pharmacy_id', pharmacyId)
            .order('created_at', ascending: false);
        res = List<Map<String, dynamic>>.from(r);
      }

      double revenue = 0;
      int strips = 0, boxes = 0, cartons = 0;
      for (final s in res) {
        revenue += double.tryParse(s['total_amount'].toString()) ?? 0;
        final type = s['sale_type']?.toString() ?? '';
        final qty = (s['quantity_sold'] as int?) ?? 0;
        if (type == 'strip') strips += qty;
        if (type == 'box') boxes += qty;
        if (type == 'carton') cartons += qty;
      }

      setState(() {
        sales = res;
        totalRevenue = revenue;
        totalTransactions = res.length;
        totalStrips = strips;
        totalBoxes = boxes;
        totalCartons = cartons;
        loading = false;
      });
    } catch (e) {
      _error('Failed to load: $e');
      setState(() => loading = false);
    }
  }

  void _showDetail(Map<String, dynamic> sale) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(
                Icons.receipt_long,
                color: Colors.blueAccent,
                size: 36,
              ),
              const SizedBox(height: 8),
              const Text(
                'Transaction Receipt',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatDate(sale['created_at'])}  •  ${_formatTime(sale['created_at'])} (BD)',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              _row('💊 Medicine', sale['medicine_name']?.toString() ?? 'N/A'),
              _row('🔢 Batch', sale['batch_number']?.toString() ?? 'N/A'),
              _row(
                '📦 Type',
                (sale['sale_type']?.toString() ?? '').toUpperCase(),
              ),
              _row('🔢 Quantity', sale['quantity_sold']?.toString() ?? '0'),
              _row(
                '💰 Unit Price',
                'BDT ${double.tryParse(sale['unit_price'].toString())?.toStringAsFixed(2) ?? '0.00'}',
              ),
              const Divider(color: Colors.white24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'BDT ${double.tryParse(sale['total_amount'].toString())?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _row(
                '👨‍⚕️ Sold By',
                sale['profiles']?['full_name']?.toString() ?? 'Unknown',
              ),
              if ((sale['customer_name']?.toString() ?? '').isNotEmpty)
                _row('👤 Customer', sale['customer_name']?.toString() ?? ''),
              if ((sale['customer_phone']?.toString() ?? '').isNotEmpty)
                _row('📱 Phone', sale['customer_phone']?.toString() ?? ''),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  icon: const Icon(Icons.delete, color: Colors.white),
                  label: const Text(
                    'Delete Transaction',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await supabase.from('sales').delete().eq('id', sale['id']);
                    _success('Deleted!');
                    _loadSales();
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _error(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  void _success(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/guardianpharmapills.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.45)),
          ),
          SafeArea(
            child: Column(
              children: [
                // TOP BAR
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Icon(Icons.receipt_long, color: Colors.white),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Transaction History',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _loadSales,
                      ),
                    ],
                  ),
                ),

                // FILTER CHIPS
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filters.length,
                    itemBuilder: (_, i) {
                      final f = filters[i];
                      final isSelected = f == selectedFilter;
                      return GestureDetector(
                        onTap: () {
                          setState(() => selectedFilter = f);
                          _loadSales();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blueAccent
                                : Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blueAccent
                                  : Colors.white24,
                            ),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white60,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // SUMMARY
                if (!loading)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.blueAccent.withOpacity(0.4),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                '💰 Total Revenue',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'BDT ${totalRevenue.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$totalTransactions transactions',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _miniStat(
                              '💊 Strips',
                              '$totalStrips',
                              Colors.blueAccent,
                            ),
                            const SizedBox(width: 8),
                            _miniStat(
                              '📦 Boxes',
                              '$totalBoxes',
                              Colors.greenAccent,
                            ),
                            const SizedBox(width: 8),
                            _miniStat(
                              '🏭 Cartons',
                              '$totalCartons',
                              Colors.orangeAccent,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // SALES LIST
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.blueAccent,
                          ),
                        )
                      : sales.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.receipt_long_outlined,
                                color: Colors.white24,
                                size: 60,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No transactions for $selectedFilter',
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: sales.length,
                          itemBuilder: (_, i) {
                            final sale = sales[i];
                            final type = sale['sale_type']?.toString() ?? '';
                            final double total =
                                double.tryParse(
                                  sale['total_amount'].toString(),
                                ) ??
                                0;
                            final soldBy =
                                sale['profiles']?['full_name']?.toString() ??
                                'Unknown';
                            final customer =
                                sale['customer_name']?.toString() ?? '';

                            Color typeColor;
                            IconData typeIcon;
                            if (type == 'strip') {
                              typeColor = Colors.blueAccent;
                              typeIcon = Icons.medication;
                            } else if (type == 'box') {
                              typeColor = Colors.greenAccent;
                              typeIcon = Icons.inventory_2;
                            } else {
                              typeColor = Colors.orangeAccent;
                              typeIcon = Icons.widgets;
                            }

                            return GestureDetector(
                              onTap: () => _showDetail(sale),
                              child: Card(
                                color: Colors.white.withOpacity(0.10),
                                margin: const EdgeInsets.only(bottom: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: typeColor.withOpacity(
                                          0.2,
                                        ),
                                        child: Icon(
                                          typeIcon,
                                          color: typeColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              sale['medicine_name']
                                                      ?.toString() ??
                                                  'Unknown',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              'Batch: ${sale['batch_number']}  |  ${type.toUpperCase()}  |  Qty: ${sale['quantity_sold']}',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              '👨‍⚕️ $soldBy  ${customer.isNotEmpty ? '  |  👤 $customer' : ''}',
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 11,
                                              ),
                                            ),
                                            Text(
                                              '${_formatDate(sale['created_at'])}  •  ${_formatTime(sale['created_at'])}',
                                              style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'BDT ${total.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.greenAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
