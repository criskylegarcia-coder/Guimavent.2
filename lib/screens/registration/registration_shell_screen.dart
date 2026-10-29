import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/registration.dart';
import '../../repositories/registration_repository.dart';
import '../../repositories/repository_exception.dart';
import '../../repositories/supabase_registration_repository.dart';
import '../../theme/app_theme.dart';
import 'personal_info_step.dart';
import 'review_step.dart';
import 'travel_info_step.dart';

// Holds all the Registration form state across the 3 steps and swaps
// between them. Each step widget is stateless — it just renders whatever
// values are passed in and reports changes back up through callbacks, so
// nothing is lost when moving back and forth between steps.
class RegistrationShellScreen extends StatefulWidget {
  const RegistrationShellScreen({super.key});

  @override
  State<RegistrationShellScreen> createState() =>
      _RegistrationShellScreenState();
}

class _RegistrationShellScreenState extends State<RegistrationShellScreen> {
  // Depends on the abstract RegistrationRepository only.
  final RegistrationRepository _repository = SupabaseRegistrationRepository();

  int _currentStep = 0;
  bool _isSubmitting = false;

  // Step 1 - Personal Info
  final _fullNameController = TextEditingController();
  String _nationality = 'Philippines';
  DateTime? _dateOfBirth;
  String? _gender;
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();

  // Step 2 - Travel Info
  DateTime? _dateOfArrival;
  String? _portOfEntry;
  DateTime? _dateOfDeparture;
  String? _travelingWith;
  String? _purposeOfVisit;
  final List<String> _municipalitiesToVisit = [];

  @override
  void initState() {
    super.initState();
    // Rebuilds on every keystroke so the "Next" button's enabled state
    // stays in sync with what's typed.
    _fullNameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _mobileController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get _isStep1Valid =>
      _fullNameController.text.trim().isNotEmpty &&
      _dateOfBirth != null &&
      _gender != null &&
      _emailPattern.hasMatch(_emailController.text.trim()) &&
      _mobileController.text.trim().isNotEmpty;

  bool get _isStep2Valid =>
      _dateOfArrival != null &&
      _portOfEntry != null &&
      _dateOfDeparture != null &&
      _dateOfDeparture!.isAfter(_dateOfArrival!) &&
      _travelingWith != null &&
      _purposeOfVisit != null &&
      _municipalitiesToVisit.isNotEmpty;

  void _goToStep(int step) => setState(() => _currentStep = step);

  void _handleBack() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
      return;
    }
    // Reached directly via URL (no entry point wired yet), so there may be
    // nothing to pop back to.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);
    final draft = Registration(
      fullName: _fullNameController.text.trim(),
      nationality: _nationality,
      dateOfBirth: _dateOfBirth!,
      gender: _gender!,
      email: _emailController.text.trim(),
      mobileNumber: _mobileController.text.trim(),
      dateOfArrival: _dateOfArrival!,
      portOfEntry: _portOfEntry!,
      dateOfDeparture: _dateOfDeparture!,
      travelingWith: _travelingWith!,
      purposeOfVisit: _purposeOfVisit!,
      municipalitiesToVisit: List.of(_municipalitiesToVisit),
    );

