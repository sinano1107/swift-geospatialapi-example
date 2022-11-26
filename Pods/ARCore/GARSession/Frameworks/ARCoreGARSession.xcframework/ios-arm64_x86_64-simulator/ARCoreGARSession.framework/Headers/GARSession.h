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

#import <ARKit/ARKit.h>

#import <ARCoreGARSession/GARAnchor.h>
#import <ARCoreGARSession/GARFrame.h>
#import <ARCoreGARSession/GARFramePair.h>
#import <ARCoreGARSession/GARSessionConfiguration.h>
#import <ARCoreGARSession/GARSessionDelegate.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * ARCore session class. Adds **ARCore** features to an app using **ARKit**.
 * All `NSError`'s returned by methods in this class have domain GARSessionErrorDomain and code a
 * value of GARSessionErrorCode - see GARSessionError.h.
 * For Augmented Faces, see GARAugmentedFaceSession. See categories of this class for other
 * features. Each feature must be turned on by using |setConfiguration:error:| prior to use.
 */
API_AVAILABLE(ios(11.0))
@interface GARSession : NSObject

/**
 * The most recent frame pair, containing the most recent `ARFrame` passed into #update:error: and
 * the corresponding returned GARFrame.
 */
@property(atomic, readonly, nullable) GARFramePair *currentFramePair;

/**
 * The delegate for receiving callbacks about the GARSession.
 */
@property(atomic, weak, nullable) id<GARSessionDelegate> delegate;

/**
 * The dispatch queue on which the delegate receives calls.
 * If `nil`, callbacks happen on the main thread.
 */
@property(atomic, nullable) dispatch_queue_t delegateQueue;

/**
 * Creates a GARSession with an API key and bundle identifier.
 *
 * @param apiKey Your API key for **Google Cloud Services**.
 * @param bundleIdentifier The bundle identifier associated to your API key. If `nil`, defaults to
 *                         `[[NSBundle mainBundle] bundleIdentifier]`.
 * @param error Out parameter for an `NSError`. Possible errors:
 *              GARSessionErrorCodeDeviceNotCompatible - this device or OS version
 *                                                       is not currently supported.
 *              GARSessionErrorCodeInvalidArgument - API key is `nil` or empty.
 * @return The new GARSession, or `nil` if there is an error.
 */
+ (nullable instancetype)sessionWithAPIKey:(NSString *)apiKey
                           bundleIdentifier:(nullable NSString *)bundleIdentifier
                                      error:(NSError **)error;

/**
 * Creates a GARSession.
 * To authenticate with Google Cloud Services, use #setAuthToken:.
 *
 * @param error Out parameter for an `NSError`. Possible errors:
 *              GARSessionErrorCodeDeviceNotCompatible - this device or OS version
 *                                                       is not currently supported.
 * @return The new GARSession, or `nil` if there is an error.
 */
+ (nullable instancetype)sessionWithError:(NSError **)error NS_SWIFT_NAME(session());

/// @cond
/**
 * Use #sessionWithAPIKey:bundleIdentifier:error: to instantiate a GARSession with an API Key.
 * Use #sessionWithError: to instantiate a GARSession without an API Key, followed by #setAuthToken:
 * to authenticate with the Google Cloud Services.
 */
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
/// @endcond

/**
 * Provide an auth token to use when authenticating with Google Cloud Services. If the
 * session was created with an API Key, the token will be ignored and an error will be logged.
 * Otherwise, the most recent valid auth token passed in will be used. Call this method each time
 * you refresh your token.
 *
 * @param authToken Token to use when authenticating with Google Cloud Services. This
 *                  must be a nonempty ASCII string with no spaces or control characters. This will
 *                  be used until another token is passed in. See documentation for supported token
 *                  types.
 */
- (void)setAuthToken:(NSString *)authToken;

/**
 * Sets the configuration for the session.
 *
 * @param configuration The new configuration to use.
 * @param error Out param for an `NSError`.
 */
- (void)setConfiguration:(GARSessionConfiguration *)configuration error:(NSError **)error;

/**
 * Updates the GARSession with an `ARFrame`.
 * Call this method with every `ARFrame` to keep the sessions synced. Can be called on any thread.
 * Normally, this should be called from your `ARSessionDelegate`'s
 * `session:didUpdateFrame:` method.
 *
 * @param frame The next `ARFrame` from **ARKit**.
 * @param error Out parameter for `NSError`. Possible errors:
 *              GARSessionErrorCodeInvalidArgument - invalid (`nil`) frame.
 *              GARSessionErrorCodeFrameOutOfOrder - frame has a smaller timestamp than previous.
 * @return The GARFrame corresponding to the `ARFrame` passed in, or `nil` if there is an error.
 */
- (nullable GARFrame *)update:(ARFrame *)frame error:(NSError **)error;

/**
 * Removes an anchor from the session.
 *
 * @param anchor The anchor to remove.
 */
- (void)removeAnchor:(GARAnchor *)anchor;

@end

NS_ASSUME_NONNULL_END
