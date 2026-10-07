import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_language.dart';
import '../theme/app_colors.dart';
import '../widgets/gh_ui.dart';
import '../services/auth_service.dart';
import '../services/doctor_service.dart';
import '../services/consultation_service.dart';
import '../services/call_service.dart';
import '../widgets/connectivity_badge.dart';
import '../widgets/voice_note_dialog.dart';
import '../services/connectivity_service.dart';
import '../services/offline_ai_service.dart';
import '../widgets/offline_setup_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedSpecialistKey = 'spec_all';
  String _userName = '';
  List<DoctorModel> _doctors = [];
  bool _doctorsLoading = true;
  List<ConsultationModel> _activeConsultations = [];
  bool _loadingConsultations = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadDoctors();
    _loadConsultations();

    // Asynchronously initialise Offline AI in the background only after user is authenticated on Home Screen
    unawaited(OfflineAiService.instance.initialise().then((_) {
      return OfflineAiService.instance.checkModelOnStartup();
    }).catchError((_) {}));
  }

  Future<void> _loadConsultations() async {
    setState(() => _loadingConsultations = true);
    try {
      final activeList = await ConsultationService.listConsultations(status: 'ACTIVE');
      if (mounted) {
        setState(() {
          _activeConsultations = activeList;
          _loadingConsultations = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingConsultations = false);
    }
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getUser();
    if (user != null && mounted) {
      setState(() {
        _userName = (user['name'] as String? ?? '').toUpperCase();
      });
    }
  }

  Future<void> _loadDoctors() async {
    setState(() => _doctorsLoading = true);
    try {
      final result = await DoctorService.getDoctors();
      if (mounted) setState(() { _doctors = result; _doctorsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _doctorsLoading = false);
    }
  }

  /// Returns doctors filtered by the selected specialization chip.
  List<DoctorModel> get _filteredDoctors {
    if (_selectedSpecialistKey == 'spec_all') return _doctors;
    final Map<String, String> keyToSpec = {
      'spec_gp':    'general',
      'spec_cardio':'cardio',
      'spec_neuro': 'neuro',
      'spec_pedia': 'pedia',
    };
    final keyword = (keyToSpec[_selectedSpecialistKey] ?? '').toLowerCase();
    return _doctors.where((d) => d.specialization.toLowerCase().contains(keyword)).toList();
  }

  final _specialistKeys = [
    'spec_all',
    'spec_gp',
    'spec_cardio',
    'spec_neuro',
    'spec_pedia',
  ];

  final _categories = [
    {
      'id': '1',
      'titleKey': 'service_consult',
      'icon': Icons.monitor_heart_outlined,
      'color': const Color(0xFFE1F5FE)
    },
    {
      'id': '2',
      'titleKey': 'service_symptoms',
      'icon': Icons.search,
      'color': const Color(0xFFF3E5F5)
    },
    {
      'id': '3',
      'titleKey': 'service_medicine',
      'icon': Icons.local_pharmacy_outlined,
      'color': const Color(0xFFE8F5E9)
    },
    {
      'id': '4',
      'titleKey': 'service_records',
      'icon': Icons.description_outlined,
      'color': const Color(0xFFFFF3E0)
    },
    {
      'id': '5',
      'titleKey': 'service_emergency',
      'icon': Icons.emergency_outlined,
      'color': const Color(0xFFFFEBEE)
    },
    {
      'id': '6',
      'titleKey': 'Prescriptions',
      'icon': Icons.article_outlined,
      'color': const Color(0xFFD1C4E9)
    },
  ];

  void _handleCategoryTap(String id) {
    switch (id) {
      case '1':
        context.go('/main/doctors');
        break;
      case '2':
        context.go('/main/symptoms');
        break;
      case '3':
        context.push('/medicine');
        break;
      case '6':
        context.go('/prescriptions');
        break;
      case '4':
        context.go('/main/records');
        break;
      case '5':
        context.push('/emergency');
        break;
    }
  }

  static const double _maxContentWidth = 1100;
  static const double _hPad = 20;

  String get _displayName {
    if (_userName.isEmpty) return '';
    return _userName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .map((p) => p[0] + p.substring(1).toLowerCase())
        .join(' ');
  }

  Future<void> _onConsultationAction(ConsultationModel c) async {
    if (ConnectivityService.instance.currentStatus == NetworkStatus.offline) {
      showDialog(
        context: context,
        builder: (context) => VoiceNoteDialog(consultationId: c.id),
      );
    } else {
      await CallService.startCall(
        consultationId: c.id,
        audioOnly: c.type.toUpperCase() == 'AUDIO',
      );
      // Automatically hide the consultation from the dashboard once the call loop finishes
      if (mounted) {
        setState(() {
          _activeConsultations.removeWhere((item) => item.id == c.id);
        });
      }
      // Secretly tell backend we completed it so it doesn't reappear
      try {
        await ConsultationService.updateStatus(c.id, 'COMPLETED');
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final contentW = math.min(screenW, _maxContentWidth);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.secondaryBg,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(top: topInset + 12, bottom: 128),
            child: Center(
              child: SizedBox(
                width: contentW,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildBanner(),
                    const SizedBox(height: 16),

                    // Offline AI Background Status / Progress Banner
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: OfflineSetupCard(),
                    ),

                    if (!_loadingConsultations &&
                        _activeConsultations.isNotEmpty)
                      _buildActiveConsultations(),

                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _hPad),
                      child: GhSectionHeader(title: context.tr('our_services')),
                    ),
                    const SizedBox(height: 12),
                    _buildServicesGrid(contentW),

                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _hPad),
                      child: GhSectionHeader(
                        title: context.tr('our_specialists'),
                        actionLabel: context.tr('explore_all'),
                        onAction: () => context.go('/main/doctors'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSpecialistChips(),
                    const SizedBox(height: 14),
                    _buildDoctorsSection(contentW),
                  ],
                ),
              ),
            ),
          ),

          // Floating chatbot FAB
          Positioned(
            bottom: 96,
            right: 20,
            child: _buildAssistantFab(),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final name = _displayName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ConnectivityBadge(),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name.isNotEmpty)
                      Text(
                        context.tr('greeting'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      name.isNotEmpty ? name : context.tr('greeting'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const GhLanguageChip(),
              const SizedBox(width: 8),
              _iconButton(Icons.notifications_none_rounded,
                  () => context.push('/notifications')),
              const SizedBox(width: 8),
              _buildAvatar(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return Tooltip(
      message: 'Notifications',
      child: Material(
        color: GhTokens.surface,
        shape: const CircleBorder(side: BorderSide(color: GhTokens.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 22, color: AppColors.textDark),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Tooltip(
      message: 'Profile',
      child: Material(
        color: AppColors.leafGreenPale,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.go('/main/profile'),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Text(
                _userName.isNotEmpty ? _userName[0] : '?',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.leafGreenPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Banner ────────────────────────────────────────────────────────────────

  Widget _buildBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.leafGradientHero,
          borderRadius: BorderRadius.circular(GhTokens.radiusLg),
          boxShadow: GhTokens.shadowMd,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('free_checkup'),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('checkup_subtitle'),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.push('/notifications'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textDark,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(context.tr('learn_more')),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(GhTokens.radiusMd),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Icon(Icons.health_and_safety_outlined,
                  size: 28, color: AppColors.leafGreenAccent),
            ),
          ],
        ),
      ),
    );
  }

  // ── Active consultations ──────────────────────────────────────────────────

  Widget _buildActiveConsultations() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_hPad, 24, _hPad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GhSectionHeader(
            title: 'Your Active Consultations',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.leafGreenPale,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_activeConsultations.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.leafGreenPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._activeConsultations
              .map((c) => _buildConsultationCard(c))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildConsultationCard(ConsultationModel c) {
    final isOffline =
        ConnectivityService.instance.currentStatus == NetworkStatus.offline;
    final isAudio = c.type.toUpperCase() == 'AUDIO';
    final actionLabel = isOffline ? 'Record Note' : (isAudio ? 'Audio' : 'Join');
    final actionIcon = isOffline
        ? Icons.mic_none_rounded
        : (isAudio ? Icons.call_rounded : Icons.videocam_rounded);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GhTokens.surface,
        borderRadius: BorderRadius.circular(GhTokens.radiusMd),
        border: Border.all(color: GhTokens.border),
        boxShadow: GhTokens.shadowSm,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.leafGreenPale,
              borderRadius: BorderRadius.circular(GhTokens.radiusSm),
            ),
            child: Icon(
              isAudio ? Icons.call_rounded : Icons.videocam_rounded,
              size: 22,
              color: AppColors.leafGreenPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.reason.isNotEmpty ? c.reason : 'Consultation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.leafGreenLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Ready to join',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => _onConsultationAction(c),
            icon: Icon(actionIcon, size: 18),
            label: Text(actionLabel),
            style: FilledButton.styleFrom(
              backgroundColor:
                  isOffline ? AppColors.warning : AppColors.leafGreenPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Services ──────────────────────────────────────────────────────────────

  Widget _buildServicesGrid(double contentW) {
    const gap = 12.0;
    final cols = contentW >= 900 ? 6 : (contentW >= 600 ? 3 : 2);
    final itemW = (contentW - _hPad * 2 - gap * (cols - 1)) / cols;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        children: _categories
            .map((cat) => SizedBox(width: itemW, child: _buildServiceCard(cat)))
            .toList(),
      ),
    );
  }

  Widget _buildServiceCard(Map cat) {
    final isEmergency = cat['id'] == '5';
    final radius = BorderRadius.circular(GhTokens.radiusMd);
    return Material(
      color: GhTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: GhTokens.border),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: () => _handleCategoryTap(cat['id'] as String),
        child: SizedBox(
          height: 124,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cat['color'] as Color,
                        borderRadius:
                            BorderRadius.circular(GhTokens.radiusSm),
                      ),
                      child: Icon(
                        cat['icon'] as IconData,
                        size: 22,
                        color: isEmergency
                            ? AppColors.emergency
                            : AppColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_outward_rounded,
                        size: 18, color: AppColors.textMuted),
                  ],
                ),
                Text(
                  context.tr(cat['titleKey'] as String),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Specialists ───────────────────────────────────────────────────────────

  Widget _buildSpecialistChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _hPad),
        itemCount: _specialistKeys.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final key = _specialistKeys[i];
          final isActive = _selectedSpecialistKey == key;
          return Semantics(
            button: true,
            selected: isActive,
            child: Material(
              color:
                  isActive ? AppColors.leafGreenPrimary : GhTokens.surface,
              shape: StadiumBorder(
                side: BorderSide(
                  color: isActive
                      ? AppColors.leafGreenPrimary
                      : GhTokens.border,
                ),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => setState(() => _selectedSpecialistKey = key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      context.tr(key),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : AppColors.textMedium,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDoctorsSection(double contentW) {
    const listHeight = 156.0;
    final cardW = math.min(contentW * 0.8, 340.0);

    if (_doctorsLoading) {
      return SizedBox(
        height: listHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: _hPad),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => _buildDoctorSkeleton(cardW),
        ),
      );
    }

    if (_filteredDoctors.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: _hPad),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: GhTokens.surface,
            borderRadius: BorderRadius.circular(GhTokens.radiusMd),
            border: Border.all(color: GhTokens.border),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.leafBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_search_outlined,
                    size: 24, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              const Text(
                'No doctors found',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: listHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _hPad),
        itemCount: _filteredDoctors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _buildDoctorCard(_filteredDoctors[i], cardW),
      ),
    );
  }

  Widget _buildDoctorSkeleton(double cardW) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: AppColors.leafBg,
            borderRadius: BorderRadius.circular(6),
          ),
        );
    return Container(
      width: cardW,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GhTokens.surface,
        borderRadius: BorderRadius.circular(GhTokens.radiusMd),
        border: Border.all(color: GhTokens.border),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.leafBg,
              borderRadius: BorderRadius.circular(GhTokens.radiusSm),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                bar(120, 14),
                const SizedBox(height: 8),
                bar(80, 12),
                const SizedBox(height: 16),
                bar(double.infinity, 36),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(DoctorModel doc, double cardW) {
    final radius = BorderRadius.circular(GhTokens.radiusMd);
    return SizedBox(
      width: cardW,
      child: Material(
        color: GhTokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: GhTokens.border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: () => context.push('/doctor-details/${doc.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(GhTokens.radiusSm),
                  child: CachedNetworkImage(
                    imageUrl: doc.image,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: AppColors.leafGreenPale),
                    errorWidget: (_, __, ___) => Container(
                      width: 72,
                      height: 72,
                      color: AppColors.leafGreenPale,
                      alignment: Alignment.center,
                      child: Text(
                        doc.name.isNotEmpty ? doc.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.leafGreenPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Dr. ${doc.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        doc.specialization,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.leafGreenPrimary,
                        ),
                      ),
                      if (doc.hospital != null && doc.hospital!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                doc.hospital!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: FilledButton(
                          onPressed: () => context.push(
                            '/teleconsultation-request',
                            extra: {'doctorId': doc.id, 'doctorName': doc.name},
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.textDark,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Text(context.tr('book_now')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Assistant FAB ─────────────────────────────────────────────────────────

  Widget _buildAssistantFab() {
    return Tooltip(
      message: 'AI Assistant',
      child: Material(
        color: AppColors.leafGreenPrimary,
        shape: const CircleBorder(),
        elevation: 6,
        shadowColor: AppColors.leafGreenPrimary.withValues(alpha: 0.4),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.push('/chatbot'),
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.insights, size: 26, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
