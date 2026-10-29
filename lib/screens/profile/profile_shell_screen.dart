import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/registration.dart';
import '../../models/user_profile.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/registration_repository.dart';
import '../../repositories/supabase_profile_repository.dart';
import '../../repositories/supabase_registration_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_snackbar.dart';
import '../../utils/image_crop.dart';
import '../../utils/logout_confirmation.dart';

// The "Profile" tab of the bottom-nav shell — replaces the Batch 1
// placeholder of the same name.
class ProfileShellScreen extends StatefulWidget {
  // Overridable for tests; every real call site leaves these null and gets
  // the real Supabase-backed repositories.
  final RegistrationRepository? registrationRepository;
  final ProfileRepository? profileRepository;

  const ProfileShellScreen({
    super.key,
    this.registrationRepository,
    this.profileRepository,
  });

  @override
  State<ProfileShellScreen> createState() => _ProfileShellScreenState();
}

class _ProfileShellScreenState extends State<ProfileShellScreen> {
  late final RegistrationRepository _registrationRepository =
      widget.registrationRepository ?? SupabaseRegistrationRepository();
  late final ProfileRepository _profileRepository =
      widget.profileRepository ?? SupabaseProfileRepository();
  // Null = still loading. Once resolved, holds the user's registration (row
  // exists) or stays null (no registration on file) — this one value drives
  // both the consolidated row's label and its tap destination.
  Registration? _registration;
  bool _isLoading = true;
  // Same idea for the header: null while loading, then either the fetched
  // profile or null if it couldn't be loaded (falls back to the old
  // hardcoded placeholder rather than blank text in that case).
  UserProfile? _profile;
  bool _isLoadingProfile = true;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadRegistration();
    _loadProfile();
  }

  Future<void> _loadRegistration() async {
    try {
      final registration = await _registrationRepository.getMyRegistration();
      if (!mounted) return;
      setState(() {
        _registration = registration;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileRepository.getMyProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _handleAvatarTap() async {
    if (_isLoadingProfile || _isUploadingAvatar) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_camera_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Take Photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Choose from Gallery'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _pickAndUploadAvatar(source);
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not access the camera/gallery.'),
        ),
      );
      return;
    }
    if (picked == null || !mounted) return; // user cancelled the picker

    setState(() => _isUploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      // Auto-center-crop to a square rather than a separate crop screen —
      // see utils/image_crop.dart.
      final cropped = centerCropSquareJpeg(bytes);
      final avatarUrl = await _profileRepository.uploadAvatar(cropped);
      if (!mounted) return;
      setState(() {
        _profile = (_profile ??
                const UserProfile(fullName: '', email: '', mobileNumber: ''))
            .copyWith(avatarUrl: avatarUrl);
        _isUploadingAvatar = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessageFor(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _handleAvatarTap,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Builder(
                        builder: (context) {
                          final avatarUrl = _profile?.avatarUrl;
                          final hasAvatar =
                              avatarUrl != null && avatarUrl.isNotEmpty;
                          return CircleAvatar(
                            radius: 44,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            backgroundImage: hasAvatar
                                ? NetworkImage(avatarUrl)
                                : null,
                            // Falls back to just the background color
                            // instead of an uncaught error if the avatar
                            // can't load (offline, etc).
                            onBackgroundImageError: hasAvatar
                                ? (exception, stackTrace) {}
                                : null,
                            child: hasAvatar
                                ? null
                                : Icon(
                                    Icons.person_rounded,
                                    size: 44,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.35),
                                  ),
                          );
                        },
                      ),
                      if (_isUploadingAvatar)
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.45),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 14,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isLoadingProfile
                      ? 'Loading...'
                      : (_profile?.displayName ?? 'Tourist'),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                if (!_isLoadingProfile && _profile != null) ...[
                  // Skipped when full_name is empty — displayName above
                  // already shows the email as the title in that case, and
                  // repeating it here would just be a duplicate line.
                  if (_profile!.fullName.isNotEmpty &&
                      _profile!.email.isNotEmpty)
                    Text(_profile!.email, style: theme.textTheme.bodyMedium),
                  if (_profile!.mobileNumber.isNotEmpty)
                    Text(
                      _profile!.mobileNumber,
                      style: theme.textTheme.bodyMedium,
                    ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Verified Tourist',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // One context-aware row, replacing the old separate "Register for
          // Arrival"/"My QR Pass" tiles now that getMyRegistration() can
          // tell which state the user is actually in.
          if (_isLoading)
            const _ProfileMenuTile(
              icon: Icons.hourglass_empty_rounded,
              label: 'Checking registration status...',
              onTap: null,
            )
          else if (_registration == null)
            _ProfileMenuTile(
              icon: Icons.app_registration_rounded,
              label: 'Register for Arrival',
              onTap: () => context.push('/register'),
            )
          else
            _ProfileMenuTile(
              icon: Icons.qr_code_rounded,
              label: 'My QR Pass',
              onTap: () => context.push(
                '/registration/my-pass',
                extra: _registration,
              ),
            ),
          _ProfileMenuTile(
            icon: Icons.checklist_rounded,
            label: 'My Itinerary',
            onTap: () => context.push('/itinerary'),
          ),
          _ProfileMenuTile(
            icon: Icons.notifications_none_rounded,
            label: 'Notification Center',
            onTap: () => context.push('/notifications'),
          ),
          _ProfileMenuTile(
            icon: Icons.help_outline_rounded,
            label: 'Help & Support',
            onTap: () => context.push('/help'),
          ),
          _ProfileMenuTile(
            icon: Icons.info_outline_rounded,
            label: 'About GuimaVent',
            onTap: () => context.push('/about'),
          ),
          const SizedBox(height: 12),
          _ProfileMenuTile(
            icon: Icons.logout_rounded,
            label: 'Logout',
            color: Colors.red.shade600,
            onTap: () => confirmAndLogout(context),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const _ProfileMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Falls back to the theme's onSurface (not the fixed AppColors.textDark
    // — a light-mode-only hex that reads as an odd dark purple-navy with
    // poor contrast against a dark scaffold) so every tile except the
    // explicitly red Logout one correctly switches between light/dark.
    final tileColor = color ?? Theme.of(context).colorScheme.onSurface;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: onTap == null
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: tileColor),
        title: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: tileColor, fontWeight: FontWeight.w500),
        ),
        trailing: onTap == null
            ? null
            : Icon(
                Icons.chevron_right_rounded,
                color: tileColor.withValues(alpha: 0.5),
              ),
        onTap: onTap,
      ),
    );
  }
}
