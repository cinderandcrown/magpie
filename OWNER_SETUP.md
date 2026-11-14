# OWNER_SETUP — what Nicholas still must do


The public code repo (`cinderandcrown/magpie`) and GitHub Secrets (`APPLE_TEAM_ID`, `ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_KEY_P8`) already exist. Most of the plan’s OWNER_SETUP checklist is done. **Only the items below remain.**

Docs checked: [App Store Connect — Create an app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app), [TestFlight](https://developer.apple.com/testflight/), [GitHub deploy keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys).

## 1. App Store Connect app record (needed before any TestFlight upload)

The ASC API does not reliably create the storefront app record. Create it in App Store Connect → My Apps → **(+)** with:

| Field | Value |
| --- | --- |
| Platforms | iOS |
| Name | MAGPIE |
| Primary language | English (U.S.) |
| Bundle ID | `com.cinderandcrown.magpie` (register the App ID first if the picker is empty: developer.apple.com → Identifiers, or let the TestFlight / Register Bundle ID workflow create it) |
| SKU | `magpie` |
| User Access | Full Access (or as you prefer) |

You said you will handle the ASC steps.

## 2. TestFlight on your iPhone

1. Install **TestFlight** from the App Store.
2. After the first successful `testflight/*` tag upload, open the build in App Store Connect → TestFlight → Internal Testing.
3. Join the internal group (CI tries to create **MAGPIE team** and add the account holder).
4. Install MAGPIE from TestFlight and confirm the square follows your finger.

**Fire Fox** pushes TestFlight tags (agents do not, unless asked). When ready:

```bash
git tag testflight/YYYY-MM-DD
git push origin testflight/YYYY-MM-DD
```

## 3. Private content repo + deploy key (later — not Mission 0)

Needed when art, audio, levels, or economy tables leave placeholders. Not required to prove the loop.

1. Create a **private** GitHub repo for content (suggested name: `cinderandcrown/magpie-content`).
2. Add a read-only **deploy key** on that repo; store the private key in a Magpie Actions secret (e.g. `CONTENT_DEPLOY_KEY`).
3. Wire CI to fetch content at build time. Keep paid/licensed assets out of the public repo.

## 4. Export compliance (question — not approved)

Proposed for Info.plist once you confirm: `ITSAppUsesNonExemptEncryption` = `false` (standard HTTPS-only / no custom crypto). **Not written into the app yet.** See checkpoint questions.
