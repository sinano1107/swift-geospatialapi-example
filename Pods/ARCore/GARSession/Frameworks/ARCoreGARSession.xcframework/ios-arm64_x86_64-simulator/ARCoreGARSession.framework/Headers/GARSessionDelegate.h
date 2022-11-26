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

@class GARAnchor;
@class GARSession;

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate for receiving callbacks from a GARSession. All methods are optional.
 */
API_AVAILABLE(ios(11.0))
@protocol GARSessionDelegate <NSObject>

@optional

/**
 * A call to GARSession#hostCloudAnchor:error: was successful.
 * @param session The GARSession in which the anchor was hosted.
 * @param anchor The GARAnchor that was returned from GARSession#hostCloudAnchor:error:,
 *               snapshotted at the completion of hosting.
 */
- (void)session:(GARSession *)session didHostAnchor:(GARAnchor *)anchor
    NS_SWIFT_NAME(session(_:didHost:));

/**
 * A call to GARSession#hostCloudAnchor:error: failed. Inspect the value of anchor.cloudState for
 * details.
 * @param session The GARSession in which the anchor was hosted.
 * @param anchor The GARAnchor that was returned from GARSession#hostCloudAnchor:error:,
 *               snapshotted at the failure of hosting.
 */
- (void)session:(GARSession *)session didFailToHostAnchor:(GARAnchor *)anchor
    NS_SWIFT_NAME(session(_:didFailToHost:));

/**
 * A call to GARSession#resolveCloudAnchorWithIdentifier:error: was successful.
 * @param session The GARSession in which the anchor was resolved.
 * @param anchor The GARAnchor that was returned from
 *               GARSession#resolveCloudAnchorWithIdentifier:error:, snapshotted at the completion
 *               of resolving.
 */
- (void)session:(GARSession *)session didResolveAnchor:(GARAnchor *)anchor
    NS_SWIFT_NAME(session(_:didResolve:));

/**
 * A call to GARSession#resolveCloudAnchorWithIdentifier:error: failed. Inspect the value of
 * anchor.cloudState for details.
 * @param session The GARSession in which the anchor was resolved.
 * @param anchor The GARAnchor that was returned from
 *               GARSession#resolveCloudAnchorWithIdentifier:error:, snapshotted at the failure of
 *               resolving.
 */
- (void)session:(GARSession *)session didFailToResolveAnchor:(GARAnchor *)anchor
    NS_SWIFT_NAME(session(_:didFailToResolve:));

@end

NS_ASSUME_NONNULL_END
