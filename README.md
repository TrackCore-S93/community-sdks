# Community SDKs

The client SDKs for the Community API, one folder each.

| Folder | SDK | For |
|---|---|---|
| [`typescript/`](typescript) | `@trackcore/community-sdk` | A backend (secret key) or a browser (publishable key) |
| [`react-native/`](react-native) | `@trackcore/community-react-native` | A React Native or Expo app |
| [`react-native-capture/`](react-native-capture) | `@trackcore/community-react-native-capture` | Add-on: opens the camera or gallery and uploads, in one call |
| [`flutter/`](flutter) | `trackcore_community` | A Flutter or Dart app |
| [`flutter-capture/`](flutter-capture) | `trackcore_community_capture` | Add-on: opens the camera or gallery and uploads, in one call |

Each folder is a complete package with its own readme, tests and licence.
Documentation: https://community.trackcore.app/developer/

## Installing

TypeScript and React Native are installed from this repository's releases;
npm cannot install a package from a folder of a git repository.

```sh
npm install https://github.com/TrackCore-S93/community-sdks/releases/download/typescript-v0.1.2/trackcore-community-sdk-0.1.2.tgz
npm install https://github.com/TrackCore-S93/community-sdks/releases/download/react-native-v0.1.2/trackcore-community-react-native-0.1.2.tgz
```

Flutter is installed from the `flutter` folder:

```yaml
dependencies:
  trackcore_community:
    git:
      url: https://github.com/TrackCore-S93/community-sdks.git
      ref: flutter-v0.1.3
      path: flutter
```

## Releases

One tag per package and version: `typescript-v0.1.2`, `react-native-v0.1.2`,
`react-native-capture-v0.1.0`, `flutter-v0.1.3`, `flutter-capture-v0.1.3`. The two npm packages are attached to their release as the
file `npm pack` produces.

## Developing

React Native is built on the TypeScript SDK and tests against its tarball,
and its capture add-on tests against both, so build them in this order:

```sh
cd typescript && npm install && npm test && npm pack
cd ../react-native && npm install && npm test && npm pack
cd ../react-native-capture && npm install && npm test
cd ../flutter && flutter pub get && flutter analyze && flutter test
cd ../flutter-capture && flutter pub get && flutter analyze && flutter test
```

All three are generated from the same API contract. Each keeps its own copy
under `contract/` (React Native uses the TypeScript SDK's).
