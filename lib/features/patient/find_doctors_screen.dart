import 'dart:math';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/language_provider.dart';
import 'patient_service.dart';

class FindDoctorsScreen extends StatefulWidget {
  /// When true, this screen is shown to a patient who has not signed in
  /// (mobile "Continue as Guest" flow). Browsing/searching for therapists
  /// stays available, but actions that require an account (e.g. "Add to My
  /// List") show a sign-in prompt instead of writing any data.
  final bool isGuest;

  const FindDoctorsScreen({super.key, this.isGuest = false});

  @override
  State<FindDoctorsScreen> createState() => _FindDoctorsScreenState();
}

class _FindDoctorsScreenState extends State<FindDoctorsScreen> {
  final _supabase = Supabase.instance.client;
  final _service = PatientService();
  final _searchCtrl = TextEditingController();
  final MapController _mapController = MapController();

  Position? _myPosition;
  bool _nearbyMode = false;
  bool _homeVisitOnly = false;
  bool _locating = false;
  bool _showMap = false;
  String _searchQuery = '';

  Set<String> _linkedDoctorIds = {};

  // Guest-mode doctors: loaded once via REST after anonymous sign-in.
  List<Map<String, dynamic>>? _guestDoctors;
  // True when we created the anon session ourselves so we can sign out on leave.
  bool _ownedAnonSession = false;

  @override
  void initState() {
    super.initState();
    if (widget.isGuest) {
      _loadGuestDoctors();
    } else {
      _loadLinkedDoctors();
    }
  }

  Future<void> _loadGuestDoctors() async {
    // Try an anonymous Supabase session so RLS policies that require
    // auth.uid() (role = 'authenticated') are satisfied without creating a
    // real account. If anonymous auth is disabled in the Supabase project
    // this will throw — we swallow it and fall through to the query anyway,
    // which may still succeed if the table has an anon-role read policy.
    if (_supabase.auth.currentUser == null) {
      try {
        await _supabase.auth.signInAnonymously();
        _ownedAnonSession = true;
      } catch (_) {}
    }
    try {
      final data = await _supabase
          .from('users')
          .select()
          .eq('role', 'doctor');
      if (mounted) setState(() => _guestDoctors = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      if (mounted) {
        setState(() => _guestDoctors = []);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load therapists: $e')),
        );
      }
    }
  }

