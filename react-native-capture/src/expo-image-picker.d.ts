// The app installs expo-image-picker; this package only names it. Declaring
// the module here keeps this package's own build free of the Expo toolchain.
declare module "expo-image-picker" {
  type Module = import("./expo.js").ExpoImagePickerModule;
  export const requestCameraPermissionsAsync: Module["requestCameraPermissionsAsync"];
  export const launchCameraAsync: Module["launchCameraAsync"];
  export const launchImageLibraryAsync: Module["launchImageLibraryAsync"];
}
