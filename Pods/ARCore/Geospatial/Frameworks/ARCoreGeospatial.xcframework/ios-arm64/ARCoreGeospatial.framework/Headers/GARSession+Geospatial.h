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

#import <CoreLocation/CoreLocation.h>

#include <simd/simd.h>

#import <ARCoreGARSession/GARAnchor.h>
#import <ARCoreGeospatial/GARGeospatialMode.h>
#import <ARCoreGeospatial/GARGeospatialTransform.h>
#import <ARCoreGARSession/GARSession.h>
#import <ARCoreGeospatial/GARVPSAvailability.h>
#import <ARCoreGeospatial/GARVPSAvailabilityFuture.h>

NS_ASSUME_NONNULL_BEGIN

/** Category adding Geospatial functionality to `GARSession`. */
API_AVAILABLE(ios(11.0))
@interface GARSession (Geospatial)

/**
 * Determines whether the given geospatial mode is supported on the current device and OS version.
 * If this returns NO, then configuring the session with the given geospatial mode will fail with
 * the error code `GARSessionErrorCodeConfigurationNotSupported`. A device may be incompatible
 * with a given mode due to insufficient sensor capabilities.
 *
 * @param geospatialMode The geospatial mode.
 * @return YES if the @p geospatialMode is supported, NO otherwise.
 */
- (BOOL)isGeospatialModeSupported:(GARGeospatialMode)geospatialMode;

/**
 * Creates a Geospatial anchor at the specified geodetic location and orientation relative to the
 * Earth.
 *
 * Latitude and longitude are defined by the
 * <a href="https://en.wikipedia.org/wiki/World_Geodetic_System">WGS84 specification</a>, and
 * altitude values are defined as the elevation above the WGS84 ellipsoid in meters.
 *
 * The rotation provided by @p eastUpSouthQAnchor is a rotation with respect to
 * an east-up-south coordinate frame. An identity rotation will have the anchor
 * oriented such that X+ points to the east, Y+ points up away from the center
 * of the earth, and Z+ points to the south.
 *
 * To create an anchor that has the +Z axis pointing in the same direction as
 * heading obtained from `GARGeospatialTransform`, use the following formula:
 *
 * \code
 * {qx, qy, qz, qw} = {0, sin((pi - heading * pi / 180.0) / 2), 0, cos((pi -
 * heading * pi / 180.0) / 2)}}.
 * \endcode
 *
 * An anchor's `GARAnchor.trackingState` will be `GARTrackingStatePaused` while
 * `GAREarth` is `GARTrackingStatePaused`. The tracking state will
 * permanently become `GARTrackingStateStopped` if the `GARSession`
 * configuration is set to `GARGeospatialModeDisabled`.
 *
 * Creating anchors near the north pole or south pole is not supported. If the
 * latitude is within 0.1° of the north pole or south pole (90° or -90 °),
 * this function will output `GARSessionErrorCodeInvalidArgument` and
 * the anchor will fail to be created.
 *
 * @param coordinate The latitude and longitude associated with the location, specified using the
 *     WGS84 reference frame. This must not be within .1° of the North or South pole (i.e. +- 90°).
 * @param altitude Altitude in reference to the WGS 84 ellipsoid, in meters. Positive values
 *     indicate altitudes above approximate sea level. Negative values indicate altitudes below
 *     approximate sea level.
 * @param eastUpSouthQAnchor Represents the quaternion from the anchor to East-Up-South (EUS)
 *     coordinates (i.e., +X points East, +Y points up, and +Z points South).
 * @param error Out param for an `NSError`. Possible error codes:
 *     GARSessionErrorCodeIllegalState - current geospatial mode is disabled.
 *     GARSessionErrorCodeInvalidArgument - latitude is not within range.
 * @return The new anchor, or `nil` if there was an error.
 */
- (nullable GARAnchor *)createAnchorWithCoordinate:(CLLocationCoordinate2D)coordinate
                                          altitude:(CLLocationDistance)altitude
                                eastUpSouthQAnchor:(simd_quatf)eastUpSouthQAnchor
                                             error:(NSError **)error
    NS_SWIFT_NAME(createAnchor(coordinate:altitude:eastUpSouthQAnchor:));

