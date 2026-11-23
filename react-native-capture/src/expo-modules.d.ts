// The app installs these; this package only names them. Declaring the
// modules here keeps this package's own build free of the Expo toolchain.
declare module "expo-document-picker" {
  type Module = import("./expo-document-picker.js").ExpoDocumentPickerModule;
  export const getDocumentAsync: Module["getDocumentAsync"];
}
declare module "expo-av" {
  export const Audio: import("./expo-av.js").ExpoAudioModule;
}
