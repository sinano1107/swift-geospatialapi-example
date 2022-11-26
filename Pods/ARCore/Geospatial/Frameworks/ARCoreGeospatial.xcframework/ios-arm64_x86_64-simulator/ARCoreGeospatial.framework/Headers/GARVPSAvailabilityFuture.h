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

#import <ARCoreGeospatial/GARFutureState.h>
#import <ARCoreGeospatial/GARVPSAvailability.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A handle to an async operation initiated by a call to
 * GARSession#checkVPSAvailabilityAtCoordinate:completionHandler.
 */
@interface GARVPSAvailabilityFuture : NSObject

/** The current future state. */
@property(nonatomic, readonly) GARFutureState state;

/**
 * The result of the async operation, or a default value if the operation isn't complete. This should
 * only be used after checking that `state` is `GARFutureStateDone`.
 */
@property(nonatomic, readonly) GARVPSAvailability result;

/**
 * Cancel the async operation if it's still pending. If the operation was cancelled by this
 * invocation, this method returns true and the callback (if any) will never be invoked.
 */
- (BOOL)cancel;

/** Instances are returned by GARSession#checkVPSAvailabilityAtCoordinate:completionHandler. */
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
