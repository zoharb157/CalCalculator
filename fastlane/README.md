# Fastlane Configuration

This Fastlane configuration is **fully automated** and designed to work seamlessly in CI/CD environments.

## Features

- ✅ **Fully Automated**: No manual intervention required
- ✅ **CI/CD Ready**: Works in GitHub Actions and other CI systems
- ✅ **Environment-Based**: All configuration via environment variables
- ✅ **Auto-Detection**: Automatically finds IPA files, checks app existence, etc.
- ✅ **Error Handling**: Graceful error handling with clear messages

## Required Environment Variables

### App Store Connect API (for TestFlight deployment)

```bash
APP_STORE_CONNECT_API_KEY_ID=your_key_id
APP_STORE_CONNECT_ISSUER_ID=your_issuer_id
APP_STORE_CONNECT_KEY_FILEPATH=./fastlane/AuthKey.p8
```

### AWS CodeCommit (for private Swift packages)

```bash
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_DEFAULT_REGION=us-east-1
```

### Optional Configuration

All of these have sensible defaults but can be overridden:

```bash
FASTLANE_PROJECT=CalCalculatorAiPlaygournd.xcodeproj
FASTLANE_SCHEME=CalCalculator
FASTLANE_APP_NAME=CalCalculator
FASTLANE_BUNDLE_IDENTIFIER=CalCalculatorAiPlaygournd
FASTLANE_TEAM_ID=5NS9ZUMYCS
```

## Available Lanes

### `deploy_to_testflight`
**Fully automated TestFlight deployment**

```bash
bundle exec fastlane deploy_to_testflight
```

This lane:
1. Sets up AWS CodeCommit credentials
2. Verifies App Store Connect credentials
3. Checks if app exists (creates if needed)
4. Runs unit tests
5. Increments build number
6. Builds and archives the app
7. Uploads to TestFlight

### `run_unit_tests`
**Run unit tests only**

```bash
bundle exec fastlane run_unit_tests
# or
bundle exec fastlane test
```

### `create_app_if_needed`
**Create app in App Store Connect if it doesn't exist**

```bash
bundle exec fastlane create_app_if_needed
# or
bundle exec fastlane create_app
```

This will only create the app if it doesn't already exist.

## CI/CD Integration

### GitHub Actions

The workflow automatically:
- Sets up all required environment variables from GitHub Secrets
- Configures AWS CodeCommit credentials
- Sets up App Store Connect API key
- Runs tests and deploys to TestFlight

### Required GitHub Secrets

- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY` (base64-encoded `.p8` file)
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

## Local Development

### First Time Setup

1. Place your App Store Connect API key in `fastlane/AuthKey.p8`
2. Set environment variables (or use `.env` file with `dotenv` gem)
3. Run: `bundle exec fastlane deploy_to_testflight`

### Manual Override

If you need to override any configuration:

```bash
FASTLANE_SCHEME=MyScheme bundle exec fastlane deploy_to_testflight
```

## Troubleshooting

### "App not found in App Store Connect"
- Run: `bundle exec fastlane create_app_if_needed`
- Or create manually at https://appstoreconnect.apple.com

### "Authentication failed"
- Verify your App Store Connect API credentials
- Check that the `.p8` file is correct and not expired
- Ensure the Key ID and Issuer ID match your API key

### "No provisioning profiles"
- The app must exist in App Store Connect first
- Run: `bundle exec fastlane create_app_if_needed`
- Wait a few minutes for provisioning profiles to be generated

### "jwt-kit compilation errors"
- This is a known issue with jwt-kit v5.3.0 and Swift 6
- The errors are in a third-party package, not your app
- Contact SDK maintainers for an update

## Architecture

The Fastfile is organized into:
- **Configuration**: Environment-based constants
- **Helper Methods**: Reusable functions for credentials, file finding, etc.
- **Main Lanes**: Public-facing lanes for common tasks
- **Private Lanes**: Internal lanes prefixed with `_`

All lanes are designed to be idempotent and handle errors gracefully.
