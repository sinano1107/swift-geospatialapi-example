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

#import <Foundation/Foundation.h>

/**
 * Describes the desired behavior of ARCore Geospatial API features and
 * capabilities. Not all devices support all modes. Use `GARSession#isGeospatialModeSupported:`
 * to find whether the current device supports a particular Geospatial mode.
 * The default value is `GARGeospatialModeDisabled`.
 */
typedef NS_ENUM(NSInteger, GARGeospatialMode) {
  /** The Geospatial API is disabled. */
  GARGeospatialModeDisabled = 0,

  /**
   * The Geospatial API is enabled. `GARFrame#earth` will return valid `GAREarth` instances, and
   * `GARSession#createAnchorWithCoordinate:altitude:eastUpSouthQAnchor:error:` will be enabled.
   *
   * Configuring the session with this mode may result in the following
   * error codes:
   *
   *  - GARSessionErrorCodeLocationPermissionNotGranted - Geospatial mode requires location
   *       permission (at least when-in-use) with full accuracy.
   *  - GARSessionErrorCodeConfigurationNotSupported - Geospatial mode not supported on this device
   *       or OS version. Use `GARSession#isGeospatialModeSupported:` to determine this before
   *       attempting to configure the session.
   */
  GARGeospatialModeEnabled = 1,
};
