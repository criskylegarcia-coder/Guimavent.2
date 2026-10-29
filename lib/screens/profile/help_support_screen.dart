import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

const List<({String question, String answer})> _faqs = [
  (
    question: 'How do I register for arrival?',
    answer:
        'From Profile, tap "Register for Arrival" (or the prompt shown when '
        'you try to get directions to an activity) and fill out the '
        'Pre-Arrival Registration form. Once submitted, you\'ll get a QR '
        'pass to present at your port of entry.',
  ),
  (
    question: 'How do I save an activity to my schedule?',
    answer:
        'Open an activity\'s details and tap "+ Add to Itinerary" (or the '
        'heart icon). It\'ll show up under the Itinerary tab.',
  ),
  (
    question: 'How do I get directions to an activity?',
    answer:
        'From an activity\'s details screen, tap "Get Directions" to see it '
        'on the map with walking, cycling, or driving options — from your '
        'current location or a specific arrival port.',
  ),
  (
    question: 'Why do I need to register before viewing directions?',
    answer:
        'Map & Directions requires a completed Pre-Arrival Registration, so '
        'LGU tourism officers can verify visitor activity and provide the '
        'QR pass used at checkpoints.',
  ),
  (
    question: 'How do I view my QR pass again?',
    answer:
        'Go to Profile — once you\'re registered, the top row switches to '
        '"My QR Pass" and shows your code again any time.',
  ),
];

// Reached from Profile's "Help & Support" row. Static content only: a short
// FAQ and a placeholder contact address — no live support inbox exists yet.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          Text('Frequently Asked Questions', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          for (final faq in _faqs) _FaqTile(faq: faq),
          const SizedBox(height: 24),
          Text('Contact Us', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ContactRow(
                    icon: Icons.email_outlined,
                    text: 'support@guimavent.example',
                  ),
                  const SizedBox(height: 10),
                  _ContactRow(
                    icon: Icons.phone_outlined,
                    text: '(033) 000-0000 (placeholder)',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'These are placeholder contact details — not a live '
                    'inbox or hotline yet.',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.textDark.withValues(alpha: 0.6),
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

class _FaqTile extends StatelessWidget {
  final ({String question, String answer}) faq;

  const _FaqTile({required this.faq});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          faq.question,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(faq.answer, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ContactRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
