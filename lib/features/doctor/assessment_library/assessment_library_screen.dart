import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'assessment_library_repository.dart';
import 'models/assessment_models.dart';

class AssessmentLibraryScreen extends StatefulWidget {
  const AssessmentLibraryScreen({super.key});

  @override
  State<AssessmentLibraryScreen> createState() =>
      _AssessmentLibraryScreenState();
}

class _AssessmentLibraryScreenState extends State<AssessmentLibraryScreen> {
  static const _accent = Color(0xFF006064);

  AssessmentCategory? _category;
  AssessmentSubcategory? _subcategory;
  AssessmentTest? _test;

  bool get _canGoBack => _category != null;

  void _goBack() {
    setState(() {
      if (_test != null) {
        _test = null;
      } else if (_subcategory != null) {
        _subcategory = null;
      } else {
        _category = null;
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _canGoBack) _goBack();
      },
      child: FutureBuilder<AssessmentLibrary>(
        future: AssessmentLibraryRepository.load(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return Center(
              child: Text('Could not load library: ${snap.error}',
                  style: const TextStyle(color: AppColors.error)),
            );
          }
          return _buildContent(snap.data!);
        },
      ),
    );
  }

  Widget _buildContent(AssessmentLibrary library) {
    if (_test != null) return _buildTestDetail(_test!);
    if (_subcategory != null) return _buildTestList(_subcategory!);
    if (_category != null) return _buildSubcategoryList(_category!);
    return _buildCategoryList(library.categories);
  }

  // ── Breadcrumb ────────────────────────────────────────────────────────────

  Widget _buildBreadcrumb() {
    final crumbs = <String>['Library'];
    if (_category != null) crumbs.add(_category!.name);
    if (_subcategory != null) crumbs.add(_subcategory!.name);
    if (_test != null) crumbs.add(_test!.name);

    return Container(
      width: double.infinity,
      color: _accent.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          InkWell(
            onTap: _canGoBack ? _goBack : null,
            borderRadius: BorderRadius.circular(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios_new_rounded,
                    size: 14,
                    color: _canGoBack ? _accent : Colors.transparent),
                const SizedBox(width: 4),
              ],
            ),
          ),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < crumbs.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.chevron_right_rounded,
                          size: 16, color: AppColors.textSecondary),
                    ),
                  Text(
                    crumbs[i],
                    style: TextStyle(
                      fontSize: 13,
                      color: i == crumbs.length - 1
                          ? _accent
                          : AppColors.textSecondary,
                      fontWeight: i == crumbs.length - 1
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Category list ─────────────────────────────────────────────────────────

  Widget _buildCategoryList(List<AssessmentCategory> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          icon: Icons.assignment_rounded,
          title: 'Assessment Library',
          subtitle:
              '${categories.length} categories  ·  clinical reference',
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final cat = categories[i];
              final testCount = cat.subcategories
                  .fold(0, (sum, s) => sum + s.tests.length);
              return _DrillCard(
                leading: _categoryIcon(cat.name),
                title: cat.name,
                subtitle:
                    '${cat.subcategories.length} subcategories  ·  $testCount tests',
                accentColor: _accent,
                onTap: () => setState(() => _category = cat),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Subcategory list ──────────────────────────────────────────────────────

  Widget _buildSubcategoryList(AssessmentCategory category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBreadcrumb(),
        _buildHeader(
          icon: _categoryIcon(category.name),
          title: category.name,
          subtitle: '${category.subcategories.length} subcategories',
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: category.subcategories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final sub = category.subcategories[i];
              return _DrillCard(
                leading: Icons.folder_open_rounded,
                title: sub.name,
                subtitle: '${sub.tests.length} tests',
                accentColor: _accent,
                onTap: () => setState(() => _subcategory = sub),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Test list ─────────────────────────────────────────────────────────────

  Widget _buildTestList(AssessmentSubcategory subcategory) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBreadcrumb(),
        _buildHeader(
          icon: Icons.folder_open_rounded,
          title: subcategory.name,
          subtitle: '${subcategory.tests.length} tests',
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: subcategory.tests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final test = subcategory.tests[i];
              return _DrillCard(
                leading: Icons.science_rounded,
                title: test.name,
                subtitle: test.purpose,
                accentColor: _accent,
                onTap: () => setState(() => _test = test),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Test detail ───────────────────────────────────────────────────────────

  Widget _buildTestDetail(AssessmentTest test) {
    return Column(
      children: [
        _buildBreadcrumb(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.science_rounded,
                          color: _accent, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        test.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailSection(
                  icon: Icons.flag_rounded,
                  label: 'Purpose',
                  body: test.purpose,
                ),
                const SizedBox(height: 16),
                _buildDetailSection(
                  icon: Icons.medical_information_rounded,
                  label: 'Method',
                  body: test.method,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSection({
    required IconData icon,
    required String label,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: _accent),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _accent,
                    letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 10),
          Text(body,
              style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.5)),
        ],
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _buildHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.08),
        border: Border(
            bottom: BorderSide(
                color: _accent.withValues(alpha: 0.15), width: 1)),
      ),
      child: Row(children: [
        Icon(icon, color: _accent, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
      ]),
    );
  }

  IconData _categoryIcon(String name) {
    switch (name) {
      case 'Musculoskeletal':
        return Icons.accessibility_new_rounded;
      case 'Neurological':
        return Icons.psychology_rounded;
      case 'Pediatrics':
        return Icons.child_care_rounded;
      case 'Functional':
        return Icons.directions_run_rounded;
      default:
        return Icons.folder_rounded;
    }
  }
}

// ── Reusable drill-down card ──────────────────────────────────────────────────

class _DrillCard extends StatelessWidget {
  final IconData leading;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _DrillCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(leading, color: accentColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