  Future<void> _loadLinkedDoctors() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final data = await _supabase
        .from('users')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (data == null || !mounted) return;
    final ids = (data['doctor_ids'] as List?)?.cast<String>().toSet() ?? {};
    setState(() => _linkedDoctorIds = ids);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _mapController.dispose();
    // Clean up the anonymous session we created so the login screen
    // doesn't inherit an unexpected auth state.
    if (_ownedAnonSession) _supabase.auth.signOut();
    super.dispose();
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  Future<void> _getLocation() async {
    setState(() => _locating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(defaultTargetPlatform == TargetPlatform.windows
                ? 'Location denied. Enable in Windows Settings → Privacy & security → Location.'
                : 'Location denied. Please enable location in your device settings.'),
          ));
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (mounted) {
        setState(() => _myPosition = pos);
        _mapController.move(LatLng(pos.latitude, pos.longitude), 13);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Location error: $e')));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Routes "Add to My List" through the guest sign-in prompt when browsing
  /// without an account; otherwise performs the action normally.
  void _handleAddToList(String doctorId) {
    if (widget.isGuest) {
      _showGuestSignInPrompt();
      return;
    }
    _addToMyList(doctorId);
  }

  void _showGuestSignInPrompt() {
    final s = AppStrings(context.read<LanguageProvider>().isArabic);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.guestSignInRequiredTitle),
        content: Text(s.guestSignInPrompt),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            child: Text(s.signIn),
          ),
        ],
      ),
    );
  }

  Future<void> _addToMyList(String doctorId) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _service.addDoctorToMyList(doctorId);
    if (!mounted) return;
    if (ok) {
      setState(() => _linkedDoctorIds.add(doctorId));
      messenger.showSnackBar(const SnackBar(
        content: Text('Doctor added to your list!'),
        backgroundColor: AppColors.success,
      ));
    } else {
      messenger.showSnackBar(const SnackBar(
        content: Text('Failed to add doctor. Try again.'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  // ── Filter logic ──────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> docs) {
    var result = docs;

    if (_searchQuery.isNotEmpty) {
      result = result.where((data) {
        final name = (data['name'] ?? '').toString().toLowerCase();
        final spec = (data['specialization'] ?? '').toString().toLowerCase();
        final clinic = (data['clinic_name'] ?? '').toString().toLowerCase();
        final bio = (data['bio'] ?? '').toString().toLowerCase();
        final exp = (data['experience'] ?? '').toString().toLowerCase();
        final q = _searchQuery;
        return name.contains(q) ||
            spec.contains(q) ||
            clinic.contains(q) ||
            bio.contains(q) ||
            exp.contains(q);
      }).toList();
    }

    if (_homeVisitOnly) {
      result = result.where((data) {
        return (data['offers_home_visit'] as bool?) ?? false;
      }).toList();
    }

    result = result.where((data) {
      return (data['show_in_search'] as bool?) ?? true;
    }).toList();

    if (_nearbyMode && _myPosition != null) {
      result.sort((a, b) {
        double distA = double.maxFinite;
        double distB = double.maxFinite;
        if (a['latitude'] != null && a['longitude'] != null) {
          distA = _distanceKm(
              _myPosition!.latitude,
              _myPosition!.longitude,
              (a['latitude'] as num).toDouble(),
              (a['longitude'] as num).toDouble());
        }
        if (b['latitude'] != null && b['longitude'] != null) {
          distB = _distanceKm(
              _myPosition!.latitude,
              _myPosition!.longitude,
              (b['latitude'] as num).toDouble(),
              (b['longitude'] as num).toDouble());
        }
        return distA.compareTo(distB);
      });
    }

    return result;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<LanguageProvider>().isArabic);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(s.findTherapist,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.patientGradientStart,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _showMap ? Icons.list_rounded : Icons.map_rounded,
              color: Colors.white,
            ),
            tooltip: _showMap ? 'List View' : 'Map View',
            onPressed: () {
              setState(() => _showMap = !_showMap);
              if (_showMap && _myPosition == null) _getLocation();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const Key('find_doctors_search'),
                  controller: _searchCtrl,
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by name, specialization, clinic…',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.primary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                color: AppColors.textSecondary),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF0F4F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _chip('All', !_nearbyMode && !_homeVisitOnly, () {
                      setState(() {
                        _nearbyMode = false;
                        _homeVisitOnly = false;
                      });
                    }),
                    const SizedBox(width: 8),
                    _chip(
                      _locating ? 'Locating…' : 'Nearby',
                      _nearbyMode,
                      () async {
                        setState(() => _nearbyMode = !_nearbyMode);
                        if (_nearbyMode && _myPosition == null) {
                          await _getLocation();
                        }
                      },
                      icon: Icons.near_me_rounded,
                    ),
                    const SizedBox(width: 8),
                    _chip('Home Visit', _homeVisitOnly, () {
                      setState(() => _homeVisitOnly = !_homeVisitOnly);
                    }, icon: Icons.home_rounded),
                  ]),
                ),
              ],
            ),
          ),

          Expanded(
            child: widget.isGuest
                ? _buildGuestDoctorList(s)
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _supabase
                        .from('users')
                        .stream(primaryKey: ['id'])
                        .eq('role', 'doctor'),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = _filter(snap.data ?? []);
                      if (_showMap) return _buildMapView(docs, s);
                      return _buildListView(docs, s);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap,
      {IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : const Color(0xFFF0F4F8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon,
                size: 13,
                color: active ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ]),
      ),
    );
  }

  // ── Guest doctor list (no auth — uses pre-loaded REST data) ─────────────

  Widget _buildGuestDoctorList(AppStrings s) {
    if (_guestDoctors == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final docs = _filter(_guestDoctors!);
    if (_showMap) return _buildMapView(docs, s);
    // Pull-to-refresh so guests see doctor profile updates (e.g. home-visit
    // toggle saved after the screen was already open) without reopening.
    return RefreshIndicator(
      onRefresh: _loadGuestDoctors,
      child: _buildListView(docs, s),
    );
  }

  // ── Map view ──────────────────────────────────────────────────────────────

  Widget _buildMapView(List<Map<String, dynamic>> docs, AppStrings s) {
    const defaultCenter = LatLng(33.8869, 35.5131);
    final initial = _myPosition != null
        ? LatLng(_myPosition!.latitude, _myPosition!.longitude)
        : defaultCenter;

    final doctorMarkers = <Marker>[];
    for (final data in docs) {
      if (data['latitude'] == null || data['longitude'] == null) continue;
      final lat = (data['latitude'] as num).toDouble();
      final lng = (data['longitude'] as num).toDouble();
      final name = (data['name'] ?? 'Therapist') as String;
      doctorMarkers.add(Marker(
        point: LatLng(lat, lng),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _showDoctorSheet(data, s),
          child: Stack(alignment: Alignment.topCenter, children: [
            const Icon(Icons.location_pin, color: Colors.green, size: 44),
            Positioned(
              top: 4,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: Colors.white,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'D',
                  style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                ),
              ),
            ),
          ]),
        ),
      ));
    }

    return Stack(children: [
      FlutterMap(
        mapController: _mapController,
        options: MapOptions(initialCenter: initial, initialZoom: 13),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.physioconnect.app',
          ),
          if (_myPosition != null)
            MarkerLayer(markers: [
              Marker(
                point:
                    LatLng(_myPosition!.latitude, _myPosition!.longitude),
                width: 32,
                height: 32,
                child: const Icon(Icons.my_location_rounded,
                    color: AppColors.primary, size: 32),
              ),
            ]),
          MarkerLayer(markers: doctorMarkers),
        ],
      ),
      Positioned(
        top: 12,
        left: 12,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6)
            ],
          ),
          child: Row(children: [
            const Icon(Icons.place_rounded,
                color: AppColors.primary, size: 16),
            const SizedBox(width: 4),
            Text(
              '${docs.where((d) => d['latitude'] != null).length} on map',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ]),
        ),
      ),
    ]);
  }

  // ── Full doctor detail sheet ──────────────────────────────────────────────
  // Shown when a user taps any doctor card (list or map). Works for both
  // authenticated patients and guests — the Add-to-List button routes
  // guests to the sign-in prompt via _handleAddToList.

  void _showDoctorSheet(Map<String, dynamic> data, AppStrings s) =>
      _showFullDoctorSheet(data, s);

  void _showFullDoctorSheet(Map<String, dynamic> data, AppStrings s) {
    final docId        = data['id'] as String;
    final name         = data['name'] as String? ?? 'Therapist';
    final spec         = data['specialization'] as String? ?? '';
    final bio          = data['bio'] as String? ?? '';
    final photo        = data['profile_photo_url'] as String? ?? '';
    final clinic       = data['clinic_name'] as String? ?? '';
    final address      = data['clinic_address'] as String? ?? '';
    final phone        = data['phone'] as String? ?? '';
    final workingHours = (data['working_hours'] as String? ?? '').trim();
    final homeVisit    = (data['offers_home_visit'] as bool?) ?? false;
    final exp          = data['experience'] as String? ?? '';
    final cert         = data['certifications'] as String? ?? '';
    final showDr       = (data['show_dr_prefix'] as bool?) ?? false;
    final isLinked     = _linkedDoctorIds.contains(docId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.80,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage:
                      photo.isNotEmpty ? NetworkImage(photo) : null,
                  child: photo.isEmpty
                      ? const Icon(Icons.person_rounded,
                          size: 44, color: AppColors.primary)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  showDr && name.isNotEmpty ? 'Dr. $name' : name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
              if (spec.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(spec,
                        style: const TextStyle(
                            color: AppColors.primary, fontSize: 13)),
                  ),
                ),
              const SizedBox(height: 20),
              if (clinic.isNotEmpty)
                _detailRow(Icons.business_rounded, clinic),
              if (address.isNotEmpty)
                _detailRow(Icons.location_on_rounded, address),
              if (phone.isNotEmpty)
                _detailRow(Icons.phone_rounded, phone,
                    color: AppColors.primary,
                    onTap: () => _openPhone(phone)),
              if (exp.isNotEmpty)
                _detailRow(Icons.work_history_rounded, '$exp experience'),
              if (cert.isNotEmpty)
                _detailRow(Icons.military_tech_rounded, cert),
              if (homeVisit)
                _detailRow(Icons.home_rounded, 'Home visits available',
                    color: Colors.green),
              if (workingHours.isNotEmpty)
                _detailRow(Icons.access_time_rounded, workingHours,
                    color: const Color(0xFF1565C0)),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('About',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Text(bio,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.5)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(
                    isLinked
                        ? Icons.check_circle_rounded
                        : Icons.person_add_rounded,
                    size: 16,
                  ),
                  label: Text(
                      isLinked ? 'Added to My List' : 'Add to My List'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isLinked ? Colors.green : AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isLinked
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          _handleAddToList(docId);
                        },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text,
      {Color color = AppColors.textSecondary, VoidCallback? onTap}) {
    if (text.isEmpty) return const SizedBox.shrink();
    Widget row = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
            child:
                Text(text, style: TextStyle(color: color, fontSize: 13))),
        if (onTap != null)
          const Icon(Icons.open_in_new_rounded,
              size: 14, color: AppColors.primary),
      ]),
    );
    if (onTap != null) return GestureDetector(onTap: onTap, child: row);
    return row;
  }

  void _openPhone(String phone) {
    if (phone.isEmpty) return;
    final cleaned = phone.replaceAll(RegExp(r'[\s\-()+]'), '');
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(phone,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _phoneAction(
                  Icons.phone_rounded,
                  'Call',
                  const Color(0xFF00695C),
                  () => launchUrl(Uri.parse('tel:$cleaned')),
                ),
                _phoneAction(
                  Icons.chat_rounded,
                  'WhatsApp',
                  const Color(0xFF25D366),
                  () => launchUrl(
                      Uri.parse('https://wa.me/$cleaned'),
                      mode: LaunchMode.externalApplication),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Widget _phoneAction(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── List view ─────────────────────────────────────────────────────────────

  Widget _buildListView(List<Map<String, dynamic>> docs, AppStrings s) {
    if (docs.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded,
              size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(s.noData,
              style: const TextStyle(color: AppColors.textSecondary)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final data = docs[i];
        final docId = data['id'] as String;
        final name = data['name'] as String? ?? 'Therapist';
        final spec = data['specialization'] as String? ?? 'Physical Therapist';
        final bio = data['bio'] as String? ?? '';
        final photo = data['profile_photo_url'] as String? ?? '';
        final clinic = data['clinic_name'] as String? ?? '';
        final address = data['clinic_address'] as String? ?? '';
        final homeVisit = (data['offers_home_visit'] as bool?) ?? false;
        final exp = data['experience'] as String? ?? '';
        final cert = data['certifications'] as String? ?? '';
        final isLinked = _linkedDoctorIds.contains(docId);
        final showDr = (data['show_dr_prefix'] as bool?) ?? false;

        double? dist;
        if (_myPosition != null &&
            data['latitude'] != null &&
            data['longitude'] != null) {
          dist = _distanceKm(
            _myPosition!.latitude,
            _myPosition!.longitude,
            (data['latitude'] as num).toDouble(),
            (data['longitude'] as num).toDouble(),
          );
        }

        return _DoctorListCard(
          s: s,
          docId: docId,
          name: name,
          spec: spec,
          bio: bio,
          photo: photo,
          clinic: clinic,
          address: address,
          homeVisit: homeVisit,
          experience: exp,
          certifications: cert,
          distanceKm: dist,
          isLinked: isLinked,
          showDrPrefix: showDr,
          onAddToList: () => _handleAddToList(docId),
          onTap: () => _showFullDoctorSheet(data, s),
        );
      },
    );
  }
}

// ── Doctor list card ───────────────────────────────────────────────────────

class _DoctorListCard extends StatelessWidget {
  final AppStrings s;
  final String docId;
  final String name;
  final String spec;
  final String bio;
  final String photo;
  final String clinic;
  final String address;
  final bool homeVisit;
  final String experience;
  final String certifications;
  final double? distanceKm;
  final bool isLinked;
  final bool showDrPrefix;
  final VoidCallback onAddToList;
  final VoidCallback? onTap;

  const _DoctorListCard({
    required this.s,
    required this.docId,
    required this.name,
    required this.spec,
    required this.bio,
    required this.photo,
    required this.clinic,
    required this.address,
    required this.homeVisit,
    required this.experience,
    required this.certifications,
    required this.distanceKm,
    required this.isLinked,
    required this.showDrPrefix,
    required this.onAddToList,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage:
                  photo.isNotEmpty ? NetworkImage(photo) : null,
              child: photo.isEmpty
                  ? const Icon(Icons.person_rounded,
                      color: AppColors.primary, size: 28)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(showDrPrefix && name.isNotEmpty ? 'Dr. $name' : name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(spec,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                if (distanceKm != null)
                  Row(children: [
                    const Icon(Icons.near_me_rounded,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Text(
                        '${distanceKm!.toStringAsFixed(1)} ${s.kmAway}',
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12)),
                  ]),
              ]),
            ),
            if (isLinked)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Icon(Icons.check_circle_rounded,
                      size: 12, color: Colors.green),
                  SizedBox(width: 3),
                  Text('My Doctor',
                      style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),

          if (homeVisit || experience.isNotEmpty || certifications.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (homeVisit)
                _infoBadge(Icons.home_rounded, 'Home Visit',
                    Colors.green.shade700, Colors.green.shade50),
              if (experience.isNotEmpty)
                _infoBadge(Icons.work_history_rounded, experience,
                    const Color(0xFF1565C0), const Color(0xFFE3F2FD)),
              if (certifications.isNotEmpty)
                _infoBadge(Icons.military_tech_rounded, certifications,
                    const Color(0xFF6A1B9A), const Color(0xFFF3E5F5)),
            ]),
          ],

          if (bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(bio,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],

          if (clinic.isNotEmpty || address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.business_rounded,
                  size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  [clinic, address].where((e) => e.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ]),
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(
                isLinked
                    ? Icons.check_circle_rounded
                    : Icons.person_add_rounded,
                size: 15,
              ),
              label: Text(
                isLinked ? 'Added to My List' : 'Add to My List',
                style: const TextStyle(fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isLinked ? Colors.green : AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isLinked ? null : onAddToList,
            ),
          ),
        ]),
      ),
    ),    // Card
    );    // GestureDetector
  }

  Widget _infoBadge(
      IconData icon, String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: textColor),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
