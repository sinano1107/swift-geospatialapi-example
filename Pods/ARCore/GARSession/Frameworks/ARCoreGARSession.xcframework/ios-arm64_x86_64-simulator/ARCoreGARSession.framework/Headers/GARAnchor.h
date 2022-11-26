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

#include <simd/simd.h>

#import <ARCoreGARSession/GARTrackingState.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * ARCore anchor class. A GARAnchor is an immutable snapshot of an underlying anchor at a particular
 * timestamp. All snapshots of the same underlying anchor will have the same identifier.
 */
@interface GARAnchor : NSObject <NSCopying>

/**
 * Transform of anchor relative to world origin. This should only be considered valid if the
 * property #hasValidTransform returns `YES`.
 */
@property(nonatomic, readonly) matrix_float4x4 transform;

/**
 * Unique Identifier for this anchor. `isEqual:` will return `YES` for another GARAnchor with
 * the same identifier, and the `hash` method is also computed from the identifier.
 */
@property(nonatomic, readonly) NSUUID *identifier;

/**
 * Whether or not this anchor has a valid transform. Equivalent to
 * `self.trackingState == GARTrackingStateTracking`.
 */
@property(nonatomic, readonly) BOOL hasValidTransform;

/** The tracking state of the anchor. */
@property(nonatomic, readonly) GARTrackingState trackingState;

/// @cond
/**
 * Instantiated by the library.
 */
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
/// @endcond

@end

NS_ASSUME_NONNULL_END
