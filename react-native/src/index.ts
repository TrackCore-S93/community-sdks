// Everything the JavaScript SDK exports is exported here unchanged: the error
// classes, the helpers and the models are the same objects, so `instanceof`
// and `isErrorOfCode` work across both. Only the client is this package's own.
export * from "@trackcore/community-sdk";
export { Community, createCommunityClient, type CommunityDeviceOptions, type DeviceFile, type DeviceMediaAPI } from "./client.js";

/** The version of this SDK. */
export const REACT_NATIVE_SDK_VERSION = "0.1.2";
