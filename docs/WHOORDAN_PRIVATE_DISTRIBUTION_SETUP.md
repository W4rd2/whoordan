# Whoordan Private Distribution Setup

Whoordan private distribution is a signed sideload/private install flow only. It must not use TestFlight, the public App Store, unsigned IPA hosting, jailbroken installs, cracked signing, or signing bypasses.

## Selected Path

Use signed Ad Hoc OTA distribution for Ward/test devices.

Why: this repo does not prove Apple Developer Enterprise Program eligibility or EU Web Distribution approval, and Apple documents Ad Hoc as the route for installing apps directly on registered devices. Apple states that registered devices can install apps through Ad Hoc distribution and that Apple Developer Program members can register a limited number of devices per product family per membership year. See Apple’s [Devices overview](https://developer.apple.com/help/account/register-devices/devices-overview/) and [Distributing your app to registered devices](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices).

Allowed alternatives only if Ward later proves eligibility:

- Enterprise/in-house OTA: only with an eligible Apple Developer Enterprise Program account. Apple says Enterprise is for proprietary internal-use apps distributed privately to employees, and has eligibility requirements such as an organization with 100 or more employees. See [Apple Developer Enterprise Program](https://developer.apple.com/programs/enterprise/).
- EU Web Distribution: only if Ward is eligible under Apple’s current alternative distribution rules and `whoordan.w4rd2.tech` is approved by Apple for that distribution path.

## Hosting And DNS

`whoordan.w4rd2.tech` must point to the deployed `web/` Next app.

Required hosting setup:

- DNS: add the hosting provider’s required `CNAME`, `A`, or `ALIAS` record for `whoordan.w4rd2.tech`.
- TLS: HTTPS must be active before any install link is used.
- Runtime: Node-compatible Next hosting with server routes enabled.
- Protected storage: keep `Whoordan.ipa` outside git in a private directory or private object storage reachable only by the server.
- Cache policy: protected manifest and IPA routes send `Cache-Control: no-store, private`.
- Referrer policy: protected responses send `Referrer-Policy: no-referrer`.

The install URL shape is:

```text
itms-services://?action=download-manifest&url=https://whoordan.w4rd2.tech/protected/manifest.plist?token=<short-lived-token>
```

The token is in the URL because iOS OTA install fetches the manifest and IPA outside a normal browser session. Keep tokens short-lived, redact query strings in hosting logs where possible, and never publish permanent artifact URLs.

## Environment Variables

Set these as hosting secrets or deployment environment variables. Do not commit values.

```text
WHOORDAN_PUBLIC_BASE_URL=https://whoordan.w4rd2.tech
WHOORDAN_DOWNLOAD_PASSWORD_HASH=<server-side scrypt hash>
WHOORDAN_DOWNLOAD_TOKEN_SECRET=<long random signing secret>
WHOORDAN_RELEASE_STORAGE_DIR=<private server-side directory containing the signed IPA>
WHOORDAN_IPA_FILENAME=Whoordan.ipa
WHOORDAN_BUNDLE_IDENTIFIER=com.w4rd2.whoordan
WHOORDAN_RELEASE_VERSION=1.2.3
WHOORDAN_RELEASE_BUILD=123
WHOORDAN_MINIMUM_OS=17.0
WHOORDAN_RELEASE_NOTES=<short wellness-safe release notes>
WHOORDAN_GITHUB_URL=<optional GitHub repo URL>
```

Forbidden values:

- Apple certificate private keys in git
- `.p12`, `.mobileprovision`, `.ipa`, `.xcarchive`, or `ExportOptions.plist` in git
- Supabase service-role keys
- `OPENAI_API_KEY` or `CODEX_API_KEY`

## Change The Download Password

Generate a new hash locally, then replace only the hosting secret `WHOORDAN_DOWNLOAD_PASSWORD_HASH`.

```bash
python3 - <<'PY'
import base64
import getpass
import hashlib
import uuid

password = getpass.getpass("Download password: ").encode("utf-8")
salt = str(uuid.uuid4())
digest = hashlib.scrypt(password, salt=salt.encode("utf-8"), n=16384, r=8, p=1, dklen=32)
encoded = base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")
print(f"scrypt${salt}${encoded}")
PY
```

Never place the raw password in frontend code, committed docs, shell history, or command arguments.

## Add The GitHub Link

Set `WHOORDAN_GITHUB_URL` in hosting secrets or environment variables. If unset, the landing page simply omits the GitHub button.

## Apple Signing Setup

Keep the bundle identifier stable:

```text
com.w4rd2.whoordan
```

Required Ad Hoc prerequisites:

1. Active Apple Developer Program membership.
2. App ID for `com.w4rd2.whoordan` with the current entitlements, including HealthKit.
3. iPhone UDIDs registered in Apple Developer Certificates, Identifiers & Profiles.
4. iOS Distribution certificate with private key available on the build Mac or CI signer.
5. Ad Hoc provisioning profile containing the registered devices and app entitlements.
6. Xcode archive/export to a signed IPA.
7. Upload the signed `Whoordan.ipa` to protected release storage.
8. Set `WHOORDAN_RELEASE_VERSION` and `WHOORDAN_RELEASE_BUILD` to match the IPA.

The website scaffolding is ready without those Apple assets, but installation remains blocked until the IPA is signed and hosted.

## Update Flow

The app fetches:

```text
https://whoordan.w4rd2.tech/api/update-manifest
```

Manifest shape:

```json
{
  "bundleIdentifier": "com.w4rd2.whoordan",
  "version": "1.2.3",
  "build": "123",
  "minimumOS": "17.0",
  "releaseNotes": "Short wellness-safe release notes.",
  "installUrl": "https://whoordan.w4rd2.tech/update"
}
```

The update check is GET-only and must not send health data, analytics, user identifiers, auth tokens, or stored records. iOS does not support silent updates for this flow; users must confirm the system-mediated install.

## Validation

Run after code changes:

```bash
cd web
npm test
npm run lint
npm run build
cd ..
xcodebuild -list -project Whoordan.xcodeproj
xcodebuild test -project Whoordan.xcodeproj -scheme Whoordan -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild build -project Whoordan.xcodeproj -scheme Whoordan -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
swiftlint lint --config .swiftlint.yml
```

Run after signing artifacts exist:

```bash
plutil -lint /path/to/manifest.plist
codesign -dv --verbose=4 /path/to/Whoordan.app
security cms -D -i /path/to/embedded.mobileprovision
```

## Blocked Until Ward Provides

- DNS access for `whoordan.w4rd2.tech`
- Hosting provider/project and deployment secrets
- Apple Developer Program team access
- Registered device UDIDs
- Distribution certificate and private key on the signing machine
- Ad Hoc provisioning profile
- Signed IPA and release storage location
- Enterprise or EU Web Distribution eligibility evidence if Ward chooses those alternatives
