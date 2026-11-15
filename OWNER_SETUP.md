# OWNER_SETUP — what remains for Nicholas / Fire Fox

The public code repo (`cinderandcrown/magpie`), GitHub Secrets (`APPLE_TEAM_ID`, `ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_KEY_P8`), and the App Store Connect app record are in place.

Docs checked: [TestFlight](https://developer.apple.com/testflight/), [GitHub deploy keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys).

## Done

### App Store Connect app record

| Field | Value |
| --- | --- |
| Name | Magpie Toy City (placeholder; “MAGPIE” was taken) |
| Apple ID | 6834947645 |
| Bundle ID | `com.cinderandcrown.magpie` |
| SKU | `magpie-001` |
| Primary language | English (U.S.) (as created) |

## Still open

### 1. TestFlight on the iPhone

1. Install **TestFlight** from the App Store (if needed).
2. After a successful `testflight/*` tag upload, open the build in App Store Connect → TestFlight → Internal Testing.
3. Join the internal group (CI tries to create **MAGPIE team** and add the account holder).
4. Install the app and confirm the square follows your finger.

**You** (or Fire Fox) push TestFlight tags — agents do not. When ready:

```bash
git tag testflight/YYYY-MM-DD
git push origin testflight/YYYY-MM-DD
```

### 2. Private content repo + deploy key (later — not Mission 0)

Needed when art, audio, levels, or economy tables leave placeholders.

1. Create a **private** GitHub repo for content (suggested: `cinderandcrown/magpie-content`).
2. Add a read-only **deploy key**; store the private key in a Magpie Actions secret (e.g. `CONTENT_DEPLOY_KEY`).
3. Wire CI to fetch content at build time. Keep paid/licensed assets out of the public repo.

### 3. Export compliance (question — not approved)

Proposed for Info.plist once confirmed: `ITSAppUsesNonExemptEncryption` = `false` (HTTPS-only / no custom crypto). **Not written into the app yet.**
