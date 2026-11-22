# FamilyVault - Google Play Store Legal & Privacy Documents

This folder contains all the official compliance pages required for publishing **FamilyVault** (`com.pgdeveloper.docnet`) on the **Google Play Console**.

---

## Files Included

1. **`privacy-policy.html`**
   - **Play Console Section**: *Store Presence > Store Listing > Privacy Policy URL*
   - Fully covers Zero-Knowledge architecture, client-side AES-256-GCM encryption, collected data (account auth only), non-collected data (no plaintext files, keys, or biometrics), and developer contact (`vtpbca60@gmail.com`).

2. **`delete-account.html`**
   - **Play Console Section**: *App Content > Data Safety > Account Deletion URL*
   - Explains what data is purged upon deletion, zero-retention guarantee, in-app deletion steps, and provides an interactive web request form.

3. **`index.html`**
   - Main landing portal linking to both Privacy Policy and Account Deletion pages.

---

## How to Host for Free (Google Play URLs)

### Option 1: GitHub Pages (Recommended)
1. Push your repository to GitHub.
2. In your repo on GitHub, go to **Settings > Pages**.
3. Under **Branch**, select `main` (or your branch) and select folder `/docs` (or `/privacy_policy`).
4. Click **Save**.
5. Your live links will be:
   - Privacy Policy: `https://<your-username>.github.io/<repo>/privacy-policy.html`
   - Account Deletion: `https://<your-username>.github.io/<repo>/delete-account.html`

### Option 2: Firebase Hosting
If you already use Firebase for this project:
```bash
firebase init hosting
firebase deploy
```
Your live links will be:
- `https://<your-project-id>.web.app/privacy-policy.html`
- `https://<your-project-id>.web.app/delete-account.html`

