import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/feed_backgrounds.dart';
import '../../core/theme/spyce_colors.dart';
import '../../core/utils/language_labels.dart';
import '../../data/models/user_models.dart';
import '../../data/repositories/api_repositories.dart';
import '../../shared/widgets/spyce_widgets.dart';
import '../auth/auth_controller.dart';

/// Max photo slots on profile (matches product: 1–5).
const int kMaxProfilePhotoSlots = 5;

/// Full profile editor — backend allows editing everything except gender
/// once set (UserProfile.clean validates gender immutable).
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  UserProfile? profile;
  bool loading = true;
  bool saving = false;
  bool locationLoading = false;
  String? error;
  /// Local path shown immediately after pick while server processes upload.
  String? pendingLocalPhotoPath;

  List<CatalogOption> sexualityOpts = [];
  List<CatalogOption> intentOpts = [];
  List<CatalogOption> genderOpts = [];
  List<CatalogOption> turnOnOpts = [];
  List<CatalogOption> languageOpts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final opts = ref.read(optionsRepositoryProvider);
    try {
      final results = await Future.wait([
        ref.read(profileRepositoryProvider).getMyProfile(),
        opts.sexualities(),
        opts.intents(),
        opts.genders(),
        opts.turnOns(),
        opts.languages(),
      ]);
      if (!mounted) return;
      final langs = results[5] as List<CatalogOption>;
      LanguageLabels.setCatalog(langs);
      final loaded = results[0] as UserProfile;
      final fixedLangs = LanguageLabels.resolveAll([
        ...loaded.languageLabels,
        ...loaded.languageIds,
      ]);
      setState(() {
        profile = loaded.copyWith(
          languageLabels:
              fixedLangs.isNotEmpty ? fixedLangs : loaded.languageLabels,
        );
        sexualityOpts = results[1] as List<CatalogOption>;
        intentOpts = results[2] as List<CatalogOption>;
        genderOpts = results[3] as List<CatalogOption>;
        turnOnOpts = results[4] as List<CatalogOption>;
        languageOpts = langs;
        loading = false;
      });
      // Auto-detect device location when profile has no coords yet.
      if (loaded.latitude == null || loaded.longitude == null) {
        // ignore: unawaited_futures
        _detectAndSaveLocation(silent: true);
      }
    } catch (_) {
      final user = ref.read(authControllerProvider).user;
      if (!mounted) return;
      setState(() {
        profile = UserProfile(
          id: user?.id ?? 'me',
          username: user?.username ?? 'you',
          bio: 'Complete your profile to shine on the feed.',
          bgId: 'B01',
          bgVariantId: 'B01-coral',
          isDiscoverable: true,
        );
        loading = false;
      });
    }
  }

  Future<void> _patch(Map<String, dynamic> fields) async {
    setState(() => saving = true);
    try {
      final updated =
          await ref.read(profileRepositoryProvider).updateMyProfile(fields);
      if (!mounted) return;
      setState(() {
        profile = updated;
        saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      // Offline optimistic merge
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved locally (offline)')),
      );
    }
  }

  /// Request device location permission, read GPS, reverse-geocode, PATCH profile.
  Future<void> _detectAndSaveLocation({bool silent = false}) async {
    if (locationLoading) return;
    setState(() => locationLoading = true);

    try {
      // 1) Ensure location services are on
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Turn on Location Services to set your city'),
            ),
          );
        }
        if (mounted) setState(() => locationLoading = false);
        return;
      }

      // 2) Permission (permission_handler + geolocator)
      var perm = await Permission.locationWhenInUse.status;
      if (perm.isDenied || perm.isRestricted) {
        perm = await Permission.locationWhenInUse.request();
      }
      if (perm.isPermanentlyDenied) {
        if (!silent && mounted) {
          final open = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Location permission'),
              content: const Text(
                'Location is needed for nearby discovery. Open Settings to enable it.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
          if (open == true) await openAppSettings();
        }
        if (mounted) setState(() => locationLoading = false);
        return;
      }
      if (!perm.isGranted) {
        // Fallback to geolocator permission API
        var g = await Geolocator.checkPermission();
        if (g == LocationPermission.denied) {
          g = await Geolocator.requestPermission();
        }
        if (g == LocationPermission.denied ||
            g == LocationPermission.deniedForever) {
          if (!silent && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          if (mounted) setState(() => locationLoading = false);
          return;
        }
      }

      // 3) Read device position
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      // Always numbers (never String) — fixes "String is not a subtype of num"
      final lat = double.tryParse(pos.latitude.toStringAsFixed(6));
      final lon = double.tryParse(pos.longitude.toStringAsFixed(6));
      if (lat == null || lon == null) {
        throw StateError('Could not read GPS coordinates');
      }

      // 4) Reverse geocode via backend
      String? city;
      String? state;
      String? country;
      try {
        final geo = await ref
            .read(profileRepositoryProvider)
            .reverseGeocode(lat, lon);
        city = geo['city']?.toString();
        state = geo['state']?.toString();
        country = geo['country']?.toString();
        // Prefer city only for the city field; display_name is composite
        if (city == null || city.isEmpty || city == 'Unknown') {
          final display = geo['display_name']?.toString();
          if (display != null && display.isNotEmpty) {
            city = display.split(',').first.trim();
          }
        }
      } catch (_) {
        // Still save lat/lon even if reverse geocode fails
      }

      // 5) PATCH profile with coords + address fields (typed as num)
      final payload = <String, dynamic>{
        'latitude': lat,
        'longitude': lon,
        if (city != null && city.isNotEmpty && city != 'Unknown') 'city': city,
        if (state != null && state.isNotEmpty && state != 'Unknown')
          'state': state,
        if (country != null && country.isNotEmpty && country != 'Unknown')
          'country': country,
      };

      final updated =
          await ref.read(profileRepositoryProvider).updateMyProfile(payload);
      if (!mounted) return;
      setState(() {
        profile = updated;
        locationLoading = false;
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              city != null && city.isNotEmpty
                  ? 'Location set to $city'
                  : 'Location coordinates saved',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => locationLoading = false);
      if (!silent) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => locationLoading = false);
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not detect location: $e')),
        );
      }
    }
  }

  Future<void> _editText({
    required String title,
    required String field,
    String? initial,
    int maxLines = 1,
    int? maxLength,
  }) async {
    final ctrl = TextEditingController(text: initial ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          maxLines: maxLines,
          maxLength: maxLength,
          autofocus: true,
          decoration: InputDecoration(hintText: title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != null) await _patch({field: saved});
  }

  Future<void> _editSingleOption({
    required String title,
    required String field,
    required List<CatalogOption> options,
    String? currentId,
  }) async {
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Options unavailable offline')),
      );
      return;
    }
    String? selected = currentId;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: SpyceColors.dark800,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title,
                        style: GoogleFonts.syne(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: options.map((o) {
                          return RadioListTile<String>(
                            value: o.id,
                            // ignore: deprecated_member_use
                            groupValue: selected,
                            title: Text(o.name),
                            activeColor: SpyceColors.pink,
                            onChanged: (v) => setLocal(() => selected = v),
                          );
                        }).toList(),
                      ),
                    ),
                    SpycePrimaryButton(
                      label: 'Save',
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (ok == true && selected != null) {
      await _patch({field: selected});
    }
  }

  Future<void> _editMultiOption({
    required String title,
    required String field,
    required List<CatalogOption> options,
    required List<String> currentIds,
  }) async {
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Options unavailable offline')),
      );
      return;
    }
    final selected = {...currentIds};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: SpyceColors.dark800,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title,
                        style: GoogleFonts.syne(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                      ),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: options.map((o) {
                            final on = selected.contains(o.id);
                            return FilterChip(
                              label: Text(o.name),
                              selected: on,
                              onSelected: (v) => setLocal(() {
                                if (v) {
                                  selected.add(o.id);
                                } else {
                                  selected.remove(o.id);
                                }
                              }),
                              selectedColor: SpyceColors.pinkDim,
                              checkmarkColor: SpyceColors.pink,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SpycePrimaryButton(
                      label: 'Save',
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (ok == true) await _patch({field: selected.toList()});
  }

  Future<void> _editAgePrefs() async {
    var minA = (profile?.agePreferenceMin ?? 18).toDouble();
    var maxA = (profile?.agePreferenceMax ?? 45).toDouble();
    // Default Anywhere (worldwide / no radius). 1–1000 km when limited.
    var anywhere = profile?.isDiscoveryAnywhere ?? true;
    var dist = (profile?.effectiveDistanceKm ?? 50).toDouble().clamp(1.0, 1000.0);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: SpyceColors.dark800,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final distLabel = anywhere
                ? 'Anywhere · Worldwide'
                : (dist >= 1000
                    ? 'Up to 1000 km'
                    : 'Up to ${dist.round()} km');
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                28 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Discovery preferences',
                    style: GoogleFonts.syne(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Who shows up in your feed by age and how far away',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Age ${minA.round()} – ${maxA.round()} yrs',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  RangeSlider(
                    values: RangeValues(minA, maxA),
                    min: 18,
                    max: 80,
                    activeColor: SpyceColors.pink,
                    onChanged: (v) => setLocal(() {
                      minA = v.start;
                      maxA = v.end;
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Distance: $distLabel',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Anywhere'),
                        avatar: Icon(
                          Icons.public,
                          size: 16,
                          color: anywhere ? Colors.white : Colors.white70,
                        ),
                        selected: anywhere,
                        selectedColor: SpyceColors.pink,
                        labelStyle: TextStyle(
                          color: anywhere ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => setLocal(() => anywhere = true),
                      ),
                      ChoiceChip(
                        label: const Text('Near me'),
                        avatar: Icon(
                          Icons.near_me_outlined,
                          size: 16,
                          color: !anywhere ? Colors.white : Colors.white70,
                        ),
                        selected: !anywhere,
                        selectedColor: SpyceColors.pink,
                        labelStyle: TextStyle(
                          color: !anywhere ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => setLocal(() {
                          anywhere = false;
                          if (dist < 1) dist = 50;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    anywhere
                        ? 'No distance limit — discover worldwide (default).'
                        : 'Only people within your radius (1–1000 km).',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                  ),
                  if (!anywhere) ...[
                    const SizedBox(height: 8),
                    Slider(
                      value: dist.clamp(1.0, 1000.0),
                      min: 1,
                      max: 1000,
                      divisions: 999,
                      activeColor: SpyceColors.pink,
                      label: '${dist.round()} km',
                      onChanged: (v) => setLocal(() => dist = v),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('1 km',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 11)),
                        Text('1000 km',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 11)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  SpycePrimaryButton(
                    label: 'Save',
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (ok == true) {
      if (anywhere) {
        await _patch({
          'age_preference_min': minA.round(),
          'age_preference_max': maxA.round(),
          'discovery_radius_type': 'GLOBAL',
          'distance_preference_km': 0,
        });
      } else {
        await _patch({
          'age_preference_min': minA.round(),
          'age_preference_max': maxA.round(),
          'discovery_radius_type': 'DISTANCE',
          'distance_preference_km': dist.round().clamp(1, 1000),
        });
      }
    }
  }

  Future<void> _editHottakes() async {
    final existing = profile?.hottakes;
    List<String> list = [];
    if (existing is List) {
      list = existing.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    } else if (existing is Map) {
      list = existing.values.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    } else if (existing is String && existing.isNotEmpty) {
      list = [existing];
    }

    final c1 = TextEditingController(text: list.isNotEmpty ? list[0] : '');
    final c2 = TextEditingController(text: list.length > 1 ? list[1] : '');
    final c3 = TextEditingController(text: list.length > 2 ? list[2] : '');

    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpyceColors.dark800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hot Takes (Up to 3)', style: GoogleFonts.syne(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Share up to 3 hot takes for your profile:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 14),
              TextField(
                controller: c1,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Hot Take #1',
                  labelStyle: const TextStyle(color: SpyceColors.pinkSoft),
                  hintText: 'e.g., Pineapple belongs on pizza',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: c2,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Hot Take #2',
                  labelStyle: const TextStyle(color: SpyceColors.pinkSoft),
                  hintText: 'e.g., Dark mode is overrated',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: c3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Hot Take #3',
                  labelStyle: const TextStyle(color: SpyceColors.pinkSoft),
                  hintText: 'e.g., Coffee is better than tea',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              final out = <String>[];
              if (c1.text.trim().isNotEmpty) out.add(c1.text.trim());
              if (c2.text.trim().isNotEmpty) out.add(c2.text.trim());
              if (c3.text.trim().isNotEmpty) out.add(c3.text.trim());
              Navigator.pop(ctx, out);
            },
            style: ElevatedButton.styleFrom(backgroundColor: SpyceColors.pink, foregroundColor: Colors.white),
            child: const Text('Save Takes'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _patch({'hottakes': result});
    }
  }

  String _formatHotTakesValue(UserProfile? p) {
    if (p == null || p.hottakes == null) return 'Add hot takes (up to 3)';
    final raw = p.hottakes;
    List<String> list = [];
    if (raw is List) {
      list = raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    } else if (raw is Map) {
      list = raw.values.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    } else if (raw is String && raw.trim().isNotEmpty) {
      list = [raw.trim()];
    }

    if (list.isEmpty) return 'Add hot takes (up to 3)';
    if (list.length == 1) return '1 Take: "${list[0]}"';
    return '${list.length} Takes: "${list.first}"…';
  }

  String _formatLanguageValue(UserProfile? p) {
    if (p == null) return 'Select languages';
    final raw = <String>[
      ...p.languageLabels,
      ...p.languageIds,
    ];
    final labels = LanguageLabels.resolveAll(raw);
    if (labels.isEmpty) return 'Select languages';
    return labels.join(', ');
  }

  Future<void> _editLanguages() async {
    if (languageOpts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Language options unavailable')),
      );
      return;
    }
    LanguageLabels.setCatalog(languageOpts);
    final selected = LanguageLabels.selectedOptionIds(
      [...?profile?.languageLabels, ...?profile?.languageIds],
      languageOpts,
    );
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: SpyceColors.dark800,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Languages',
                      style: GoogleFonts.syne(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                      ),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: languageOpts.map((o) {
                            final on = selected.contains(o.id);
                            return FilterChip(
                              label: Text(o.name),
                              selected: on,
                              onSelected: (v) => setLocal(() {
                                if (v) {
                                  selected.add(o.id);
                                } else {
                                  selected.remove(o.id);
                                }
                              }),
                              selectedColor: SpyceColors.pinkDim,
                              checkmarkColor: SpyceColors.pink,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SpycePrimaryButton(
                      label: 'Save',
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (ok == true) {
      // Save human-readable names so feed never shows UUIDs
      final names = LanguageLabels.namesForSave(selected);
      await _patch({'languages': names});
    }
  }

  String _formatPreferredGendersValue(UserProfile? p) {
    if (p == null || p.preferredGenderIds.isEmpty) return 'Select preferred genders';
    final names = p.preferredGenderIds.map((id) {
      final opt = genderOpts.firstWhere(
        (o) => o.id == id,
        orElse: () => CatalogOption(id: id, name: id),
      );
      return opt.name;
    }).toList();
    return names.join(', ');
  }

  String _formatTurnOnsValue(UserProfile? p) {
    if (p == null) return 'Pick turn-ons';
    if (p.turnOnLabels.isNotEmpty) {
      final names = p.turnOnLabels.map((item) {
        final opt = turnOnOpts.firstWhere(
          (o) => o.id == item,
          orElse: () => CatalogOption(id: item, name: item),
        );
        return opt.name;
      }).toList();
      return names.take(3).join(', ');
    }
    if (p.turnOnIds.isNotEmpty) {
      final names = p.turnOnIds.map((id) {
        final opt = turnOnOpts.firstWhere(
          (o) => o.id == id,
          orElse: () => CatalogOption(id: id, name: id),
        );
        return opt.name;
      }).toList();
      return names.take(3).join(', ');
    }
    return 'Pick turn-ons';
  }

  Future<void> _chooseThemeBg() async {
    final result = await showModalBottomSheet<DiscoveryTheme>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SpyceColors.dark800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ThemePickerSheet(
        repo: ref.read(profileRepositoryProvider),
        initial: DiscoveryTheme(
          layoutId: profile?.layoutId,
          bgId: profile?.bgId,
          bgVariantId: profile?.bgVariantId,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      profile = profile?.copyWith(
        layoutId: result.layoutId,
        bgId: result.bgId,
        bgVariantId: result.bgVariantId,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Theme saved')),
    );
  }

  Future<void> _addOrChangeImage({String? replaceImageId}) async {
    final currentCount = profile?.images
            .where((i) => i.imageUrl.isNotEmpty || i.id.isNotEmpty)
            .length ??
        0;
    if (replaceImageId == null && currentCount >= kMaxProfilePhotoSlots) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can upload up to 5 photos. Tap one to replace or delete.'),
        ),
      );
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: SpyceColors.dark800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                replaceImageId != null ? 'Replace photo' : 'Add photo',
                style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Take a new picture or choose one from your gallery',
                style: TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: SpyceColors.pink.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_camera, color: SpyceColors.pink),
                ),
                title: const Text(
                  'Take photo',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Open camera',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const SizedBox(height: 4),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: SpyceColors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library, color: SpyceColors.teal),
                ),
                title: const Text(
                  'Choose from gallery',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Pick an existing photo',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;
    await _pickAndUploadImage(source, replaceImageId: replaceImageId);
  }

  Future<bool> _ensureImagePermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isGranted || status.isLimited) return true;
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera permission is required to take a photo'),
          action: status.isPermanentlyDenied
              ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
              : null,
        ),
      );
      return false;
    }

    // Gallery — photos permission on modern Android / iOS
    PermissionStatus status = await Permission.photos.request();
    if (status.isGranted || status.isLimited) return true;
    // Older Android may map to storage
    status = await Permission.storage.request();
    if (status.isGranted || status.isLimited) return true;
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Photo library permission is required'),
        action: status.isPermanentlyDenied
            ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
            : null,
      ),
    );
    return false;
  }

  Future<void> _pickAndUploadImage(
    ImageSource source, {
    String? replaceImageId,
  }) async {
    final allowed = await _ensureImagePermission(source);
    if (!allowed || !mounted) return;

    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (file == null || !mounted) return;

    final beforeIds =
        profile?.images.map((i) => i.id).where((id) => id.isNotEmpty).toSet() ??
            {};
    final beforeCount = profile?.images
            .where((i) => i.imageUrl.isNotEmpty || i.id.isNotEmpty)
            .length ??
        0;

    setState(() {
      saving = true;
      pendingLocalPhotoPath = file.path;
    });
    final repo = ref.read(profileRepositoryProvider);
    try {
      if (replaceImageId != null && replaceImageId.isNotEmpty) {
        try {
          await repo.deleteImage(replaceImageId);
        } on ApiException catch (e) {
          // Continue upload but surface delete failure for testing
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Replace delete warning: ${e.fullDetail}'),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } catch (_) {
          // Continue upload even if delete fails (e.g. already gone)
        }
      }
      final uploadRes = await repo.uploadImage(file.path);
      if (!mounted) return;

      final status = (uploadRes['status'] ?? '').toString().toLowerCase();
      final newId = (uploadRes['id'] ?? '').toString();
      final readyImmediately = status == 'ok' ||
          status == 'success' ||
          (newId.isNotEmpty && uploadRes['image_url'] != null);

      if (readyImmediately) {
        // Sync upload (201): photo is already on the profile
        await _load();
        if (!mounted) return;
        setState(() => pendingLocalPhotoPath = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo ready ✓')),
        );
      } else {
        // Legacy async path (202 processing) — poll until visible
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading photo…')),
        );
        final ready = await _refreshImagesAfterUpload(
          beforeIds: beforeIds,
          beforeCount: beforeCount,
        );
        if (!mounted) return;
        if (ready) {
          setState(() => pendingLocalPhotoPath = null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo ready ✓')),
          );
        } else {
          setState(() => pendingLocalPhotoPath = null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Photo is still processing. Pull down to refresh in a moment.',
              ),
              duration: Duration(seconds: 6),
            ),
          );
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => pendingLocalPhotoPath = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.fullDetail),
          duration: const Duration(seconds: 10),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => pendingLocalPhotoPath = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not upload photo: ${ApiException.describe(e)}'),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  /// Returns true when a new image is visible on the profile.
  Future<bool> _refreshImagesAfterUpload({
    required Set<String> beforeIds,
    required int beforeCount,
  }) async {
    final repo = ref.read(profileRepositoryProvider);
    Object? lastPollError;
    // Celery may take a few seconds; poll longer so success is visible
    for (var attempt = 0; attempt < 14; attempt++) {
      await Future.delayed(
        Duration(milliseconds: attempt == 0 ? 1000 : 1400),
      );
      if (!mounted) return false;
      try {
        final updated = await repo.getMyProfile();
        if (!mounted) return false;
        setState(() => profile = updated);
        final afterIds =
            updated.images.map((i) => i.id).where((id) => id.isNotEmpty).toSet();
        final newId = afterIds.difference(beforeIds).isNotEmpty;
        final moreSlots = updated.images
                .where((i) => i.imageUrl.isNotEmpty || i.id.isNotEmpty)
                .length >
            beforeCount;
        final newWithUrl = updated.images.any(
          (i) =>
              i.imageUrl.isNotEmpty &&
              (beforeIds.isEmpty || !beforeIds.contains(i.id)),
        );
        if (newId || moreSlots || newWithUrl) {
          return true;
        }
      } catch (e) {
        lastPollError = e;
      }
    }
    if (lastPollError != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile poll error: ${ApiException.describe(lastPollError)}',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
    return false;
  }

  List<ProfileImage> get _sortedPhotos {
    final list = List<ProfileImage>.from(profile?.images ?? const []);
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// Persist new order: slot 1 (index 0) is always the main/profile picture.
  Future<void> _applyPhotoOrder(List<ProfileImage> ordered) async {
    final payload = <Map<String, dynamic>>[
      for (var i = 0; i < ordered.length; i++)
        {'id': ordered[i].id, 'order': i + 1},
    ];
    // Optimistic UI — first image is the main/profile avatar
    final p = profile;
    if (p != null) {
      setState(() {
        profile = p.copyWith(
          images: [
            for (var i = 0; i < ordered.length; i++)
              ordered[i].copyWith(order: i + 1),
          ],
          photoStatus: 'CUSTOM',
        );
      });
    }
    setState(() => saving = true);
    try {
      await ref.read(profileRepositoryProvider).reorderImages(payload);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not rearrange photos')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _setAsMainPhoto(ProfileImage image) async {
    final photos = _sortedPhotos;
    final idx = photos.indexWhere((p) => p.id == image.id);
    if (idx <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already your main profile photo')),
      );
      return;
    }
    final next = List<ProfileImage>.from(photos);
    final item = next.removeAt(idx);
    next.insert(0, item);
    await _applyPhotoOrder(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Main profile photo updated')),
    );
  }

  Future<void> _movePhoto(ProfileImage image, {required int delta}) async {
    final photos = _sortedPhotos;
    final idx = photos.indexWhere((p) => p.id == image.id);
    if (idx < 0) return;
    final target = idx + delta;
    if (target < 0 || target >= photos.length) return;
    final next = List<ProfileImage>.from(photos);
    final item = next.removeAt(idx);
    next.insert(target, item);
    await _applyPhotoOrder(next);
  }

  Future<void> _swapPhotos(ProfileImage a, ProfileImage b) async {
    final photos = _sortedPhotos;
    final i = photos.indexWhere((p) => p.id == a.id);
    final j = photos.indexWhere((p) => p.id == b.id);
    if (i < 0 || j < 0 || i == j) return;
    final next = List<ProfileImage>.from(photos);
    final tmp = next[i];
    next[i] = next[j];
    next[j] = tmp;
    await _applyPhotoOrder(next);
  }

  Future<void> _pickSwapTarget(ProfileImage image) async {
    final photos = _sortedPhotos.where((p) => p.id != image.id).toList();
    if (photos.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add another photo to swap positions')),
      );
      return;
    }
    final target = await showModalBottomSheet<ProfileImage>(
      context: context,
      backgroundColor: SpyceColors.dark800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Swap with…',
                style: GoogleFonts.syne(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose which photo to swap positions with',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              for (final p in photos)
                ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: p.imageUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(
                    p.order <= 1 ? 'Slot 1 · Main photo' : 'Slot ${p.order}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(ctx, p),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
    if (target == null || !mounted) return;
    await _swapPhotos(image, target);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photos swapped')),
    );
  }

  Future<void> _onPhotoTap(ProfileImage image) async {
    final photos = _sortedPhotos;
    final idx = photos.indexWhere((p) => p.id == image.id);
    final isMain = idx == 0;
    final canMoveLeft = idx > 0;
    final canMoveRight = idx >= 0 && idx < photos.length - 1;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SpyceColors.dark800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_outlined, color: Colors.white70),
                title: const Text('View photo', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, 'view'),
              ),
              if (!isMain)
                ListTile(
                  leading: const Icon(Icons.star_rounded, color: SpyceColors.pink),
                  title: const Text(
                    'Set as main profile photo',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Moves this photo to slot 1',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onTap: () => Navigator.pop(ctx, 'main'),
                ),
              if (canMoveLeft)
                ListTile(
                  leading: const Icon(Icons.arrow_back, color: SpyceColors.pinkSoft),
                  title: const Text('Move left', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(ctx, 'left'),
                ),
              if (canMoveRight)
                ListTile(
                  leading: const Icon(Icons.arrow_forward, color: SpyceColors.pinkSoft),
                  title: const Text('Move right', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(ctx, 'right'),
                ),
              if (photos.length > 1)
                ListTile(
                  leading: const Icon(Icons.swap_horiz, color: SpyceColors.teal),
                  title: const Text('Swap with another photo', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(ctx, 'swap'),
                ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: SpyceColors.pinkSoft),
                title: const Text('Replace photo', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, 'replace'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFFF6B81)),
                title: const Text('Delete photo', style: TextStyle(color: Color(0xFFFF6B81))),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );

    if (action == null || !mounted) return;

    if (action == 'view') {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InteractiveViewer(
              child: Image.network(
                image.imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  color: SpyceColors.dark800,
                  padding: const EdgeInsets.all(40),
                  child: const Icon(Icons.broken_image, color: Colors.white38, size: 48),
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    if (action == 'main') {
      await _setAsMainPhoto(image);
      return;
    }
    if (action == 'left') {
      await _movePhoto(image, delta: -1);
      return;
    }
    if (action == 'right') {
      await _movePhoto(image, delta: 1);
      return;
    }
    if (action == 'swap') {
      await _pickSwapTarget(image);
      return;
    }

    if (action == 'replace') {
      await _addOrChangeImage(replaceImageId: image.id);
      return;
    }

    if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: SpyceColors.dark800,
          title: const Text('Delete this photo?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'This removes it from your profile. Remaining photos stay in order — the first becomes your main photo.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Color(0xFFFF6B81))),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      setState(() => saving = true);
      try {
        await ref.read(profileRepositoryProvider).deleteImage(image.id);
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo deleted')),
        );
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete photo')),
        );
      } finally {
        if (mounted) setState(() => saving = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final p = profile;
    final bg = FeedBackgrounds.resolve(
      bgId: p?.bgId,
      bgVariantId: p?.bgVariantId,
      seed: (p?.id ?? 'me').hashCode,
    );

    if (loading) {
      return const Scaffold(
        backgroundColor: SpyceColors.dark950,
        body: Center(child: CircularProgressIndicator(color: SpyceColors.pink)),
      );
    }

    return Scaffold(
      backgroundColor: SpyceColors.dark950,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: SpyceColors.dark950,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  SvgPicture.asset(bg, fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          SpyceColors.dark950,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: SpyceColors.pink, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: SpyceColors.pink.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: NetworkAvatar(
                                url: p?.displayImageUrl,
                                name: p?.username ?? user?.email,
                                size: 84,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                // Adds a photo to slots; slot 1 is always the main profile image
                                onTap: () {
                                  final photos = _sortedPhotos;
                                  if (photos.isNotEmpty) {
                                    // Open main photo options so user can replace/rearrange
                                    _onPhotoTap(photos.first);
                                  } else {
                                    _addOrChangeImage();
                                  }
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: SpyceColors.pink,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                p?.username != null ? '@${p!.username}' : (user?.email ?? 'You'),
                                style: GoogleFonts.syne(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (p?.city != null)
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 13, color: SpyceColors.pinkSoft),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${p!.city}${p.country != null ? ', ${p.country}' : ''}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                  ],
                                ),
                              if (p?.genderLabel != null)
                                Text(
                                  '${p!.genderLabel}${p.age != null ? ' · ${p.age}' : ''}',
                                  style: const TextStyle(color: SpyceColors.dark200, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                onPressed: _chooseThemeBg,
                icon: const Icon(Icons.palette_outlined, color: SpyceColors.pink),
                tooltip: 'Change Theme',
              ),
              if (saving)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: SpyceColors.pink),
                  ),
                ),
              IconButton(
                onPressed: () => context.push('/app/settings'),
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
              ),
            ],

          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photos Grid Header — fixed 5 slots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Photos & Media',
                        style: GoogleFonts.syne(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${(p?.images.where((i) => i.imageUrl.isNotEmpty).length ?? 0)}/$kMaxProfilePhotoSlots',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Slot 1 is your main profile photo. Tap a photo to set as main, move, or swap.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Always 5 slots: filled with user uploads, else vacant
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final gap = 10.0;
                      final slots = kMaxProfilePhotoSlots;
                      final tileW =
                          (constraints.maxWidth - gap * (slots - 1)) / slots;
                      final tileH = tileW * 1.25;
                      final images = List<ProfileImage>.from(
                        p?.images ?? const <ProfileImage>[],
                      )..sort((a, b) => a.order.compareTo(b.order));
                      // First empty slot shows local preview while upload processes
                      final pendingSlot = pendingLocalPhotoPath != null
                          ? images.length.clamp(0, slots - 1)
                          : -1;

                      return SizedBox(
                        height: tileH,
                        child: Row(
                          children: [
                            for (var i = 0; i < slots; i++) ...[
                              if (i > 0) SizedBox(width: gap),
                              SizedBox(
                                width: tileW,
                                height: tileH,
                                child: _ProfilePhotoSlot(
                                  index: i,
                                  image: i < images.length ? images[i] : null,
                                  localPreviewPath: i == pendingSlot
                                      ? pendingLocalPhotoPath
                                      : null,
                                  uploading: saving,
                                  onAdd: saving
                                      ? null
                                      : () => _addOrChangeImage(),
                                  onTapImage: (img) => _onPhotoTap(img),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Identity Section
                  _SectionCard(
                    title: 'Identity & Preferences',
                    children: [
                      _EditTile(
                        label: 'Username',
                        value: p?.username != null ? '@${p!.username}' : '—',
                        onTap: () => _editText(title: 'Username', field: 'username', initial: p?.username),
                      ),
                      _EditTile(
                        label: 'Display Name',
                        value: p?.name ?? '—',
                        onTap: () => _editText(title: 'Display Name', field: 'name', initial: p?.name),
                      ),
                      _EditTile(
                        label: 'Gender',
                        value: p?.genderLabel ?? '—',
                        subtitle: 'Locked by system',
                        locked: true,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Gender cannot be changed once set.')),
                          );
                        },
                      ),
                      _EditTile(
                        label: 'Preferred Genders',
                        value: _formatPreferredGendersValue(p),
                        onTap: () => _editMultiOption(
                          title: 'Preferred Genders',
                          field: 'preferred_genders',
                          options: genderOpts,
                          currentIds: p?.preferredGenderIds ?? const [],
                        ),
                      ),
                      _EditTile(
                        label: 'Sexuality',
                        value: p?.sexualityLabel ?? '—',
                        onTap: () => _editSingleOption(
                          title: 'Sexuality',
                          field: 'sexuality',
                          options: sexualityOpts,
                          currentId: p?.sexualityId,
                        ),
                      ),
                      _EditTile(
                        label: 'Dating Intent',
                        value: p?.intentLabel ?? '—',
                        onTap: () => _editSingleOption(
                          title: 'Primary Intent',
                          field: 'intent',
                          options: intentOpts,
                          currentId: p?.intentId,
                        ),
                      ),
                    ],
                  ),

                  // About Me Section
                  _SectionCard(
                    title: 'About Me',
                    children: [
                      _EditTile(
                        label: 'Bio',
                        value: p?.bio?.isNotEmpty == true ? p!.bio! : 'Add bio…',
                        onTap: () => _editText(
                          title: 'Bio',
                          field: 'bio',
                          initial: p?.bio,
                          maxLines: 4,
                          maxLength: 300,
                        ),
                      ),
                      _EditTile(
                        label: 'Hot Takes',
                        value: _formatHotTakesValue(p),
                        onTap: _editHottakes,
                      ),
                      _EditTile(
                        label: 'Turn-Ons',
                        value: _formatTurnOnsValue(p),
                        onTap: () => _editMultiOption(
                          title: 'Turn-Ons',
                          field: 'turn_ons',
                          options: turnOnOpts,
                          currentIds: p?.turnOnIds ?? const [],
                        ),
                      ),
                      _EditTile(
                        label: 'Languages Spoken',
                        value: _formatLanguageValue(p),
                        onTap: _editLanguages,
                      ),
                    ],
                  ),

                  // Location — device GPS + reverse geocode to backend
                  _SectionCard(
                    title: 'Location',
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: locationLoading
                                ? null
                                : () => _detectAndSaveLocation(),
                            icon: locationLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: SpyceColors.pinkSoft,
                                    ),
                                  )
                                : const Icon(Icons.my_location,
                                    color: SpyceColors.pinkSoft, size: 18),
                            label: Text(
                              locationLoading
                                  ? 'Detecting…'
                                  : 'Use current location',
                              style: const TextStyle(
                                color: SpyceColors.pinkSoft,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color:
                                    SpyceColors.pink.withValues(alpha: 0.45),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (p?.latitude != null && p?.longitude != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'GPS · ${p!.latitude!.toStringAsFixed(4)}, ${p.longitude!.toStringAsFixed(4)}',
                            style: const TextStyle(
                              color: SpyceColors.dark200,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      _EditTile(
                        label: 'City',
                        value: p?.city ?? '—',
                        onTap: () => _editText(
                            title: 'City', field: 'city', initial: p?.city),
                      ),
                      _EditTile(
                        label: 'State',
                        value: p?.state ?? '—',
                        onTap: () => _editText(
                            title: 'State',
                            field: 'state',
                            initial: p?.state),
                      ),
                      _EditTile(
                        label: 'Country',
                        value: p?.country ?? '—',
                        onTap: () => _editText(
                            title: 'Country',
                            field: 'country',
                            initial: p?.country),
                      ),
                    ],
                  ),

                  // Discovery & Controls
                  _SectionCard(
                    title: 'Discovery Settings',
                    children: [
                      _EditTile(
                        label: 'Age & Distance Preference',
                        value:
                            '${p?.agePreferenceMin ?? 18}–${p?.agePreferenceMax ?? 45} yrs · ${p?.discoveryDistanceLabel ?? 'Anywhere · Worldwide'}',
                        onTap: _editAgePrefs,
                      ),
                      _ToggleTile(
                        label: 'Pause Profile',
                        subtitle: 'Hide from discovery while keeping matches',
                        value: p?.isPaused ?? false,
                        onChanged: (v) => _patch({'is_paused': v}),
                      ),
                      _ToggleTile(
                        label: 'Incognito Mode',
                        subtitle: 'Hide profile completely',
                        value: p?.isHidden ?? false,
                        onChanged: (v) => _patch({'is_hidden': v}),
                      ),
                      _ToggleTile(
                        label: 'Hide Age',
                        value: p?.hideAge ?? false,
                        onChanged: (v) => _patch({'hide_age': v}),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.mood, color: SpyceColors.teal),
                    title: const Text('Update Mood', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                    onTap: () => context.push('/app/mood'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.workspace_premium, color: SpyceColors.gold),
                    title: const Text('SPYCE Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                    onTap: () => context.push('/app/premium'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Sign out?'),
                          content: const Text('You will need an OTP to sign back in.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Sign out', style: TextStyle(color: SpyceColors.pink)),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await ref.read(authControllerProvider.notifier).logout();
                        if (!mounted) return;
                        context.go('/auth');
                      }
                    },
                    icon: const Icon(Icons.logout, color: SpyceColors.pinkSoft),
                    label: const Text(
                      'Sign out',
                      style: TextStyle(color: SpyceColors.pinkSoft, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: SpyceColors.pink.withValues(alpha: 0.4)),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }
}

/// One of 5 fixed profile photo slots: filled image or vacant add-tile.
class _ProfilePhotoSlot extends StatelessWidget {
  const _ProfilePhotoSlot({
    required this.index,
    required this.image,
    required this.uploading,
    required this.onAdd,
    required this.onTapImage,
    this.localPreviewPath,
  });

  final int index;
  final ProfileImage? image;
  final String? localPreviewPath;
  final bool uploading;
  final VoidCallback? onAdd;
  final ValueChanged<ProfileImage> onTapImage;

  bool get _hasPhoto {
    final img = image;
    return img != null && img.imageUrl.isNotEmpty;
  }

  bool get _hasLocalPreview =>
      localPreviewPath != null && localPreviewPath!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final slotLabel = '${index + 1}';

    if (_hasLocalPreview && !_hasPhoto) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(localPreviewPath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: SpyceColors.dark800),
            ),
            Container(color: Colors.black38),
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: SpyceColors.pinkSoft,
                ),
              ),
            ),
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Uploading…',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_hasPhoto) {
      final img = image!;
      return GestureDetector(
        onTap: () => onTapImage(img),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: img.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  color: SpyceColors.dark800,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SpyceColors.pinkSoft,
                    ),
                  ),
                ),
                errorWidget: (_, _, _) => Container(
                  color: SpyceColors.dark800,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white38,
                    size: 22,
                  ),
                ),
              ),
              if (index == 0)
                Positioned(
                  left: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Main',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    slotLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Vacant slot
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: SpyceColors.pink.withValues(alpha: 0.35),
            width: 1.2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              uploading ? Icons.hourglass_top : Icons.add,
              color: SpyceColors.pink.withValues(alpha: 0.9),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              slotLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              uploading ? '…' : 'Vacant',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: SpyceColors.dark800,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SpyceColors.dark500),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.syne(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: SpyceColors.pinkSoft,
            ),
          ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

class _EditTile extends StatelessWidget {
  const _EditTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.subtitle,
    this.locked = false,
  });

  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: SpyceColors.dark100,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(
        locked ? Icons.lock_outline : Icons.edit_outlined,
        size: 18,
        color: SpyceColors.dark200,
      ),
      onTap: onTap,
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: const TextStyle(color: SpyceColors.dark200, fontSize: 11))
          : null,
      value: value,
      activeThumbColor: SpyceColors.pink,
      onChanged: onChanged,
    );
  }
}

// ── Theme picker (API: GET /theme/options/ + PATCH /theme/me/) ─

class _ThemePickerSheet extends StatefulWidget {
  const _ThemePickerSheet({
    required this.repo,
    required this.initial,
  });

  final ProfileRepository repo;
  final DiscoveryTheme initial;

  @override
  State<_ThemePickerSheet> createState() => _ThemePickerSheetState();
}

class _ThemePickerSheetState extends State<_ThemePickerSheet> {
  ThemeOptions? options;
  DiscoveryTheme? theme;
  bool loading = true;
  bool saving = false;
  String? error;

  static const _tokenColors = <String, Color>{
    'sunset': Color(0xFFFF6B35),
    'ocean': Color(0xFF0077B6),
    'midnight': Color(0xFF3D348B),
    'pink': Color(0xFFFF1F6B),
    'teal': Color(0xFF00D4AA),
    'violet': Color(0xFFA855F7),
    'gold': Color(0xFFF5B800),
    'coral': Color(0xFFFF6FA3),
    'ice': Color(0xFFA5F3FC),
    'emerald': Color(0xFF10B981),
    'rose': Color(0xFFFB7185),
    'slate': Color(0xFF64748B),
    'amber': Color(0xFFF59E0B),
    'cyan': Color(0xFF06B6D4),
    'magenta': Color(0xFFD946EF),
    'lime': Color(0xFF84CC16),
    'peach': Color(0xFFFDBA74),
    'lavender': Color(0xFFC084FC),
    'mint': Color(0xFF6EE7B7),
    'spyce': Color(0xFFFF2E74),
    'cool': Color(0xFF3B82F6),
    'warm': Color(0xFFF97316),
    'dark1': Color(0xFF1E1B4B),
    'dark2': Color(0xFF312E81),
  };

  @override
  void initState() {
    super.initState();
    theme = widget.initial;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        widget.repo.getThemeOptions(),
        widget.repo.getMyTheme(),
      ]);
      if (!mounted) return;
      final opts = results[0] as ThemeOptions;
      final mine = results[1] as DiscoveryTheme;
      setState(() {
        options = opts;
        // Prefer live server selection; fall back to profile fields.
        theme = DiscoveryTheme(
          layoutId: mine.layoutId ?? widget.initial.layoutId,
          bgId: mine.bgId ?? widget.initial.bgId,
          bgVariantId: mine.bgVariantId ?? widget.initial.bgVariantId,
          colorToken: mine.colorToken,
          assignedAt: mine.assignedAt,
        );
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Could not load themes from server';
      });
    }
  }

  Future<void> _apply(Map<String, dynamic> patch) async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final updated = await widget.repo.updateTheme(patch);
      if (!mounted) return;
      setState(() {
        theme = updated;
        saving = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = 'Failed to update theme';
      });
    }
  }

  void _selectLayout(String layoutId) {
    if (theme?.layoutId == layoutId) return;
    _apply({'layout_id': layoutId});
  }

  void _selectBackground(ThemeBackgroundOption bg) {
    if (theme?.bgId == bg.bgId) return;
    final first = bg.variants.isNotEmpty ? bg.variants.first : null;
    if (first == null) {
      _apply({'bg_id': bg.bgId});
      return;
    }
    _apply({
      'bg_id': bg.bgId,
      'bg_variant_id': first.bgVariantId,
    });
  }

  void _selectVariant(String bgId, String bgVariantId) {
    if (theme?.bgVariantId == bgVariantId) return;
    _apply({
      'bg_id': bgId,
      'bg_variant_id': bgVariantId,
    });
  }

  Color _swatchColor(ThemeVariantOption v) {
    final token = (v.colorToken ??
            (v.bgVariantId.contains('-')
                ? v.bgVariantId.split('-').last
                : v.bgVariantId))
        .toLowerCase();
    return _tokenColors[token] ?? SpyceColors.pink;
  }

  List<Widget> _buildVariantSection(ThemeBackgroundOption? bg) {
    if (bg == null || bg.variants.isEmpty) return const [];
    return [
      const SizedBox(height: 10),
      Text(
        '${bg.name.toUpperCase()} — COLOR',
        style: GoogleFonts.syne(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: SpyceColors.pinkSoft,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: bg.variants.map((v) {
          final selected = theme?.bgVariantId == v.bgVariantId;
          final color = _swatchColor(v);
          return GestureDetector(
            onTap: saving
                ? null
                : () => _selectVariant(bg.bgId, v.bgVariantId),
            child: Tooltip(
              message: v.name,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                    color: selected ? Colors.white : Colors.white24,
                    width: selected ? 2.5 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.55),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.88;
    final backgrounds = options?.backgrounds ?? const <ThemeBackgroundOption>[];
    final layouts = options?.layouts ?? const <ThemeLayoutOption>[];
    ThemeBackgroundOption? activeBg;
    for (final b in backgrounds) {
      if (b.bgId == theme?.bgId) {
        activeBg = b;
        break;
      }
    }
    activeBg ??= backgrounds.isNotEmpty ? backgrounds.first : null;

    return SafeArea(
      child: SizedBox(
        height: maxH,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Discovery Theme',
                          style: GoogleFonts.syne(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          saving
                              ? 'Saving…'
                              : 'How your card looks in other people\'s feed',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (saving)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SpyceColors.pink,
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, theme),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: SpyceColors.pink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  error!,
                  style: const TextStyle(color: Color(0xFFFF6B81), fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            if (loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: SpyceColors.pink),
                ),
              )
            else if (backgrounds.isEmpty && layouts.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.palette_outlined,
                            size: 40, color: Colors.white38),
                        const SizedBox(height: 12),
                        const Text(
                          'No themes available from the server.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  children: [
                    // Live preview of selected bg
                    if (theme?.bgId != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 120,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              SvgPicture.asset(
                                FeedBackgrounds.resolve(
                                  bgId: theme?.bgId,
                                  bgVariantId: theme?.bgVariantId,
                                  layoutId: theme?.layoutId,
                                ),
                                fit: BoxFit.cover,
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.1),
                                      Colors.black.withValues(alpha: 0.55),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 14,
                                bottom: 12,
                                right: 14,
                                child: Text(
                                  [
                                    if (theme?.layoutId != null)
                                      theme!.layoutId!,
                                    if (theme?.bgId != null) theme!.bgId!,
                                    if (theme?.bgVariantId != null)
                                      theme!.bgVariantId!,
                                  ].join(' · '),
                                  style: GoogleFonts.syne(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    if (layouts.isNotEmpty) ...[
                      Text(
                        'LAYOUT',
                        style: GoogleFonts.syne(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: SpyceColors.pinkSoft,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...layouts.map((l) {
                        final selected = theme?.layoutId == l.layoutId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: selected
                                ? SpyceColors.pink.withValues(alpha: 0.12)
                                : SpyceColors.dark700,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: saving
                                  ? null
                                  : () => _selectLayout(l.layoutId),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? SpyceColors.pink
                                        : SpyceColors.dark500,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.name,
                                      style: TextStyle(
                                        color: selected
                                            ? SpyceColors.pinkSoft
                                            : Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (l.description != null &&
                                        l.description!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          l.description!,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],

                    Text(
                      'BACKGROUND',
                      style: GoogleFonts.syne(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: SpyceColors.pinkSoft,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...backgrounds.map((bg) {
                      final selected = theme?.bgId == bg.bgId;
                      final previewVariant = bg.variants.isNotEmpty
                          ? bg.variants.first.bgVariantId
                          : null;
                      final asset = FeedBackgrounds.resolve(
                        bgId: bg.bgId,
                        bgVariantId: previewVariant,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: selected
                              ? SpyceColors.pink.withValues(alpha: 0.12)
                              : SpyceColors.dark700,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap:
                                saving ? null : () => _selectBackground(bg),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? SpyceColors.pink
                                      : SpyceColors.dark500,
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: SvgPicture.asset(
                                        asset,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          bg.name,
                                          style: TextStyle(
                                            color: selected
                                                ? SpyceColors.pinkSoft
                                                : Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '${bg.bgId} · ${bg.variants.length} colors',
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (selected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: SpyceColors.pink,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    ..._buildVariantSection(activeBg),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
