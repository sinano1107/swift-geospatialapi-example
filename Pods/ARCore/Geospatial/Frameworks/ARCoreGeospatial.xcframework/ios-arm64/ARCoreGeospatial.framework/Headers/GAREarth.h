/*
 * Copyright 2018 Google LLC. All Rights Reserved.
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

#import <ARCoreGeospatial/GAREarthState.h>
#import <ARCoreGeospatial/GARGeospatialTransform.h>
#import <ARCoreGARSession/GARTrackingState.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Provides localization ability in Geospatial coordinates. To use `GAREarth`, configure the
 * `GARSession` with an appropriate `GARGeospatialMode` using
 * `GARSessionConfiguration#geospatialMode` and `GARSession#setConfiguration:error:`.
 */
@interface GAREarth : NSObject

/**
 * The current global transform of the device. If `trackingState` is not
 * `GARTrackingStateTracking`, this will be nil.
 */
@property(nonatomic, readonly, nullable) GARGeospatialTransform *cameraGeospatialTransform;

/** The current state of tracking for `GAREarth`. */
@property(nonatomic, readonly) GARTrackingState trackingState;

/** The current Earth state. */
@property(nonatomic, readonly) GAREarthState earthState;

/// @cond
/**
 * Instantiated by the library.
 */
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
/// @endcond

@end

NS_ASSUME_NONNULL_END
