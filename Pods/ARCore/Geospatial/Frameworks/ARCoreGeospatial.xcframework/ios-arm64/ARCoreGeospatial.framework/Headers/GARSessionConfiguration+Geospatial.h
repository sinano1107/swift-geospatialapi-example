/*
 * Copyright 2022 Google LLC. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <ARCoreGeospatial/GARGeospatialMode.h>
#import <ARCoreGARSession/GARSessionConfiguration.h>

NS_ASSUME_NONNULL_BEGIN

/** Category adding Geospatial functionality to `GARSessionConfiguration`. */
@interface GARSessionConfiguration (Geospatial)

/**
 * Describes the desired behavior of the ARCore Geospatial API. The Geospatial API uses a
 * combination of Google's Visual Positioning Service (VPS) and GPS to determine the geospatial
 * pose.
 *
 * The Geospatial API is able to provide the best user experience when it is able to generate
 * high accuracy poses. However, the Geospatial API can be used anywhere, as long as the device is
 * able to determine its location, even if the available location information has low accuracy.
 *
 *  - In areas with VPS coverage, the Geospatial API is able to generate high accuracy poses.
 *    This can work even where GPS accuracy is low, such as dense urban environments. Under
 *    typical conditions, VPS can be expected to provide positional accuracy typically better
 *    than 5 meters and often around 1 meter, and a rotational accuracy of better than 5
 *    degrees. Use `GARSession#checkVPSAvailabilityAtCoordinate:completionHandler:` to
 *    determine if a given location has VPS coverage.
 *  - In outdoor environments with few or no overhead obstructions, GPS may be sufficient to
 *    generate high accuracy poses. GPS accuracy may be low in dense urban environments and
 *    indoors.
 *
 * A small number of ARCore supported devices do not support the Geospatial API. Use
 * `GARSession#isGeospatialModeSupported:` to determine if the current device is supported.
 * Affected devices are also indicated on the <a href="https://developers.google.com/ar/devices">ARCore
 * supported devices page</a>.
 *
 * The default mode is `GARGeospatialModeDisabled`. If the mode is changed, existing Geospatial anchors will stop tracking.
 *
 * Remember to set a credential for authentication with Google Cloud before configuring, or
 * you may receive auth errors. See `GARSession#sessionWithAPIKey:bundleIdentifier:error:` and
 * `GARSession#setAuthToken:`, as well as documentation on
 * <a href="https://developers.google.com/ar/develop/ios/geospatial/enable">Enable the Geospatial API</a>.
 *
 * Configuring may result in the following error codes:
 *
 *  - `GARSessionErrorCodeLocationPermissionNotGranted` - Geospatial mode requires location
 * permission (at least when-in-use) with full accuracy.
 *  - `GARSessionErrorCodeConfigurationNotSupported` - Geospatial mode not supported on this device
 * or OS version. Use `GARSession#isGeospatialModeSupported:` to determine this before attempting to
 * configure the session.
 */
@property(nonatomic) GARGeospatialMode geospatialMode;

@end

NS_ASSUME_NONNULL_END
