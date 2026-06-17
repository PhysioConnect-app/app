import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'store_manager_categories_screen.dart';
import 'store_manager_products_screen.dart';
import 'store_manager_service.dart';

const _kStoreColor = Color(0xFF00838F);

class StoreManagerDashboardScreen extends StatefulWidget {
  const StoreManagerDashboardScreen({super.key});

  @override
  State<StoreManagerDashboardScreen> createState() =>
      _StoreManagerDashboardScreenState();
}

class _StoreManagerDashboardScreenState
    extends State<StoreManagerDashboardScreen> {
  final _svc = StoreManagerService();
  int _catCount = 0;
  int _productCount = 0;
  int _publishedCount = 0;
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final results = await Future.wait([
        _svc.getAllCategories(),
        _svc.getAllProducts(),
      ]);
      if (!mounted) return;
      final cats = results[0];
      final prods = results[1];
      setState(() {
        _catCount = cats.length;
        _productCount = prods.length;
        _publishedCount =
            prods.where((p) => p['status'] == 'published').length;
        _statsLoaded = true;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _kStoreColor,
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Physiogate — Store Manager',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              if (_statsLoaded)
                Text(
                  '$_catCount ${_catCount == 1 ? 'category' : 'categories'}'
                  ' · $_productCount ${_productCount == 1 ? 'product' : 'products'}'
                  ' · $_publishedCount published',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Sign out',
              onPressed: () => Supabase.instance.client.auth.signOut(),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.category_rounded), text: 'Categories'),
              Tab(icon: Icon(Icons.inventory_2_rounded), text: 'Products'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            StoreManagerCategoriesScreen(onChanged: _loadStats),
            StoreManagerProductsScreen(onChanged: _loadStats),
          ],
        ),
      ),
    );
  }
}
