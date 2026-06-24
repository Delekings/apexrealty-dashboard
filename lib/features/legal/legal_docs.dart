// lib/features/legal/legal_docs.dart
//
// The catalogue of legal documents shipped with the app. To add a document:
//   1. Drop its markdown at assets/legal/<slug>.md
//   2. Add a LegalDoc entry below.
// Everything else (index list, routes, viewer) is driven from this list.

class LegalDoc {
  final String slug;
  final String title;
  final String version;
  final String effectiveDate;
  final String summary;

  const LegalDoc({
    required this.slug,
    required this.title,
    required this.version,
    required this.effectiveDate,
    required this.summary,
  });

  String get asset => 'assets/legal/$slug.md';
}

const List<LegalDoc> legalDocs = [
  LegalDoc(
    slug: 'privacy',
    title: 'Privacy Policy',
    version: '1.0',
    effectiveDate: '14 June 2026',
    summary: 'How Lintel collects, uses, and protects personal data.',
  ),
  LegalDoc(
    slug: 'terms',
    title: 'Terms of Service',
    version: '2.0',
    effectiveDate: '14 June 2026',
    summary: 'The agreement governing your use of Lintel.',
  ),
  LegalDoc(
    slug: 'security',
    title: 'Security Policy',
    version: '1.0',
    effectiveDate: '14 June 2026',
    summary: 'How we secure the platform and your data.',
  ),
  LegalDoc(
    slug: 'communications',
    title: 'Communications & Email Policy',
    version: '1.0',
    effectiveDate: '14 June 2026',
    summary: 'How email and other communications are handled and sent.',
  ),
  LegalDoc(
    slug: 'account-deletion',
    title: 'Account Deletion Policy',
    version: '1.0',
    effectiveDate: '14 June 2026',
    summary: 'What happens to your data when an account is closed.',
  ),
  LegalDoc(
    slug: 'subprocessors',
    title: 'Subprocessor Disclosure',
    version: '1.0',
    effectiveDate: '14 June 2026',
    summary: 'The third parties that process data on our behalf.',
  ),
];

LegalDoc? legalDocBySlug(String slug) {
  for (final d in legalDocs) {
    if (d.slug == slug) return d;
  }
  return null;
}
