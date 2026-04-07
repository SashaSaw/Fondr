# TODO

Future improvements and technical debt.

## Privacy & Compliance

- [x] **Privacy Manifest** — Created `PrivacyInfo.xcprivacy` declaring UserDefaults usage
- [x] **Privacy Policy** — Written and hosted at `website/privacy.html`
- [ ] **GDPR: Download My Data** — Add a data export feature so users can request a copy of all their data. Not required at launch but reduces legal risk
- [ ] **Privacy policy link in app** — Add a link to the privacy policy in the Settings screen

## Landing Page

- [ ] **App Store link** — Replace placeholder `#` links in `website/index.html` with real App Store URL after upload
- [x] **Contact details** — Added contact email to privacy policy
- [ ] **Copyright** — Update copyright holder name in `website/index.html` and `website/privacy.html` footer

## Security Hardening

- [ ] **Tighten CORS** — Backend has `origin: '*'` (accepts requests from any origin). Not urgent for mobile-only, but should be locked to specific domains if a web client is ever added
- [ ] **Hash refresh tokens** — Refresh tokens are stored as plain UUIDs in the database. Ideally hash them like passwords so a DB breach doesn't expose valid tokens. Low priority since they're random UUIDs
- [ ] **Rate limiting** — No rate limiting on auth endpoints. Add throttling to prevent brute-force login attempts
