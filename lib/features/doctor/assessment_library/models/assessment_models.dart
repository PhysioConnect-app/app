class AssessmentTest {
  final String name;
  final String purpose;
  final String method;
  // Reserved for Arabic localisation — unpopulated until _ar keys are added to
  // assessment_library.json. Do not read these in UI code yet.
  final String? nameAr;
  final String? purposeAr;
  final String? methodAr;

  const AssessmentTest({
    required this.name,
    required this.purpose,
    required this.method,
    this.nameAr,
    this.purposeAr,
    this.methodAr,
  });

  factory AssessmentTest.fromJson(Map<String, dynamic> json) => AssessmentTest(
        name: json['name'] as String,
        purpose: json['purpose'] as String,
        method: json['method'] as String,
        nameAr: json['name_ar'] as String?,
        purposeAr: json['purpose_ar'] as String?,
        methodAr: json['method_ar'] as String?,
      );
}

class AssessmentSubcategory {
  final String name;
  // Reserved for Arabic localisation.
  final String? nameAr;
  final List<AssessmentTest> tests;

  const AssessmentSubcategory({
    required this.name,
    this.nameAr,
    required this.tests,
  });

  factory AssessmentSubcategory.fromJson(Map<String, dynamic> json) =>
      AssessmentSubcategory(
        name: json['name'] as String,
        nameAr: json['name_ar'] as String?,
        tests: (json['tests'] as List)
            .map((t) => AssessmentTest.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}

class AssessmentCategory {
  // JSON key is "category", not "name", at the top level.
  final String name;
  // Reserved for Arabic localisation.
  final String? nameAr;
  final List<AssessmentSubcategory> subcategories;

  const AssessmentCategory({
    required this.name,
    this.nameAr,
    required this.subcategories,
  });

  factory AssessmentCategory.fromJson(Map<String, dynamic> json) =>
      AssessmentCategory(
        name: json['category'] as String,
        nameAr: json['category_ar'] as String?,
        subcategories: (json['subcategories'] as List)
            .map((s) =>
                AssessmentSubcategory.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class AssessmentLibrary {
  final int version;
  final List<AssessmentCategory> categories;

  const AssessmentLibrary({required this.version, required this.categories});

  factory AssessmentLibrary.fromJson(Map<String, dynamic> json) =>
      AssessmentLibrary(
        version: json['version'] as int,
        categories: (json['categories'] as List)
            .map((c) =>
                AssessmentCategory.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}
