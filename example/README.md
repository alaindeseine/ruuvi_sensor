# ruuvi_sensor example

A two-screen Flutter app showing how to use `ruuvi_sensor`:

1. **Scan**: lists nearby RuuviTags with their live temperature, humidity, pressure and battery values.
2. **Tag**: tap a tag to read its device information and download its full logged history.

Run it on a physical Android device (BLE doesn't work on emulators):

```sh
flutter run
```

See `android/app/src/main/AndroidManifest.xml` for the required Bluetooth permissions and `android/app/build.gradle.kts` for `compileSdk = 37`.
