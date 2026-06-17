import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'store_manager_categories_screen.dart';

// Products tab is imported and wired in the next commit.

const _kStoreColor = Color(0xFF00838F);

class StoreManagerDashboardScreen extends StatelessWidget {
  const StoreManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _kStoreColor,
          foregroundColor: Colors.white,
          title: const Text(
            'Physiogate — Store Manager',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
        body: const TabBarView(
          children: [
            StoreManagerCategoriesScreen(),
            Center(child: Text('Products — coming next')),
          ],
        ),
      ),
    );
  }
}
