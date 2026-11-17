## 0.1.0

The first version: every route of the Community API, sign-in with a
publishable key, typed models and error codes generated from the API
contract, retries, image upload, rapid-tap-safe reactions and live updates.

### Added since the first build

- `push`: `register`, `unregister`, `preference`, `setEnabled`. Registers the
  phone's Firebase or Expo push token so notifications reach the phone while
  the app is closed. `signOut` unregisters it.
- `settings.update(pushEnabled: …)`: the creator's switch for push.
