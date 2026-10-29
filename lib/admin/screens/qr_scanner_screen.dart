import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../repositories/admin_checkin_repository.dart';
import '../../repositories/repository_exception.dart';
import '../../theme/app_theme.dart';

// Visitor check-in via QR scan (camera, web-compatible via mobile_scanner)
// or manual pass_code entry — the latter always available, not just a
// permission-denied fallback, since staff may simply prefer typing.
//
// The QR only ever encodes the raw pass_code string (see
// registration_success_screen.dart's QrImageView(data: passCode, ...)) —
// confirmed before building this, not assumed.
class QrScannerScreen extends StatefulWidget {
  // Overridable for tests; every real call site leaves this null and gets
  // the real Supabase-backed repository.
  final AdminCheckinRepository? repository;
  // Off in tests — mobile_scanner needs real camera/platform-channel
  // support that isn't available under `flutter test`. None of the
  // required test coverage (lookup, invalid code, expiry, duplicate,
  // manual entry) touches the camera itself.
  final bool enableCamera;

  const QrScannerScreen({
    super.key,
    this.repository,
    this.enableCamera = true,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  late final AdminCheckinRepository _repository =
      widget.repository ?? SupabaseAdminCheckinRepository();
  final TextEditingController _manualCodeController = TextEditingController();
  late final Future<List<ArrivalPort>> _portsFuture;

  String? _selectedPortId;
  String? _lastHandledCode;
  bool _isLookingUp = false;
  ArrivalCardLookup? _lookupResult;
  CheckinStatus? _checkinStatus;
  String? _lookupError;
  bool _isRecordingCheckin = false;

  @override
  void initState() {
    super.initState();
    _portsFuture = _repository.getPorts();
  }

  @override
  void dispose() {
    _manualCodeController.dispose();
    super.dispose();
  }

  void _handleDetectedCode(BarcodeCapture capture) {
    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    final value = barcode?.rawValue;
    if (value == null || value.isEmpty) return;
    // mobile_scanner's onDetect fires repeatedly while a code stays in
    // frame — only act on it once until it's cleared for the next scan.
    if (_isLookingUp || value == _lastHandledCode) return;
    _lastHandledCode = value;
    _handleLookup(value);
  }

  Future<void> _handleManualSubmit() async {
    final code = _manualCodeController.text.trim();
    if (code.isEmpty) return;
    _lastHandledCode = code;
    await _handleLookup(code);
  }

  Future<void> _handleLookup(String passCode) async {
    setState(() {
      _isLookingUp = true;
      _lookupError = null;
      _lookupResult = null;
      _checkinStatus = null;
    });
    try {
      final card = await _repository.lookupArrivalCard(passCode);
      if (card == null) {
        if (!mounted) return;
        setState(() {
          _lookupError = 'Invalid pass code';
          _isLookingUp = false;
        });
        return;
      }
      final status = await _repository.getCheckinStatus(card.id);
      if (!mounted) return;
      setState(() {
        _lookupResult = card;
        _checkinStatus = status;
        _isLookingUp = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lookupError = e is RepositoryException
            ? e.message
            : 'Could not look up this pass code. Please try again.';
        _isLookingUp = false;
      });
    }
  }

  Future<void> _handleConfirmCheckin() async {
    final card = _lookupResult;
    if (card == null || _isRecordingCheckin) return;
    setState(() => _isRecordingCheckin = true);
    try {
      await _repository.recordCheckin(
        arrivalCardId: card.id,
        portId: _selectedPortId,
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checked in ${card.fullName}')),
      );
      _resetForNextScan();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRecordingCheckin = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is RepositoryException ? e.message : 'Could not record check-in.',
          ),
        ),
      );
    }
  }

  void _resetForNextScan() {
    setState(() {
      _lookupResult = null;
      _checkinStatus = null;
      _lookupError = null;
      _isRecordingCheckin = false;
      _lastHandledCode = null;
      _manualCodeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('QR Scanner', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Scan a visitor\'s QR pass, or enter their pass code manually.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _buildPortPicker(),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.enableCamera) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                        child: SizedBox(
                          height: 280,
                          child: MobileScanner(onDetect: _handleDetectedCode),
                          // No custom errorBuilder needed beyond the
                          // default — the manual entry field below is
                          // always available regardless of camera state,
                          // so a camera failure never blocks check-in.
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _manualCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Pass Code',
                              hintText: 'e.g. GV-2025-123456',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _handleManualSubmit(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _isLookingUp ? null : _handleManualSubmit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          child: const Text('Look Up'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_isLookingUp)
                      const Center(child: CircularProgressIndicator())
                    else if (_lookupError != null)
                      _buildErrorBanner(_lookupError!)
                    else if (_lookupResult != null)
                      _buildResultCard(_lookupResult!),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortPicker() {
    return FutureBuilder<List<ArrivalPort>>(
      future: _portsFuture,
      builder: (context, snapshot) {
        final ports = snapshot.data ?? const [];
        if (ports.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          width: 300,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedPortId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Stationed at (optional)',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final port in ports)
                DropdownMenuItem(value: port.id, child: Text(port.name)),
            ],
            onChanged: (value) => setState(() => _selectedPortId = value),
          ),
        );
      },
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(ArrivalCardLookup card) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isExpired = card.validTo != null && now.isAfter(card.validTo!);
    final isNotYetValid = card.validFrom != null && now.isBefore(card.validFrom!);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.fullName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Pass code: ${card.passCode}', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            _detailRow('Nationality', card.nationality.isEmpty ? '—' : card.nationality),
            _detailRow(
              'Visiting',
              card.municipalitiesToVisit.isEmpty
                  ? '—'
                  : card.municipalitiesToVisit.join(', '),
            ),
            _detailRow(
              'Valid',
              (card.validFrom != null && card.validTo != null)
                  ? '${_formatDate(card.validFrom!)} - ${_formatDate(card.validTo!)}'
                  : 'No validity dates on file',
            ),
            if (isExpired) ...[
              const SizedBox(height: 12),
              _warningBanner(
                'This pass expired on ${_formatDate(card.validTo!)}.',
              ),
            ] else if (isNotYetValid) ...[
              const SizedBox(height: 12),
              _warningBanner(
                'This pass is not valid until ${_formatDate(card.validFrom!)}.',
              ),
            ],
            const SizedBox(height: 16),
            if (_checkinStatus != null) ...[
              _warningBanner(
                'Already checked in at ${_formatDateTime(_checkinStatus!.checkedInAt)} '
                'by ${_checkinStatus!.checkedInByName}.',
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isRecordingCheckin ? null : _handleConfirmCheckin,
                child: Text(
                  _isRecordingCheckin ? 'Recording...' : 'Check In Anyway',
                ),
              ),
            ] else
              FilledButton(
                onPressed: _isRecordingCheckin ? null : _handleConfirmCheckin,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: Text(
                  _isRecordingCheckin ? 'Recording...' : 'Confirm Check-in',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textDark,
              ).copyWith(color: AppColors.textDark.withValues(alpha: 0.6)),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _warningBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatDateTime(DateTime dateTime) =>
      '${_formatDate(dateTime)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}
