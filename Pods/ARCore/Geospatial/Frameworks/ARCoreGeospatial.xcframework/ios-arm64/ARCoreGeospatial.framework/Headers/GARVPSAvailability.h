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
 * The result of `GARSession#checkVPSAvailabilityAtCoordinate:completionHandler:`.
 */
typedef NS_ENUM(NSInteger, GARVPSAvailability) {
  /**
   * The request to the remote service is not yet completed, so the availability
   * is not yet known.
   */
  GARVPSAvailabilityUnknown = 0,

  /** VPS is available at the requested location. */
  GARVPSAvailabilityAvailable = 1,

  /** VPS is not available at the requested location. */
  GARVPSAvailabilityUnavailable = 2,

  /** An internal error occurred while determining availability. */
  GARVPSAvailabilityErrorInternal = -1,

  /**
   * The external service could not be reached due to a network connection
   * error.
   */
  GARVPSAvailabilityErrorNetworkConnection = -2,

  /**
   * An authorization error occurred when communicating with the Google Cloud
   * ARCore API. See <a
   * href="https://developers.google.com/ar/develop/ios/geospatial/enable">Enable
   * the Geospatial API</a> for troubleshooting steps.
   */
  GARVPSAvailabilityErrorNotAuthorized = -3,

  /** Too many requests were sent. */
  GARVPSAvailabilityErrorResourceExhausted = -4,
};