/**
 * Creates a Terrain anchor at the specified geodetic location, altitude relative
 * to the horizontal position’s terrain and orientation relative to the Earth.
 * Terrain means the ground, or ground floor inside a building with VPS coverage.
 *
 * The specified altitudeAboveTerrain is interpreted to be relative to the Earth's terrain
 * (or floor) at the specified latitude/longitude geodetic coordinates, rather
 * than relative to the WGS-84 ellipsoid. Specifying an altitudeAboveTerrain of 0 will
 * position the anchor directly on the terrain (or floor) whereas specifying a
 * positive altitudeAboveTerrain will position the anchor above the terrain (or floor),
 * against the direction of gravity.
 *
 * This function schedules a task to resolve the anchor's pose using the given parameters. You may
 * resolve multiple anchors at a time, but a session cannot be tracking more than 100 Terrain
 * Anchors at time. Attempting to resolve more than 100 Terrain Anchors will result in
 * 'GARSessionErrorCodeResourceExhausted'.
 *
 * If this function returns error nil, the terrain anchor's `GARAnchor.terrainState` will be
 * `GARTerrainAnchorStateTaskInProgress`, and its tracking state will be `GARTrackingStatePaused`.
 * This anchor remains in this state until its pose has been successfully resolved. If the resolving
 * task results in an error, the tracking state will be set to `GARTrackingStateStopped`.
 *
 * Latitude and longitude are defined by the
 * <a href="https://en.wikipedia.org/wiki/World_Geodetic_System">WGS84 specification</a>, and
 * altitude values are defined as the elevation above the WGS84 ellipsoid in meters.
 *
 * The rotation provided by @p eastUpSouthQAnchor is a rotation with respect to
 * an east-up-south coordinate frame. An identity rotation will have the anchor
 * oriented such that X+ points to the east, Y+ points up away from the center
 * of the earth, and Z+ points to the south.
 *
 * To create an anchor that has the +Z axis pointing in the same direction as
 * heading obtained from `GARGeospatialTransform`, use the following formula:
 *
 * \code
 * {qx, qy, qz, qw} = {0, sin((pi - heading * pi / 180.0) / 2), 0, cos((pi -
 * heading * pi / 180.0) / 2)}}.
 * \endcode
 *
 * An anchor's `GARAnchor.trackingState` will be `GARTrackingStateTracking` while
 * `GAREarth` is `GARTrackingStatePaused`. The tracking state will
 * permanently become `GARTrackingStateStopped` if the `GARSession`
 * configuration is set to `GARGeospatialModeDisabled`.
 *
 * Creating anchors near the north pole or south pole is not supported. If the
 * latitude is within 0.1° of the north pole or south pole (90° or -90°),
 * this function will output `GARSessionErrorCodeInvalidArgument` and
 * the anchor will fail to be created.
 *
 * @param coordinate The latitude and longitude associated with the location, specified using the
 *     WGS84 reference frame. This must not be within .1° of the North or South pole (i.e. +- 90°).
 * @param altitudeAboveTerrain Altitude above Earth's terrain, in meters.
 * @param eastUpSouthQAnchor Represents the quaternion from the anchor to East-Up-South (EUS)
 *     coordinates (i.e., +X points East, +Y points up, and +Z points South).
 * @param error Out param for an `NSError`. Possible error codes:
 *     GARSessionErrorCodeIllegalState - current geospatial mode is disabled.
 *     GARSessionErrorCodeInvalidArgument - latitude is not within range.
 *     GARSessionErrorCodeResourceExhausted - tried to create too many Terrain Anchors.
 * @return The new anchor, or `nil` if there was an error.
 */
- (nullable GARAnchor *)createAnchorWithCoordinate:(CLLocationCoordinate2D)coordinate
                              altitudeAboveTerrain:(CLLocationDistance)altitudeAboveTerrain
                                eastUpSouthQAnchor:(simd_quatf)eastUpSouthQAnchor
                                             error:(NSError **)error
    NS_SWIFT_NAME(createAnchorOnTerrain(coordinate:altitudeAboveTerrain:eastUpSouthQAnchor:));

