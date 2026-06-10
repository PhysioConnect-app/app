class AppStrings {
  final bool isArabic;
  const AppStrings(this.isArabic);

  String _t(String en, String ar) => isArabic ? ar : en;

  // App
  String get appName => _t('PhysioConnect', 'فيزيو كونكت');
  String get logout => _t('Logout', 'تسجيل الخروج');
  String get cancel => _t('Cancel', 'إلغاء');
  String get save => _t('Save', 'حفظ');
  String get add => _t('Add', 'إضافة');
  String get delete => _t('Delete', 'حذف');
  String get edit => _t('Edit', 'تعديل');
  String get search => _t('Search', 'بحث');
  String get loading => _t('Loading...', 'جارٍ التحميل...');
  String get error => _t('Error', 'خطأ');
  String get success => _t('Success', 'نجاح');
  String get noData => _t('No data available', 'لا توجد بيانات');
  String get send => _t('Send', 'إرسال');
  String get close => _t('Close', 'إغلاق');
  String get confirm => _t('Confirm', 'تأكيد');
  String get language => _t('العربية', 'English');
  String get signOut => _t('Sign Out', 'تسجيل الخروج');
  String get areYouSure => _t('Are you sure?', 'هل أنت متأكد؟');

  // Auth
  String get welcomeBack => _t('Welcome Back!', 'مرحباً بعودتك!');
  String get signInSubtitle => _t('Please sign in to your account', 'يرجى تسجيل الدخول إلى حسابك');
  String get ptLogin => _t('Physical Therapy Portal', 'بوابة العلاج الطبيعي');
  String get email => _t('Email Address', 'البريد الإلكتروني');
  String get emailOrUsername => _t('Email or Username', 'البريد الإلكتروني أو اسم المستخدم');
  String get password => _t('Password', 'كلمة المرور');
  String get showPassword => _t('Show', 'إظهار');
  String get hidePassword => _t('Hide', 'إخفاء');
  String get signIn => _t('Sign In', 'تسجيل الدخول');
  String get forgotPassword => _t('Forgot Password?', 'نسيت كلمة المرور؟');
  String get forgotPasswordTitle => _t('Reset Password', 'إعادة تعيين كلمة المرور');
  String get forgotPasswordHint => _t(
    'Enter your email address and we\'ll send you a reset link.',
    'أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة التعيين.',
  );
  String get forgotPasswordSent => _t(
    'Reset link sent! Check your inbox.',
    'تم إرسال رابط الإعادة! تحقق من صندوق الوارد.',
  );
  String get forgotPasswordError => _t(
    'Could not send reset email. Check the address and try again.',
    'تعذر إرسال البريد. تحقق من العنوان وحاول مجدداً.',
  );
  String get login => _t('Log In', 'تسجيل الدخول');
  String get loginFailed => _t('Login failed. Check your credentials.', 'فشل تسجيل الدخول. تحقق من بياناتك.');

  // Guest mode (mobile patient login)
  String get continueAsGuest => _t('Continue as Guest', 'المتابعة كزائر');
  String get guestSignInRequiredTitle => _t('Sign In Required', 'تسجيل الدخول مطلوب');
  String get guestSignInPrompt => _t(
    'Sign in or create an account to book',
    'سجّل الدخول أو أنشئ حساباً للحجز',
  );

  // Doctor Dashboard
  String get doctorDashboard => _t('PT Dashboard', 'لوحة العلاج الطبيعي');
  String get myPatients => _t('My Patients', 'مرضاي');
  String get schedule => _t('Schedule', 'الجدول');
  String get soapNotes => _t('SOAP Notes', 'ملاحظات SOAP');
  String get statistics => _t('Statistics', 'الإحصائيات');
  String get messages => _t('Messages', 'الرسائل');
  String get billing => _t('Income', 'الدخل');
  String get inventory => _t('Inventory', 'المخزون');
  String get expenses => _t('Expenses', 'المصروفات');
  String get myProfile => _t('My Profile', 'ملفي');

  // Doctor - Patients
  String get addPatient => _t('Add Patient', 'إضافة مريض');
  String get patientName => _t('Patient Full Name', 'الاسم الكامل للمريض');
  String get patientEmail => _t('Patient Email', 'بريد المريض الإلكتروني');
  String get patientPassword => _t('Temporary Password', 'كلمة المرور المؤقتة');
  String get patientPhone => _t('Phone Number', 'رقم الهاتف');
  String get patientDob => _t('Date of Birth', 'تاريخ الميلاد');
  String get diagnosis => _t('Primary Diagnosis', 'التشخيص الرئيسي');
  String get createAccount => _t('Create Patient Account', 'إنشاء حساب المريض');
  String get activeRehab => _t('Active Rehabilitation', 'إعادة التأهيل النشطة');
  String get noPatients => _t('No patients linked to your practice yet.', 'لا يوجد مرضى مرتبطون بعيادتك بعد.');
  String get selectPatientForNotes => _t('Tap a patient to open their notes', 'اضغط على مريض لفتح ملاحظاته');

  // Doctor - Schedule
  String get scheduleSession => _t('Schedule Session', 'جدولة جلسة');
  String get selectPatient => _t('Select Patient', 'اختر المريض');
  String get sessionDate => _t('Session Date & Time', 'التاريخ والوقت');
  String get sessionNotes => _t('Session Notes / Modality', 'ملاحظات الجلسة');
  String get bookSession => _t('Book Session', 'حجز الجلسة');
  String get sessionBooked => _t('Session booked successfully!', 'تم حجز الجلسة بنجاح!');
  String get selectPatientAndTime => _t('Select patient and time first.', 'اختر المريض والوقت أولاً.');

  // Doctor - SOAP Notes
  String get soapTemplates => _t('SOAP Templates', 'قوالب SOAP');
  String get useTemplate => _t('Use Template', 'استخدام قالب');
  String get subjective => _t('Subjective (S)', 'الاستجوابي (S)');
  String get objective => _t('Objective (O)', 'الموضوعي (O)');
  String get assessment => _t('Assessment (A)', 'التقييم (A)');
  String get plan => _t('Plan (P)', 'الخطة (P)');
  String get subjectiveHint => _t("Patient's description of symptoms, pain level, history", 'وصف المريض للأعراض ومستوى الألم والتاريخ');
  String get objectiveHint => _t('Measurable findings: ROM, strength, gait, special tests', 'النتائج القابلة للقياس: المدى الحركي والقوة والمشية');
  String get assessmentHint => _t('Clinical diagnosis, functional limitations, progress', 'التشخيص السريري والقيود الوظيفية والتقدم');
  String get planHint => _t('Treatment plan, frequency, HEP, goals, next visit', 'خطة العلاج والتكرار والبرنامج المنزلي والأهداف');
  String get publishNote => _t('Publish Note', 'نشر الملاحظة');
  String get notePublished => _t('Clinical note published!', 'تم نشر الملاحظة السريرية!');
  String get fillAllSoapFields => _t('Select a patient and fill all SOAP fields.', 'اختر مريضاً واملأ جميع حقول SOAP.');

  // Doctor - Stats
  String get sessionStats => _t('Session Statistics', 'إحصائيات الجلسات');
  String get daily => _t('Daily', 'يومياً');
  String get weekly => _t('Weekly', 'أسبوعياً');
  String get monthly => _t('Monthly', 'شهرياً');
  String get yearly => _t('Yearly', 'سنوياً');
  String get totalSessions => _t('Total Sessions', 'إجمالي الجلسات');
  String get thisWeek => _t('This Week', 'هذا الأسبوع');
  String get thisMonth => _t('This Month', 'هذا الشهر');
  String get thisYear => _t('This Year', 'هذا العام');

  // Doctor - Appointments Overview
  String get appointmentsOverview => _t('Appointments', 'المواعيد');
  String get addAppointment => _t('Add Appointment', 'إضافة موعد');
  String get scheduleAppointment => _t('Schedule Appointment', 'جدولة موعد');
  String get noAppointments => _t('No appointments for this period.', 'لا توجد مواعيد لهذه الفترة.');
  String get editAppointment => _t('Edit Appointment', 'تعديل الموعد');
  String get appointmentDeleted => _t('Appointment deleted.', 'تم حذف الموعد.');
  String get appointmentUpdated => _t('Appointment updated!', 'تم تحديث الموعد!');

  // Doctor - Patient Actions
  String get sendNote => _t('Send a Note', 'إرسال ملاحظة');
  String get viewEditSoap => _t('View & Edit SOAP', 'عرض وتعديل SOAP');
  String get selectAction => _t('Select an action', 'اختر إجراءً');
  String get soapDoctorOnly => _t('Doctor documentation only', 'وثائق الطبيب فقط');
  String get noteContent => _t('Write your note here...', 'اكتب ملاحظتك هنا...');
  String get noteSent => _t('Note sent!', 'تم إرسال الملاحظة!');

  // Doctor - Documentation tab
  String get documentation => _t('Documentation', 'التوثيق');
  String get addDocumentation => _t('Add Documentation', 'إضافة توثيق');
  String get noDocumentation => _t('No documentation yet.\nTap + to document a patient.', 'لا يوجد توثيق بعد.\nاضغط + لتوثيق مريض.');
  String get noteCount => _t('notes', 'ملاحظات');
  String get lastDoc => _t('Last', 'آخر');
  String get pickPatient => _t('Select Patient', 'اختر مريضاً');

  // Doctor - Schedule / Calendar
  String get todaySessions => _t('Today\'s Sessions', 'جلسات اليوم');
  String get noSessionsDay => _t('No sessions on this day', 'لا جلسات في هذا اليوم');
  String get upcomingBadge => _t('Upcoming', 'قادمة');
  String get pastBadge => _t('Past', 'منتهية');

  // Doctor - Billing
  String get invoices => _t('Invoices', 'الفواتير');
  String get newInvoice => _t('New Invoice', 'فاتورة جديدة');
  String get amount => _t('Amount', 'المبلغ');
  String get currency => _t('Currency', 'العملة');
  String get description => _t('Description', 'الوصف');
  String get statusPending => _t('Pending', 'معلق');
  String get statusPaid => _t('Paid', 'مدفوع');
  String get statusCancelled => _t('Cancelled', 'ملغي');
  String get markAsPaid => _t('Mark as Paid', 'تحديد كمدفوع');
  String get totalRevenue => _t('Total Revenue', 'إجمالي الإيرادات');
  String get createInvoice => _t('Create Invoice', 'إنشاء فاتورة');
  String get invoiceCreated => _t('Invoice created!', 'تم إنشاء الفاتورة!');

  // Doctor - Inventory
  String get clinicInventory => _t('Clinic Inventory', 'مخزون العيادة');
  String get addItem => _t('Add Item', 'إضافة عنصر');
  String get itemName => _t('Item Name', 'اسم العنصر');
  String get category => _t('Category', 'الفئة');
  String get quantity => _t('Quantity', 'الكمية');
  String get unit => _t('Unit', 'الوحدة');
  String get minQuantity => _t('Min. Quantity Alert', 'الحد الأدنى للتنبيه');
  String get lowStock => _t('Low Stock', 'مخزون منخفض');
  String get inStock => _t('In Stock', 'متوفر');

  // Doctor - Profile
  String get editInfo => _t('Edit Info', 'تحرير المعلومات');
  String get personalInformation => _t('Personal Information', 'المعلومات الشخصية');
  String get professionalOverview => _t('Professional Overview', 'نظرة عامة مهنية');
  String get experience => _t('Experience', 'الخبرة');
  String get certifications => _t('Certifications', 'الشهادات');
  String get expertiseAreas => _t('Expertise Areas', 'مجالات الخبرة');
  String get languages => _t('Languages', 'اللغات');
  String get yearsOfExperience => _t('Years', 'سنوات');
  String get contact => _t('Contact', 'جهة الاتصال');

  // Doctor - Profile
  String get editProfile => _t('Edit Profile', 'تعديل الملف');
  String get fullName => _t('Full Name', 'الاسم الكامل');
  String get specialization => _t('Specialization', 'التخصص');
  String get bio => _t('Bio / About', 'نبذة / عن الطبيب');
  String get clinicName => _t('Clinic Name', 'اسم العيادة');
  String get clinicAddress => _t('Clinic Address', 'عنوان العيادة');
  String get homeVisit => _t('Offers Home Visits', 'يقدم زيارات منزلية');
  String get profilePhotoUrl => _t('Profile Photo URL', 'رابط صورة الملف');
  String get saveProfile => _t('Save Profile', 'حفظ الملف');
  String get profileSaved => _t('Profile saved successfully!', 'تم حفظ الملف بنجاح!');
  String get updateLocation => _t('Update My Location', 'تحديث موقعي');

  // Patient Dashboard
  String get patientDashboard => _t('My Health Portal', 'بوابة صحتي');
  String get myHealth => _t('My Health', 'صحتي');
  String get findTherapist => _t('Find Therapist', 'ابحث عن معالج');
  String get notifications => _t('Notifications', 'الإشعارات');
  String get upcomingSessions => _t('Upcoming Sessions', 'الجلسات القادمة');
  String get clinicalNotes => _t('Clinical Notes & History', 'الملاحظات السريرية');
  String get noUpcomingSessions => _t('No upcoming sessions scheduled.', 'لا توجد جلسات قادمة مجدولة.');
  String get noNotes => _t('No clinical notes yet.', 'لا توجد ملاحظات سريرية بعد.');
  // Patient Dashboard — header & greeting
  String get welcome => _t('Welcome', 'مرحباً');
  String get goodMorning => _t('Good Morning', 'صباح الخير');
  String get goodAfternoon => _t('Good Afternoon', 'مساء الخير');
  String get goodEvening => _t('Good Evening', 'مساء النور');
  // Patient Dashboard — appointment banner
  String get noUpcomingAppointments => _t('No Upcoming Appointments', 'لا توجد مواعيد قادمة');
  String get bookSessionToday => _t('Book a session with your doctor today.', 'احجز جلسة مع طبيبك اليوم.');
  String get upcomingAppointment => _t('Upcoming Appointment', 'الموعد القادم');
  String get viewDetails => _t('View Details', 'عرض التفاصيل');
  // Patient — appointments screen
  String get myAppointments => _t('My Appointments', 'مواعيدي');
  String get upcomingTab => _t('Upcoming', 'القادمة');
  String get requestedTab => _t('Requested', 'المطلوبة');
  String get previousTab => _t('Previous', 'السابقة');
  String get summaryTab => _t('Summary', 'الملخص');
  String get totalSessionsAttended => _t('Total Sessions Attended', 'إجمالي الجلسات المحضورة');
  String get sessionsByDoctor => _t('Sessions by Doctor', 'الجلسات حسب الطبيب');
  String get noUpcomingApptsMsg => _t('No upcoming appointments.', 'لا توجد مواعيد قادمة.');
  String get noPastApptsMsg => _t('No past appointments yet.', 'لا توجد مواعيد سابقة بعد.');
  String get noRequestsMsg => _t('No appointment requests yet.', 'لا توجد طلبات مواعيد بعد.');
  String get noSessionsMsg => _t('No sessions attended yet.', 'لم تحضر أي جلسات بعد.');
  String get reschedule => _t('Reschedule', 'إعادة الجدولة');
  String get completed => _t('Completed', 'مكتمل');
  String get contactYourDoctor => _t('Contact your doctor to reschedule.', 'تواصل مع طبيبك لإعادة الجدولة.');
  String get cancelAppointment => _t('Cancel Appointment', 'إلغاء الموعد');
  String get cancelAppointmentConfirm => _t(
    'Are you sure you want to cancel this appointment?',
    'هل أنت متأكد من إلغاء هذا الموعد؟',
  );
  String get keepIt => _t('Keep It', 'احتفظ به');
  String get cancelIt => _t('Cancel It', 'إلغاء');
  String get appointmentCancelled => _t('Appointment cancelled.', 'تم إلغاء الموعد.');
  String lastSessionDate(String date) => _t('Last session: $date', 'آخر جلسة: $date');
  // Patient — my doctors screen
  String get myDoctors => _t('My Doctors/Therapists', 'أطبائي / معالجيّ');
  String get searchDoctors => _t('Search doctors', 'ابحث عن أطباء');
  String get noDoctorsAdded => _t('No Doctors Added', 'لم يضف أطباء بعد');
  String get searchForDoctor => _t('Search for a doctor and add them to your list.', 'ابحث عن طبيب وأضفه إلى قائمتك.');
  String get findDoctorOrTherapist => _t('Find a Doctor or Therapist', 'ابحث عن طبيب أو معالج');
  String noResultsFor(String q) => _t('No results for "$q"', 'لا نتائج لـ "$q"');
  // Notification permission rationale (shown before iOS system dialog)
  String get notifPermTitle => _t('Stay Updated', 'ابقَ على اطلاع');
  String get notifPermBody => _t(
    'PhysioConnect sends reminders for upcoming sessions and new clinical notes from your care team.',
    'يرسل فيزيو كونكت تذكيرات بالجلسات القادمة والملاحظات السريرية الجديدة من فريق رعايتك.',
  );
  String get notifPermAllow => _t('Allow', 'السماح');
  String get notifPermNotNow => _t('Not Now', 'ليس الآن');

  // Privacy policy — replace URL with your real hosted page before Store submission
  static const String privacyPolicyUrl = 'https://jihadzhour-dot.github.io/physioconnect-privacy/';
  String get privacyPolicy => _t('Privacy Policy', 'سياسة الخصوصية');

  // Find Therapist
  String get nearbyTherapists => _t('Nearby Therapists', 'معالجون قريبون');
  String get searchTherapists => _t('Search therapists...', 'ابحث عن معالجين...');
  String get allTherapists => _t('All Therapists', 'جميع المعالجين');
  String get nearby => _t('Nearby', 'قريب');
  String get kmAway => _t('km away', 'كم');
  String get selectTherapist => _t('Select', 'اختيار');
  String get therapistLinked => _t('Therapist linked to your care team!', 'تم ربط المعالج بفريق رعايتك!');
  String get homeVisitAvailable => _t('Home Visit Available', 'الزيارة المنزلية متاحة');

  // Notifications
  String get newSessionAlert => _t('New session scheduled', 'تمت جدولة جلسة جديدة');
  String get newNoteAlert => _t('New clinical note added', 'تمت إضافة ملاحظة سريرية جديدة');
  String get reminderAlert => _t('Session reminder', 'تذكير بالجلسة');
}
