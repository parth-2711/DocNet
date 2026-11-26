/// Core application constants derived from PRD.md and THEME.md.
class AppConstants {
  AppConstants._();

  static const String appName = 'DocNet';
  static const String appTagline =
      'Your documents. Encrypted & shared securely.';

  // DOC-003: Max file size target (25 MB)
  static const int maxFileSizeBytes = 25 * 1024 * 1024;

  // DOC-002: Supported initial file formats
  static const List<String> supportedExtensions = ['pdf', 'jpeg', 'jpg', 'png'];

  // DOC-005: Default document categories designed for students, professionals & general users
  static const List<String> defaultCategories = [
    'Identity',
    'Education',
    'Work',
    'Certificates',
    'Financial',
    'Medical',
    'Property',
    'Insurance',
    'Shared',
    'Other',
  ];

  // THEME.md Section 12: Responsive Breakpoints
  static const double compactMaxWidth = 600.0;
  static const double mediumMaxWidth = 1024.0;
}
