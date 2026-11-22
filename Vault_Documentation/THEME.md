# FamilyVault — UI Theme and Design System

**Version:** 1.0  
**Platforms:** Android, iOS, Windows, Web

## 1. Brand direction

FamilyVault should feel:
- Trustworthy.
- Calm.
- Private.
- Modern.
- Family-friendly without looking childish.
- Professional enough for financial and identity documents.

Provisional tagline:

**Your family's documents. One secure place.**

Product name is provisional and requires trademark/store-name checks.

## 2. Design principles

1. Security status is clear but not frightening.
2. Important actions are easy to find.
3. Document lists are dense enough for productivity but readable.
4. Destructive actions are visually distinct.
5. Privacy controls are understandable.
6. Layout adapts to phone, tablet, desktop, and browser.
7. Avoid excessive glassmorphism, gradients, and decorative motion.
8. Accessibility is part of the design system.

## 3. Color palette

### Light theme

| Token | Hex | Usage |
|---|---|---|
| `primary` | `#183653` | Main brand/nav |
| `primaryContainer` | `#DCEAF5` | Selected surfaces |
| `secondary` | `#2C789B` | Secondary actions |
| `accent` | `#5DB7E8` | Highlights |
| `background` | `#F2F6FA` | App background |
| `surface` | `#FFFFFF` | Cards/sheets |
| `surfaceVariant` | `#E8EFF5` | Subtle panels |
| `textPrimary` | `#172C42` | Main text |
| `textSecondary` | `#607286` | Supporting text |
| `success` | `#237A57` | Successful state |
| `warning` | `#A85B2E` | Warning |
| `error` | `#B33A3A` | Error/destructive |
| `outline` | `#CBD6E0` | Borders |

### Dark theme

| Token | Hex | Usage |
|---|---|---|
| `primary` | `#8CCDF0` | Primary action |
| `primaryContainer` | `#23445E` | Selected surfaces |
| `secondary` | `#80C5D9` | Secondary action |
| `accent` | `#5DB7E8` | Highlights |
| `background` | `#101B27` | App background |
| `surface` | `#172635` | Cards |
| `surfaceVariant` | `#243849` | Panels |
| `textPrimary` | `#F0F5F9` | Main text |
| `textSecondary` | `#B2C2CF` | Supporting text |
| `success` | `#69D5A7` | Success |
| `warning` | `#E5A16E` | Warning |
| `error` | `#F08A8A` | Error |
| `outline` | `#405466` | Borders |

Check text/background combinations for WCAG contrast. Do not assume palette pairs automatically pass.

## 4. Typography

Use a legible sans-serif family such as Inter or a compatible platform fallback.

Suggested scale:
- Display: 32/40.
- Headline: 24/32.
- Title: 20/28.
- Subtitle: 16/24.
- Body: 14/22.
- Label: 12/18.
- Caption: 11/16.

Support text scaling. Avoid fixed-height text containers that clip localized content.

## 5. Spacing and shape

Spacing scale:
- 4 px: micro gap.
- 8 px: compact.
- 12 px: standard small.
- 16 px: standard.
- 20 px: section.
- 24 px: large.
- 32 px: page section.

Radius:
- Small controls: 8 px.
- Inputs/cards: 12 px.
- Large panels: 16 px.
- Dialogs: 20 px.
- Pills: fully rounded.

Use subtle elevation. Prefer borders and spacing over heavy shadows.

## 6. Iconography

Use consistent outline icons. Suggested concepts:
- Home.
- Folder.
- File PDF.
- Image.
- Shield.
- Cloud sync.
- Family/users.
- Share.
- History.
- Bell.
- Settings.
- Lock.
- Device.
- Warning.
- Offline.

Never use icon color alone to communicate permission or sync state. Include text labels or semantic descriptions.

## 7. Component inventory

### Buttons
- Primary filled.
- Secondary outlined.
- Tertiary text.
- Destructive.
- Icon button.
- Loading state.
- Disabled state.

### Inputs
- Standard text.
- Search.
- Password with visibility toggle.
- Dropdown.
- Date picker.
- Multi-select.
- Inline validation.

### Cards
- Document card.
- Category card.
- Family member card.
- Storage usage card.
- Sync status card.
- Request card.
- Activity item.

### Feedback
- Toast/snackbar.
- Inline error.
- Confirmation dialog.
- Empty state.
- Loading skeleton.
- Progress indicator.
- Offline banner.
- Conflict panel.

## 8. Document card specification

Show:
- File-type icon.
- Encrypted display name after local decryption.
- Category.
- Updated time.
- Owner indicator in family context.
- Sync state.
- Optional favorite marker.

Actions:
- Open.
- More menu.

Do not show sensitive file names in push notifications or external system notifications.

## 9. Dashboard layout

### Mobile
1. Top app bar and profile.
2. Sync status.
3. Storage usage.
4. Upload CTA.
5. Category shortcuts.
6. Recent documents.
7. Shared family documents.
8. Pending requests/reminders.

### Desktop/web
- Sidebar navigation.
- Top search/action bar.
- Dashboard cards.
- Recent documents table/list.
- Optional right-side activity panel.

## 10. Navigation

Mobile bottom destinations:
- Home.
- Documents.
- Family.
- Activity.
- Settings.

Desktop sidebar uses the same destinations with labels and keyboard focus.

## 11. Screen specifications

### Onboarding
- Clear explanation of client-side encryption.
- Recovery warning and verification.
- Skip family setup option.
- No preselected consent for optional features.

### Home
- Greeting.
- Sync state.
- Storage.
- Quick upload.
- Categories.
- Recent.
- Shared with me.

### Documents
- Search and filters.
- List/grid toggle.
- Sort.
- Multi-select.
- Upload.
- Empty/loading/error/offline states.

### Document detail
- Preview.
- Metadata.
- Version history.
- Permissions.
- Sync state.
- Share/replace/export/archive/delete.

### Family
- Family header.
- Member list and roles.
- Invitations.
- Shared vault.
- Requests.
- Family settings.

### Security
- Recovery status.
- Devices.
- App lock.
- Key rotation/recovery actions.
- Security event history.

## 12. Responsive breakpoints

Suggested layout behavior:
- Compact: under 600 px.
- Medium: 600–1023 px.
- Expanded: 1024 px and above.

Breakpoints are design guidance. Test actual window widths and platform behavior.

## 13. Motion

- Short transitions for navigation.
- Subtle upload progress animation.
- Avoid motion that delays critical actions.
- Respect reduced-motion settings.
- No celebratory animation for security-sensitive operations.

## 14. Accessibility

- WCAG 2.2 AA target for web interfaces.
- Semantic labels.
- Keyboard traversal.
- Visible focus.
- Contrast checks.
- Text scaling.
- Screen-reader announcements for upload/sync state.
- Touch targets appropriate for mobile.
- Error messages associated with fields.

## 15. Localization

Initial languages:
- English.
- Gujarati.
- Hindi.

Do not hardcode strings. Allow longer translated labels and date formats. Test Gujarati and Hindi font rendering.

## 16. UI copy guidance

Prefer:
- “Encrypted on this device.”
- “Waiting for connection.”
- “Shared with 2 family members.”
- “This device is up to date.”
- “A newer version exists.”
- “You can revoke future access, but cannot remove copies already downloaded.”

Avoid:
- “100% safe.”
- “Unhackable.”
- “File deleted everywhere” when only cloud deletion occurred.
- “Family can access everything” unless that is explicitly the user's configured choice.
