// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'store_service.dart';

const _kStoreColor = Color(0xFF00838F);

class DoctorStorefrontScreen extends StatefulWidget {
  const DoctorStorefrontScreen({super.key});

  @override
  State<DoctorStorefrontScreen> createState() => _DoctorStorefrontScreenState();
}

class _DoctorStorefrontScreenState extends State<DoctorStorefrontScreen> {
  final _svc = StoreService();

  // ── Navigation state ───────────────────────────────────────────────────────
  // Empty  → root category grid
  // [cat]  → cat's subcategories + direct products
  // [c, s] → subcategory s's products
  final List<Map<String, dynamic>> _catStack = [];
  Map<String, dynamic>? _selectedProduct;

  // ── Root data ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _rootCats = [];
  bool _rootLoading = true;
  String? _rootError;

  // ── Per-category cache (avoids reloading on back navigation) ──────────────
  final Map<String, List<Map<String, dynamic>>> _subcatCache = {};
  final Map<String, List<Map<String, dynamic>>> _productCache = {};
  bool _levelLoading = false;

  // Current level's data (mirrors cache entry for _catStack.last)
  List<Map<String, dynamic>> _currentSubcats = [];
  List<Map<String, dynamic>> _currentProducts = [];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadRoot();
  }

  Future<void> _loadRoot() async {
    setState(() { _rootLoading = true; _rootError = null; });
    try {
      _rootCats = await _svc.getRootCategories();
    } catch (e) {
      _rootError = e.toString();
    }
    if (mounted) setState(() => _rootLoading = false);
  }

  Future<void> _openCategory(Map<String, dynamic> cat) async {
    final id = cat['id'] as String;
    if (!_subcatCache.containsKey(id)) {
      setState(() => _levelLoading = true);
      try {
        _subcatCache[id] = await _svc.getSubcategories(id);
        _productCache[id] = await _svc.getProducts(id);
      } catch (_) {
        _subcatCache[id] = [];
        _productCache[id] = [];
      }
    }
    if (!mounted) return;
    setState(() {
      _catStack.add(cat);
      _currentSubcats = _subcatCache[id]!;
      _currentProducts = _productCache[id]!;
      _levelLoading = false;
    });
  }

  void _openProduct(Map<String, dynamic> product) =>
      setState(() => _selectedProduct = product);

  // Returns image URLs for a product. Reads image_urls[] first; falls back
  // to the legacy image_url string for products created before the migration.
  List<String> _productImages(Map<String, dynamic> p) {
    final raw = p['image_urls'];
    if (raw is List) {
      final urls =
          raw.whereType<String>().where((s) => s.isNotEmpty).toList();
      if (urls.isNotEmpty) return urls;
    }
    final single = (p['image_url'] as String? ?? '').trim();
    return single.isNotEmpty ? [single] : const [];
  }

  void _openLightbox(
      BuildContext context, List<String> images, int initialIndex) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, __, ___) =>
            _LightboxPage(images: images, initialIndex: initialIndex),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _back() {
    setState(() {
      if (_selectedProduct != null) {
        _selectedProduct = null;
      } else if (_catStack.isNotEmpty) {
        _catStack.removeLast();
        if (_catStack.isNotEmpty) {
          final parentId = _catStack.last['id'] as String;
          _currentSubcats = _subcatCache[parentId] ?? [];
          _currentProducts = _productCache[parentId] ?? [];
        }
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final showBack = _catStack.isNotEmpty || _selectedProduct != null;
    return Column(
      children: [
        if (showBack) _buildSubNav(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  // Inline sub-navigation bar shown when we've drilled in.
  Widget _buildSubNav() {
    String label;
    if (_selectedProduct != null) {
      label = (_selectedProduct!['title'] as String? ?? '').trim();
    } else {
      label = (_catStack.last['name'] as String? ?? '').trim();
    }
    // Breadcrumb prefix
    String prefix = '';
    if (_catStack.length == 2 && _selectedProduct == null) {
      prefix = '${(_catStack.first['name'] as String? ?? '')}  ›  ';
    } else if (_selectedProduct != null && _catStack.isNotEmpty) {
      prefix = '${(_catStack.last['name'] as String? ?? '')}  ›  ';
    }

    return Material(
      color: _kStoreColor.withValues(alpha: 0.08),
      child: InkWell(
        onTap: _back,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.arrow_back_rounded, size: 20, color: _kStoreColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$prefix$label',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _kStoreColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedProduct != null) return _buildProductDetail(_selectedProduct!);
    if (_catStack.isEmpty) return _buildRootGrid();
    return _buildCategoryContent();
  }

  // ── Root category grid ─────────────────────────────────────────────────────

  Widget _buildRootGrid() {
    if (_rootLoading) {
      return const Center(child: CircularProgressIndicator(color: _kStoreColor));
    }
    if (_rootError != null) {
      return _buildError(_rootError!, _loadRoot);
    }
    if (_rootCats.isEmpty) {
      return _buildEmpty('No products available yet.\nCheck back soon.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            icon: Icons.storefront_rounded,
            title: 'Physiogate Catalog',
            subtitle: 'Browse our product categories'),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            // Auto-wraps: each card is at most 150 px wide; more categories
            // → more columns, fills left-to-right naturally.
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              mainAxisExtent: 108,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _rootCats.length,
            itemBuilder: (_, i) => _buildCategoryCard(_rootCats[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> cat) {
    final name = (cat['name'] as String? ?? '').trim();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openCategory(cat),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _kStoreColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.category_rounded,
                    color: _kStoreColor, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: Color(0xFF1A2332),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Category content (subcategories + products) ────────────────────────────

  Widget _buildCategoryContent() {
    if (_levelLoading) {
      return const Center(child: CircularProgressIndicator(color: _kStoreColor));
    }
    final hasSubcats  = _currentSubcats.isNotEmpty;
    final hasProducts = _currentProducts.isNotEmpty;

    if (!hasSubcats && !hasProducts) {
      return _buildEmpty('No items in this category yet.');
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (hasSubcats) ...[
          _buildListSectionLabel('Sub-categories'),
          ...(_currentSubcats.map((s) => _buildSubcatTile(s))),
        ],
        if (hasProducts) ...[
          _buildListSectionLabel('Products'),
          ...(_currentProducts.map((p) => _buildProductTile(p))),
        ],
      ],
    );
  }

  Widget _buildSubcatTile(Map<String, dynamic> cat) {
    final name = (cat['name'] as String? ?? '').trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openCategory(cat),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kStoreColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.category_rounded,
                      color: _kStoreColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13,
                          color: Color(0xFF1A2332))),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFADB5BD), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductTile(Map<String, dynamic> p) {
    final title    = (p['title']       as String? ?? '').trim();
    final price    = (p['price']       as num?)    ?? 0;
    final currency = (p['currency']    as String? ?? 'USD').trim();
    final images   = _productImages(p);
    final imageUrl = images.isNotEmpty ? images.first : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openProduct(p),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl,
                          width: 56, height: 56, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _productPlaceholder())
                      : _productPlaceholder(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13,
                              color: Color(0xFF1A2332)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kStoreColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$currency ${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}',
                          style: const TextStyle(
                              color: _kStoreColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFADB5BD), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Product detail ─────────────────────────────────────────────────────────

  Widget _buildProductDetail(Map<String, dynamic> p) {
    final title       = (p['title']           as String? ?? '').trim();
    final description = (p['description']     as String? ?? '').trim();
    final price       = (p['price']           as num?)    ?? 0;
    final currency    = (p['currency']        as String? ?? 'USD').trim();
    final images      = _productImages(p);
    final phone       = (p['phone_number']    as String? ?? '').trim();
    final whatsapp    = (p['whatsapp_number'] as String? ?? '').trim();

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // Image carousel — tap any image to open fullscreen lightbox
        _ImageCarousel(
          images: images,
          onTap: (i) => _openLightbox(context, images, i),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + price row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kStoreColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$currency ${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ),
                ],
              ),

              // Description
              if (description.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Description',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey)),
                const SizedBox(height: 6),
                Text(description,
                    style: const TextStyle(fontSize: 14, height: 1.55)),
              ],

              // Contact section
              if (phone.isNotEmpty || whatsapp.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: _kStoreColor.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _kStoreColor.withValues(alpha: 0.25)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.contact_phone_rounded,
                              color: _kStoreColor, size: 18),
                          SizedBox(width: 8),
                          Text('Contact Physiogate',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: _kStoreColor)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (phone.isNotEmpty)
                        _contactButton(
                          icon: Icons.phone_rounded,
                          label: 'Call',
                          color: const Color(0xFF2E7D32),
                          onTap: () => launchUrl(
                            Uri.parse('tel:$phone'),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                      if (phone.isNotEmpty && whatsapp.isNotEmpty)
                        const SizedBox(height: 10),
                      if (whatsapp.isNotEmpty)
                        _contactButton(
                          icon: Icons.chat_rounded,
                          label: 'WhatsApp',
                          color: const Color(0xFF1B5E20),
                          onTap: () => launchUrl(
                            Uri.parse('https://wa.me/$whatsapp'),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _contactButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _kStoreColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _kStoreColor, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1A2332))),
              Text(subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(label.toUpperCase(),
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: Colors.grey)),
    );
  }

  Widget _productPlaceholder({double height = 56}) {
    return Container(
      width: height,
      height: height,
      color: const Color(0xFFF3F4F6),
      child: const Center(
        child: Icon(Icons.inventory_2_rounded,
            color: Color(0xFFD1D5DB), size: 22),
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.storefront_outlined, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildError(String message, VoidCallback retry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 52, color: Colors.grey),
          const SizedBox(height: 14),
          const Text('Could not load store',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(message,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: _kStoreColor),
          ),
        ],
      ),
    );
  }
}

// ── Image carousel (product detail) ──────────────────────────────────────────

class _ImageCarousel extends StatefulWidget {
  const _ImageCarousel({required this.images, required this.onTap});
  final List<String> images;
  final void Function(int index) onTap;

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  late final PageController _ctrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    if (images.isEmpty) {
      return Container(
        height: 180,
        color: _kStoreColor.withValues(alpha: 0.08),
        child: const Center(
          child: Icon(Icons.inventory_2_rounded, color: _kStoreColor, size: 40),
        ),
      );
    }
    return SizedBox(
      height: 240,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => widget.onTap(i),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    images[i],
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, prog) => prog == null
                        ? child
                        : Container(
                            color: _kStoreColor.withValues(alpha: 0.05),
                            child: const Center(
                              child: CircularProgressIndicator(
                                  color: _kStoreColor, strokeWidth: 2),
                            ),
                          ),
                    errorBuilder: (_, __, ___) => Container(
                      color: _kStoreColor.withValues(alpha: 0.08),
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded,
                            color: _kStoreColor, size: 40),
                      ),
                    ),
                  ),
                  // Expand hint
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.open_in_full_rounded,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Dot indicators
          if (images.length > 1)
            Positioned(
              bottom: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  images.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i == _page ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i == _page ? Colors.white : Colors.white60,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          // Prev arrow
          if (images.length > 1 && _page > 0)
            Positioned(
              left: 8,
              child: IconButton(
                onPressed: () => _ctrl.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut),
                icon: const Icon(Icons.chevron_left_rounded,
                    color: Colors.white, size: 30),
                style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    padding: const EdgeInsets.all(4)),
              ),
            ),
          // Next arrow
          if (images.length > 1 && _page < images.length - 1)
            Positioned(
              right: 8,
              child: IconButton(
                onPressed: () => _ctrl.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut),
                icon: const Icon(Icons.chevron_right_rounded,
                    color: Colors.white, size: 30),
                style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    padding: const EdgeInsets.all(4)),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Fullscreen lightbox ───────────────────────────────────────────────────────

class _LightboxPage extends StatefulWidget {
  const _LightboxPage({required this.images, required this.initialIndex});
  final List<String> images;
  final int initialIndex;

  @override
  State<_LightboxPage> createState() => _LightboxPageState();
}

class _LightboxPageState extends State<_LightboxPage> {
  late final PageController _ctrl =
      PageController(initialPage: widget.initialIndex);
  late int _page = widget.initialIndex;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      child: Stack(
        children: [
          // Swipeable image view
          PageView.builder(
            controller: _ctrl,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Center(
              child: Image.network(
                widget.images[i],
                fit: BoxFit.contain,
                loadingBuilder: (_, child, prog) => prog == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white)),
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_rounded,
                      color: Colors.white60, size: 64),
                ),
              ),
            ),
          ),
          // Top bar: close button + image counter
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 24),
                    tooltip: 'Close',
                  ),
                  const Spacer(),
                  if (widget.images.length > 1)
                    Text(
                      '${_page + 1} / ${widget.images.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          // Prev arrow
          if (widget.images.length > 1 && _page > 0)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: () => _ctrl.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut),
                  icon: const Icon(Icons.chevron_left_rounded,
                      size: 36, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black38),
                ),
              ),
            ),
          // Next arrow
          if (widget.images.length > 1 && _page < widget.images.length - 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: () => _ctrl.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut),
                  icon: const Icon(Icons.chevron_right_rounded,
                      size: 36, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black38),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
