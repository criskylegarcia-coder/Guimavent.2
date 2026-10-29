import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/registration.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_format.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';

// Shown right after RegistrationShellScreen's Review step submits
// successfully, and reused (with isNewSubmission: false) by ProfileShellScreen's
// "My QR Pass" row to show an already-registered tourist their existing
// pass. `registration` arrives via GoRouter's `extra` and is expected to
// already have passCode/validFrom/validTo filled in either way.
class RegistrationSuccessScreen extends StatelessWidget {
  final Registration registration;
  final bool isNewSubmission;

  const RegistrationSuccessScreen({
    super.key,
    required this.registration,
    this.isNewSubmission = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passCode = registration.passCode ?? '';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      width: 88,
                      height: 88,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: AppColors.secondary,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isNewSubmission
                          ? 'Registration Successful!'
                          : 'My QR Pass',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isNewSubmission
                          ? 'Your registration is complete. Present this QR '
                                'Code at the port of entry for verification.'
                          : 'Present this QR Code at the port of entry for '
                                'verification.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              'GuimaVent Access Pass',
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 16),
                            QrImageView(
                              data: passCode,
                              size: 180,
                              backgroundColor: AppColors.white,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Code: $passCode',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Valid: ${formatDateRange(registration.dateOfArrival, registration.dateOfDeparture)}',
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Download QR',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Downloading QR code...')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Go to Home',
                      onPressed: () => context.go('/home'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
