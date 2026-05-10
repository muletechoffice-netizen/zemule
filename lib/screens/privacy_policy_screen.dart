import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last Updated: March 5, 2026',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _sectionTitle(context, '1. Introduction'),
            _body(
              context,
              'This Privacy Policy explains how Zemule ("we", "our", "us") '
              'collects, uses, stores, shares, and protects your personal data when '
              'you use the Zemule app and related services.',
            ),
            _sectionTitle(context, '2. Data We Collect'),
            _body(
              context,
              'Depending on how you use the Service, we may collect:\n'
              '- Account data: name, email address, phone number, and profile details.\n'
              '- Authentication data: login events and account security metadata.\n'
              '- User content: reviews, listings, favorites, and in-app submissions.\n'
              '- Device and technical data: app logs, diagnostics, and device identifiers.\n'
              '- Usage data: interactions with screens, features, and search queries.',
            ),
            _sectionTitle(context, '3. How We Use Personal Data'),
            _body(
              context,
              'We process personal data to provide and improve the Service, maintain '
              'account security, respond to support requests, communicate important '
              'updates, enforce policies, and comply with legal obligations.',
            ),
            _sectionTitle(context, '4. Legal Bases for Processing'),
            _body(
              context,
              'Where required, we rely on one or more lawful bases, including consent, '
              'performance of a contract, legitimate interests, and legal compliance.',
            ),
            _sectionTitle(context, '5. Sharing of Data'),
            _body(
              context,
              'We may share personal data with trusted service providers (for hosting, '
              'analytics, authentication, and support), where required by law, or in '
              'connection with security investigations and legal claims.',
            ),
            _sectionTitle(context, '6. Data Retention'),
            _body(
              context,
              'We retain personal data only as long as necessary for the purposes in '
              'this policy, legal obligations, dispute resolution, and enforcement of '
              'our agreements.',
            ),
            _sectionTitle(context, '7. Security'),
            _body(
              context,
              'We implement administrative, technical, and organizational safeguards to '
              'protect personal data. No system is perfectly secure, but we continually '
              'work to reduce risk and protect user information.',
            ),
            _sectionTitle(context, '8. International Transfers'),
            _body(
              context,
              'Your data may be processed in jurisdictions outside your country. Where '
              'required, we apply appropriate safeguards for cross-border transfers.',
            ),
            _sectionTitle(context, '9. Your Rights'),
            _body(
              context,
              'Subject to applicable law, you may have rights to access, correct, '
              'delete, object to processing, restrict processing, withdraw consent, and '
              'request portability of your data.',
            ),
            _sectionTitle(context, '10. Children\'s Privacy'),
            _body(
              context,
              'Zemule is not intended for children under the age defined by applicable '
              'law without appropriate parental or guardian authorization.',
            ),
            _sectionTitle(context, '11. Changes to This Policy'),
            _body(
              context,
              'We may update this Privacy Policy from time to time. Material changes '
              'will be posted in the app with an updated effective date.',
            ),
            _sectionTitle(context, '12. Contact Details'),
            _body(
              context,
              'General Email: muletechoffice@gmail.com\n'
              'Support: support@muletechoffice@gmail.com\n'
              'Privacy: privacy@muletechoffice@gmail.com\n'
              'Data Protection Officer (DPO): dpo@muletechoffice@gmail.com\n'
              'Disputes: disputes@muletechoffice@gmail.com\n'
              'Phone: +260 77 780 7668',
            ),
            _sectionTitle(context, '13. Data Protection Commissioner (Zambia)'),
            _body(
              context,
              'If you believe your data protection rights have been violated, you may '
              'lodge a complaint with the Data Protection Commission (Zambia):\n'
              'Phone: (+260) 750 799 801\n'
              'Email: info@dataprotection.gov.zm\n'
              'Location: Ministry of Technology and Science, Zambia\n'
              'Website: https://www.dataprotection.gov.zm',
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _body(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
    );
  }
}
