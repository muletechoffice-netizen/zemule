import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last Updated: March 5, 2026',
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _sectionTitle(context, '1. Acceptance of Terms'),
            _body(
              context,
              'These Terms of Service ("Terms") govern your access to and use of '
              'Zemule ("App", "Service", "we", "our", "us"). By creating an '
              'account, browsing, posting, listing, or otherwise using Zemule, you '
              'agree to these Terms. If you do not agree, do not use the Service.',
            ),
            _sectionTitle(context, '2. Eligibility'),
            _body(
              context,
              'You must be legally capable of entering binding agreements under '
              'applicable law. You are responsible for ensuring your use of Zemule is '
              'lawful in your location.',
            ),
            _sectionTitle(context, '3. Accounts and Security'),
            _body(
              context,
              'You are responsible for maintaining accurate account information and '
              'for all activity under your account. Keep credentials confidential. We '
              'may suspend or terminate accounts involved in fraud, abuse, or policy '
              'violations.',
            ),
            _sectionTitle(context, '4. User Content'),
            _body(
              context,
              'You may submit listings, reviews, profile information, and other '
              'content. You retain ownership of your content, but grant Zemule a '
              'non-exclusive, worldwide, royalty-free license to host, display, '
              'reproduce, and distribute such content solely to operate and improve '
              'the Service.',
            ),
            _sectionTitle(context, '5. Prohibited Conduct'),
            _body(
              context,
              'You must not: post false or misleading information; violate laws or '
              'third-party rights; upload harmful code; attempt unauthorized access; '
              'harass users; manipulate ratings or reviews; or interfere with the '
              'Service\'s integrity.',
            ),
            _sectionTitle(context, '6. Listings, Reviews, and Rankings'),
            _body(
              context,
              'Zemule may moderate, remove, reorder, or label content to preserve '
              'quality and safety. Rankings, recommendations, and visibility may be '
              'influenced by relevance, quality, completeness, user signals, and other '
              'factors.',
            ),
            _sectionTitle(context, '7. Business User Responsibilities'),
            _body(
              context,
              'If you list a business, you represent that your listing information is '
              'accurate and that you have authority to publish it. You are responsible '
              'for keeping your business data current and lawful.',
            ),
            _sectionTitle(context, '8. Intellectual Property'),
            _body(
              context,
              'All Zemule branding, software, and platform components are protected by '
              'intellectual property laws. Except as expressly permitted, you may not '
              'copy, modify, reverse engineer, or redistribute any part of the Service.',
            ),
            _sectionTitle(context, '9. Privacy'),
            _body(
              context,
              'Your use of Zemule is also governed by our Privacy Policy. By using the '
              'Service, you acknowledge that we may process personal data as described '
              'in that policy.',
            ),
            _sectionTitle(context, '10. Third-Party Services'),
            _body(
              context,
              'Zemule may include links, maps, analytics, payment tools, or other '
              'third-party services. We are not responsible for third-party terms, '
              'content, availability, or practices.',
            ),
            _sectionTitle(context, '11. Disclaimers'),
            _body(
              context,
              'The Service is provided on an "as is" and "as available" basis to the '
              'maximum extent permitted by law. We do not guarantee uninterrupted '
              'availability, error-free operation, or specific outcomes from use.',
            ),
            _sectionTitle(context, '12. Limitation of Liability'),
            _body(
              context,
              'To the maximum extent permitted by law, Zemule and its affiliates are '
              'not liable for indirect, incidental, special, consequential, or punitive '
              'damages, or any loss of data, revenue, or profits arising from use of '
              'the Service.',
            ),
            _sectionTitle(context, '13. Indemnification'),
            _body(
              context,
              'You agree to defend, indemnify, and hold Zemule harmless from claims, '
              'liabilities, losses, and expenses arising from your content, your use of '
              'the Service, or your breach of these Terms.',
            ),
            _sectionTitle(context, '14. Suspension and Termination'),
            _body(
              context,
              'We may suspend or terminate access when necessary to protect users, '
              'comply with law, investigate misconduct, or enforce these Terms.',
            ),
            _sectionTitle(context, '15. Changes to Terms'),
            _body(
              context,
              'We may update these Terms from time to time. Updated versions become '
              'effective when posted in the App unless a later date is specified.',
            ),
            _sectionTitle(context, '16. Governing Law and Disputes'),
            _body(
              context,
              'These Terms are governed by applicable laws of Zambia, unless otherwise '
              'required by mandatory local law. Disputes should first be raised with '
              'us to seek an amicable resolution.',
            ),
            _sectionTitle(context, '17. Contact Information'),
            _body(
              context,
              'For questions about these Terms:\n'
              'Phone: +260 77 780 7668\n'
              'Email: muletechoffice@gmail.com',
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
