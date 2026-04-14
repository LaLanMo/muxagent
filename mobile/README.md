# muxagent mobile

Flutter mobile client for `muxagent`.

## Firebase setup

The committed Firebase config files in this repo are placeholders for open-source
distribution. Replace these files with your own Firebase project settings before
building push-notification enabled app builds:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

Without project-specific Firebase credentials, the app can compile, but push
notifications and related messaging flows are not expected to work correctly.