/**
 * Converts the provided transform to a `GARGeospatialTransform` with respect to the
 * Earth. Its heading will be zero for a `GARGeospatialTransform` returned from this method.
 *
 * @param transform  The local transform in world coordinate space.
 * @param error Out param for an `NSError`. Possible error codes:
 *   -  `GARSessionErrorCodeIllegalState` - current Geospatial mode is disabled.
 *   -  `GARSessionErrorCodeNotTracking` - Earth's or Session's `ARTrackingState` is not
 *     `GARTrackingStateTracking`.
 * @return `GARGeospatialTransform`, or `nil` if there was an error.
 */
- (nullable GARGeospatialTransform *)geospatialTransformFromTransform:(matrix_float4x4)transform
                                                                error:(NSError **)error
    NS_SWIFT_NAME(geospatialTransform(transform:));

/**
 * Converts the provided Earth specified horizontal position, altitude and rotation with respect to
 * an east-up-south coordinate frame to a local transform in world coordinate space.
 *
 * @param coordinate The latitude and longitude associated with the location, specified using the
 *     WGS84 reference frame. This must not be within .1° of the North or South pole (i.e. +- 90°).
 * @param altitude Altitude in reference to the WGS 84 ellipsoid, in meters. Positive values
 *     indicate altitudes above approximate sea level. Negative values indicate altitudes below
 *     approximate sea level.
 * @param eastUpSouthQTarget Represents the quaternion from the target to East-Up-South (EUS)
 *     coordinates (i.e., +X points East, +Y points up, and +Z points South).
 * @param error Out param for an `NSError`. Possible error codes:
 *   -  `GARSessionErrorCodeIllegalState` - current geospatial mode is disabled.
 *   -  `GARSessionErrorCodeNotTracking` - Earth's or Session's ARTrackingState is not
 *     `GARTrackingStateTracking`.
 *   -  `GARSessionErrorCodeInvalidArgument` - latitude is not within range.
 * @return a local transform in world coordinate space.
 */
- (matrix_float4x4)transformFromGeospatialCoordinate:(CLLocationCoordinate2D)coordinate
                                            altitude:(CLLocationDistance)altitude
                                  eastUpSouthQTarget:(simd_quatf)eastUpSouthQTarget
                                               error:(NSError **)error
    NS_SWIFT_NAME(transform(coordinate:altitude:eastUpSouthQTarget:))
#if __has_attribute(swift_error)
    __attribute__((swift_error(nonnull_error)))
#endif
    ;

/**
 * Gets the availability of the Visual Positioning System (VPS) at a specified horizontal
 * position. The availability of VPS in a given location helps to improve the quality of
 * Geospatial localization and tracking accuracy.
 *
 * This launches an asynchronous operation used to query the Google Cloud ARCore API. This
 * function returns a `GARVPSAvailabilityFuture` which can be used to obtain the task's result.
 * Its initial `GARFutureState` will be set to `GARFutureStatePending`. When the operation
 * is completed, its `GARFutureState` will be set to `GARFutureStateDone`, and `GARVPSAvailabilityFuture.state`
 * can be used to obtain the operation's result.
 *
 * <p>You may provide an optional @p completionHandler, which will be invoked when the operation is
 * completed, unless the `GARVPSAvailabilityFuture` has been cancelled. The callback will be called on the
 * Main thread.
 *
 * <p>Your app must be properly set up to communicate with the Google Cloud ARCore API in order to
 * obtain a result from this call. See <a
 * href="https://developers.google.com/ar/develop/ios/geospatial/check-vps-availability">Check
 * VPS Availability</a> for more details on setup steps and usage examples.
 *
 * @param coordinate The coordinate at which to check availability.
 * @param completionHandler Completion handler to be invoked on the Main thread, if not nil.
 * @return A handler that can be polled or cancelled. If the operation is cancelled, no callback
 *     will be invoked.
 */
- (GARVPSAvailabilityFuture *)
    checkVPSAvailabilityAtCoordinate:(CLLocationCoordinate2D)coordinate
                   completionHandler:
                       (void (^_Nullable)(GARVPSAvailability availability))completionHandler
    NS_SWIFT_NAME(checkVPSAvailability(coordinate:completionHandler:));

@end

NS_ASSUME_NONNULL_END