    String passCode;
    try {
      passCode = await _repository.submit(draft);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is RepositoryException
                ? e.message
                : 'Could not submit your registration. Please try again.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    HapticFeedback.lightImpact();
    final registration = draft.copyWith(
      passCode: passCode,
      validFrom: draft.dateOfArrival,
      validTo: draft.dateOfDeparture,
    );
    context.push('/registration/success', extra: registration);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _handleBack,
        ),
        title: const Text('Pre-Arrival Registration'),
      ),
      body: Column(
        children: [
          _StepperHeader(currentStep: _currentStep),
          Expanded(
            child: switch (_currentStep) {
              0 => PersonalInfoStep(
                fullNameController: _fullNameController,
                nationality: _nationality,
                onNationalityChanged: (value) =>
                    setState(() => _nationality = value),
                dateOfBirth: _dateOfBirth,
                onDateOfBirthChanged: (date) =>
                    setState(() => _dateOfBirth = date),
                gender: _gender,
                onGenderChanged: (gender) => setState(() => _gender = gender),
                emailController: _emailController,
                mobileController: _mobileController,
                isValid: _isStep1Valid,
                onNext: () => _goToStep(1),
              ),
              1 => TravelInfoStep(
                dateOfArrival: _dateOfArrival,
                onDateOfArrivalChanged: (date) =>
                    setState(() => _dateOfArrival = date),
                portOfEntry: _portOfEntry,
                onPortOfEntryChanged: (port) =>
                    setState(() => _portOfEntry = port),
                dateOfDeparture: _dateOfDeparture,
                onDateOfDepartureChanged: (date) =>
                    setState(() => _dateOfDeparture = date),
                travelingWith: _travelingWith,
                onTravelingWithChanged: (value) =>
                    setState(() => _travelingWith = value),
                purposeOfVisit: _purposeOfVisit,
                onPurposeOfVisitChanged: (value) =>
                    setState(() => _purposeOfVisit = value),
                municipalitiesToVisit: _municipalitiesToVisit,
                onMunicipalitiesChanged: (list) => setState(() {
                  _municipalitiesToVisit
                    ..clear()
                    ..addAll(list);
                }),
                isValid: _isStep2Valid,
                onNext: () => _goToStep(2),
              ),
              _ => ReviewStep(
                fullName: _fullNameController.text.trim(),
                nationality: _nationality,
                dateOfBirth: _dateOfBirth!,
                gender: _gender!,
                email: _emailController.text.trim(),
                mobileNumber: _mobileController.text.trim(),
                dateOfArrival: _dateOfArrival!,
                portOfEntry: _portOfEntry!,
                dateOfDeparture: _dateOfDeparture!,
                travelingWith: _travelingWith!,
                purposeOfVisit: _purposeOfVisit!,
                municipalitiesToVisit: _municipalitiesToVisit,
                isSubmitting: _isSubmitting,
                onSubmit: _handleSubmit,
              ),
            },
          ),
        ],
      ),
    );
  }
}

// Numbered 1-2-3 header: current step filled green, completed steps
// checked, future steps outlined.
class _StepperHeader extends StatelessWidget {
  final int currentStep;

  const _StepperHeader({required this.currentStep});

  static const List<String> _labels = ['Personal Info', 'Travel Info', 'Review'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        16,
        AppSpacing.screenPadding,
        12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            if (i > 0) Expanded(child: _StepConnector(active: currentStep >= i)),
            _StepCircleLabel(
              stepIndex: i,
              currentStep: currentStep,
              label: _labels[i],
            ),
          ],
        ],
      ),
    );
  }
}

class _StepConnector extends StatelessWidget {
  final bool active;

  const _StepConnector({required this.active});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 13, left: 4, right: 4),
      child: Container(
        height: 2,
        color: active ? AppColors.primary : AppColors.textDark.withValues(alpha: 0.15),
      ),
    );
  }
}

class _StepCircleLabel extends StatelessWidget {
  final int stepIndex;
  final int currentStep;
  final String label;

  const _StepCircleLabel({
    required this.stepIndex,
    required this.currentStep,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = stepIndex < currentStep;
    final isCurrent = stepIndex == currentStep;
    final isFilled = isCompleted || isCurrent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? AppColors.primary : Colors.transparent,
            border: Border.all(
              color: isFilled
                  ? AppColors.primary
                  : AppColors.textDark.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: isCompleted
              ? const Icon(Icons.check_rounded, size: 16, color: AppColors.white)
              : Text(
                  '${stepIndex + 1}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isCurrent
                        ? AppColors.white
                        : AppColors.textDark.withValues(alpha: 0.5),
                  ),
                ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 84,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isCurrent
                  ? AppColors.primary
                  : AppColors.textDark.withValues(alpha: 0.6),
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
