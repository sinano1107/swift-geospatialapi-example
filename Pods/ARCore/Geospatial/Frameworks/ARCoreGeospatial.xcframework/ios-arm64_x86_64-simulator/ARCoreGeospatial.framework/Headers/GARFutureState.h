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

/** The state of an async operation. */
typedef NS_ENUM(NSInteger, GARFutureState) {
  /**
   * The operation is still pending. It may still be possible to cancel the operation. The result
   * of the operation isn't available yet, and any registered callback hasn't yet been dispatched or
   * invoked.
   */
  GARFutureStatePending = 0,

  /** The operation has been cancelled. Any registered callback will never be invoked. */
  GARFutureStateCancelled = 1,

  /**
   * The operation is complete and the result is available. If a callback was registered, it will
   * soon be invoked with the result, if it hasn't been invoked already.
   */
  GARFutureStateDone = 2,
};
