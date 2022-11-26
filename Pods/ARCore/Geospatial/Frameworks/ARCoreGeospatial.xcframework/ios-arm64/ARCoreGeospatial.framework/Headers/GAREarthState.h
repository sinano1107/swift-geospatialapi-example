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
 * Describes the current state of `GAREarth`, containing the possible values of `GAREarth.earthState`.
 * When `GAREarth.trackingState` does not become `GARTrackingStateTracking`, this may contain the
 * cause of this failure.
 */
typedef NS_ENUM(NSInteger, GAREarthState) {
  /**
   * `GAREarth` is enabled, and has not encountered any problems. Localization is enabled and
   * functioning. Use `GAREarth.trackingState` to determine if it can be used.
   */
  GAREarthStateEnabled = 0,

  /** Earth localization has encountered an internal error. The app should not attempt to recover
    * from this error. Check the iOS device logs for more information.
    */
  GAREarthStateErrorInternal = -1,

  /**
   * The application failed to authenticate with Google Cloud. This may happen if:
   * - The Google Cloud Project has not enabled the ARCore API.
   * - The provided API key is invalid.
   * - The provided auth token is expired or invalid.
   * - No credentials have been provided.
   */
  GAREarthStateErrorNotAuthorized = -2,

  /**
   * The application has exhausted the quota allotted to the given
   * Google Cloud project. The developer should request additional quota
   * (https://cloud.google.com/docs/quota#requesting_higher_quota) for the
   * ARCore API for their project from the Google Cloud Console.
   */
  GAREarthStateErrorResourceExhausted = -3,
};
