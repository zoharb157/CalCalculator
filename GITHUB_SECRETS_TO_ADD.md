# GitHub Secrets Setup

Add these 3 secrets to your GitHub repository:

## Steps:
1. Go to: `https://github.com/[your-username]/CalCalculator/settings/secrets/actions`
2. Click "New repository secret" for each one below

## Secrets to Add:

### 1. `APP_STORE_CONNECT_API_KEY_ID`
**Value:** `L8VPZGLM970R`

### 2. `APP_STORE_CONNECT_ISSUER_ID`
**Value:** `19020611-ed38-4968-8ca9-4592b8171acc`

### 3. `APP_STORE_CONNECT_KEY`
**Value (base64 encoded):**
```
LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JR0hBZ0VBTUJNR0J5cUdTTTQ5QWdFR0NDcUdTTTQ5QXdFSEJHMHdhd0lCQVFRZ2RaOU9qakg4TVV3Ym1qUmIKRU9sK1B1T0lQN2hHajlzd3FLVXlwb2V5em1xaFJBTkNBQVNUTEFYd1JyVmlDSURMby9oVU1kQjdYVCs5RTdmeAptQ3Z6ZHI2YlplOHIrYUhLZUtKZTZFRGZraUZRV1gyM2h5d25UUTVpNHJPVloxU2dIZktMamhTcgotLS0tLUVORCBQUklWQVRFIEtFWS0tLS0t
```

## Verification:
After adding all 3 secrets, your CI/CD pipeline will:
- ✅ Run unit tests on every push to `main`
- ✅ Build and upload to TestFlight if tests pass
- ✅ Use the App Store Connect API key for authentication

## Current Configuration:
- **Team ID:** `5NS9ZUMYCS` (already configured in `fastlane/Appfile`)
- **Bundle ID:** `CalCalculatorAi`
- **Scheme:** `playground`
- **Project:** `playground.xcodeproj`

