import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';

class DoctorLocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const DoctorLocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<DoctorLocationPickerScreen> createState() =>
      _DoctorLocationPickerScreenState();
}

class _DoctorLocationPickerScreenState
    extends State<DoctorLocationPickerScreen> {
  final MapController _mapCtrl = MapController();
  LatLng? _picked;
  bool _saving = false;
  bool _locating = false;

  static const _defaultCenter = LatLng(31.9454, 35.9284); // Amman, Jordan

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _picked = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  Future<void> _useGps() async {
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
            content: Text(Platform.isWindows
                ? 'Location denied. Enable in Windows Settings → Privacy & security → Location.'
                : 'Location permission denied. Enable in settings.'),
          ));
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _picked = latLng);
        _mapCtrl.move(latLng, 15);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('GPS error: $e')));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (_picked == null) return;
    setState(() => _saving = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('users').update({
        'latitude': _picked!.latitude,
        'longitude': _picked!.longitude,
        'location_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Clinic location saved!'),
          backgroundColor: AppColors.success,
        ));
        Navigator.pop(context, _picked);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = _picked ?? _defaultCenter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Clinic Location',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.doctorGradientStart,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          _locating
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.my_location_rounded),
                  tooltip: 'Use GPS',
                  onPressed: _useGps,
                ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: initial,
              initialZoom: _picked != null ? 15 : 12,
              onTap: (_, latLng) => setState(() => _picked = latLng),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.physioconnect.app',
              ),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 48,
                      height: 48,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.green,
                        size: 48,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Instruction banner
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6)
                ],
              ),
              child: const Row(children: [
                Icon(Icons.touch_app_rounded,
                    color: AppColors.primary, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap the map to pin your clinic. Tap again to repin.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ]),
            ),
          ),

          // Coordinates readout
          if (_picked != null)
            Positioned(
              bottom: 92,
              left: 12,
              right: 12,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4)
                    ],
                  ),
                  child: Text(
                    '${_picked!.latitude.toStringAsFixed(5)}, '
                    '${_picked!.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),

          // Save button
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: ElevatedButton.icon(
              onPressed: _picked == null || _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: Text(_picked == null
                  ? 'Tap map to pin location'
                  : 'Save Clinic Location'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
