//
//  ViewController.m
//  SwiftGeospatial
//
//  Created by 長政輝 on 2022/11/26.
//

#import "ViewController.h"

#import <ARKit/ARKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>
#import <ModelIO/ModelIO.h>
#import <SceneKit/ModelIO.h>
#import <SceneKit/SceneKit.h>
#import <UIKit/UIKit.h>

#include <simd/simd.h>

#import <ARCore/ARCore.h>

// 「十分な」精度のための閾値。これらはアプリケーションに応じて調整することができます。
// ここでは、状態の変化がちらつくのを避けるために、「低」と「高」の両方の値を使用します。
static const CLLocationAccuracy kHorizontalAccuracyLowThreshold = 10;
static const CLLocationAccuracy kHorizontalAccuracyHighThreshold = 20;
static const CLLocationDirectionAccuracy kHeadingAccuracyLowThreshold = 15;
static const CLLocationDirectionAccuracy kHeadingAccuracyHighThreshold = 25;

// 十分な精度が得られない場合、アプリが諦めるまでの時間。
static const NSTimeInterval kLocalizationFailureTime = 3 * 60.0;
// 地形アンカーを解決するメッセージが表示された後、時間が経過しました。
static const NSTimeInterval kDurationNoTerrainAnchorResult = 10;

// このサンプルでは最大5つのアンカーを同時に使用できますが、ARCoreは原則的に無制限にサポートします。
static const NSUInteger kMaxAnchors = 5;

static NSString *const kPretrackingMessage = @"アンカーを設定するデバイスのローカライズ。";
static NSString *const kLocalizationTip =
    @"身近な建物やお店、看板などにカメラを向けてみましょう。";
static NSString *const kLocalizationComplete = @"ローカライズ完了";
static NSString *const kLocalizationFailureMessage =
    @"ローカライズができない。\n一度アプリを終了し、再度アプリを起動してください。";
static NSString *const kGeospatialTransformFormat =
    @"LAT/LONG（緯度/経度）: %.6f°, %.6f°\n    ACCURACY（精度）: %.2fm\nALTITUDE（高度）: %.2fm\n    ACCURACY（精度）: %.2fm\n"
     "HEADING（方位）: %.1f°\n    ACCURACY（精度）: %.1f°";

static const CGFloat kFontSize = 14.0;

// アンカー座標は、セッション間で永続化されます。
static NSString *const kSavedAnchorsUserDefaultsKey = @"anchors";

// 機能を使用する前にプライバシーポリシーを表示する。
static NSString *const kPrivacyNoticeUserDefaultsKey = @"privacy_notice_acknowledged";

// プライバシー通知プロンプトのタイトル。
static NSString *const kPrivacyNoticeTitle = @"現実世界におけるAR";

// 個人情報保護に関する注意喚起の内容
static NSString *const kPrivacyNoticeText =
    @"このセッションを動かすために、Googleはあなたのカメラからのビジュアルデータを処理します。";

// プライバシーに関する内容を詳しく知るためのリンクです。
static NSString *const kPrivacyNoticeLearnMoreURL =
    @"https://developers.google.com/ar/data-privacy";

// 機能を使用する前に、VPSの可用性通知を表示します。
static NSString *const kVPSAvailabilityNoticeUserDefaultsKey = @"VPS_availability_notice_acknowledged";

// VPS可用性通知プロンプトのタイトル。
static NSString *const kVPSAvailabilityTitle = @"VPSはご利用いただけません";

// VPS可用性通知プロンプトの内容。
static NSString *const kVPSAvailabilityText =
    @"現在地はVPSの通信エリアではありません。VPSが利用できない場合、セッションはGPS信号のみを使用します。";

typedef NS_ENUM(NSInteger, LocalizationState) {
  LocalizationStatePretracking = 0,
  LocalizationStateLocalizing = 1,
  LocalizationStateLocalized = 2,
  LocalizationStateFailed = -1,
};

@interface ViewController () <ARSessionDelegate, ARSCNViewDelegate, CLLocationManagerDelegate>

/** 位置情報の許可要求と確認に使用される位置情報マネージャー。 */
@property(nonatomic) CLLocationManager *locationManager;

/** ARKit session. */
@property(nonatomic) ARSession *arSession;

/**
 * ARCoreセッション、地理空間ローカライズに使用。ロケーションパーミッションを取得後、作成される。
 */
@property(nonatomic) GARSession *garSession;

/** AR対応のカメラ映像や3Dコンテンツを表示するビューです。 */
@property(nonatomic, weak) ARSCNView *scnView;

/** マーカーをレンダリングするために使用される SceneKit のシーン。 */
@property(nonatomic) SCNScene *scene;

/** 画面上部に地球追跡の状態を表示するためのラベル。 */
@property(nonatomic, weak) UILabel *trackingLabel;

/** 画面下部のステータス表示に使用するラベル。 */
@property(nonatomic, weak) UILabel *statusLabel;

/** 画面をタップしてアンカーを作成するヒントを表示するためのラベルです。 */
@property(nonatomic, weak) UILabel *tapScreenLabel;

/** 新しい地理空間アンカーを配置するために使用するボタンです。 */
@property(nonatomic, weak) UIButton *addAnchorButton;

/** WGS84アンカーまたはTerrainアンカーを作成するためのUISwitch。 */
@property(nonatomic, weak) UISwitch *terrainAnchorSwitch;

/** terrainAnchorSwitchのラベルです。 */
@property(nonatomic, weak) UILabel *switchLabel;

/** 既存のアンカーをすべてクリアするためのボタンです。 */
@property(nonatomic, weak) UIButton *clearAllAnchorsButton;

/** 直近のGARFrame。 */
@property(nonatomic) GARFrame *garFrame;

/** アンカー ID を SceneKit ノードにマッピングするディクショナリ。 */
@property(nonatomic) NSMutableDictionary<NSUUID *, SCNNode *> *markerNodes;

/** ローカライズの試行を開始した最後の時間。失敗時のタイムアウトを実装するために使用します。 */
@property(nonatomic) NSDate *lastStartLocalizationDate;

/** 地形アンカーIDを解決し始めた時間に対応させた辞書。 */
@property(nonatomic) NSMutableDictionary<NSUUID *, NSDate *> *terrainAnchorIDToStartTime;

/** 次のフレーム更新時に削除する終了した地形アンカーIDのセット。 */
@property(nonatomic) NSMutableSet<NSUUID *> *anchorIDsToRemove;

/** 現在のローカライズの状態。 */
@property(nonatomic) LocalizationState localizationState;

/** 前回から保存したアンカーを復元したかどうか。 */
@property(nonatomic) BOOL restoredSavedAnchors;

/** 最後のアンカーが地形アンカーであるかどうか。 */
@property(nonatomic) BOOL islastClickedTerrainAnchorButton;

/** テレインアンカーモードであるかどうか。 */
@property(nonatomic) BOOL isTerrainAnchorMode;

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  self.markerNodes = [NSMutableDictionary dictionary];
  self.terrainAnchorIDToStartTime = [NSMutableDictionary dictionary];
  self.anchorIDsToRemove = [NSMutableSet set];

  ARSCNView *scnView = [[ARSCNView alloc] init];
  scnView = [[ARSCNView alloc] init];
  scnView.translatesAutoresizingMaskIntoConstraints = NO;
  scnView.automaticallyUpdatesLighting = YES;
  scnView.autoenablesDefaultLighting = YES;
  self.scnView = scnView;
  self.scene = self.scnView.scene;
  self.arSession = self.scnView.session;
  self.scnView.delegate = self;
  self.scnView.debugOptions = ARSCNDebugOptionShowFeaturePoints;

  [self.view addSubview:self.scnView];

  UIFont *font = [UIFont systemFontOfSize:kFontSize];
  UIFont *boldFont = [UIFont boldSystemFontOfSize:kFontSize];

  UILabel *trackingLabel = [[UILabel alloc] init];
  trackingLabel.translatesAutoresizingMaskIntoConstraints = NO;
  trackingLabel.font = font;
  trackingLabel.textColor = UIColor.whiteColor;
  trackingLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:.5];
  trackingLabel.numberOfLines = 6;
  self.trackingLabel = trackingLabel;
  [self.scnView addSubview:trackingLabel];

  UILabel *tapScreenLabel = [[UILabel alloc] init];
  tapScreenLabel.translatesAutoresizingMaskIntoConstraints = NO;
  tapScreenLabel.font = boldFont;
  tapScreenLabel.textColor = UIColor.whiteColor;
  tapScreenLabel.numberOfLines = 2;
  tapScreenLabel.textAlignment = NSTextAlignmentCenter;
  tapScreenLabel.text = @"画面をタップしてアンカーを作成";
  tapScreenLabel.hidden = YES;
  self.tapScreenLabel = tapScreenLabel;
  [self.scnView addSubview:tapScreenLabel];

  UILabel *statusLabel = [[UILabel alloc] init];
  statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
  statusLabel.font = font;
  statusLabel.textColor = UIColor.whiteColor;
  statusLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:.5];
  statusLabel.numberOfLines = 2;
  self.statusLabel = statusLabel;
  [self.scnView addSubview:statusLabel];

  UIButton *addAnchorButton = [UIButton buttonWithType:UIButtonTypeSystem];
  addAnchorButton.translatesAutoresizingMaskIntoConstraints = NO;
  [addAnchorButton setTitle:@"カメラアンカーを追加する" forState:UIControlStateNormal];
  addAnchorButton.titleLabel.font = boldFont;
  [addAnchorButton addTarget:self
                      action:@selector(addAnchorButtonPressed)
            forControlEvents:UIControlEventTouchUpInside];
  addAnchorButton.hidden = YES;
  self.addAnchorButton = addAnchorButton;
  [self.view addSubview:addAnchorButton];

  UISwitch *terrainAnchorSwitch = [[UISwitch alloc] init];
  terrainAnchorSwitch.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:terrainAnchorSwitch];
  self.terrainAnchorSwitch = terrainAnchorSwitch;

  UILabel *switchLabel = [[UILabel alloc] init];
  switchLabel.translatesAutoresizingMaskIntoConstraints = NO;
  switchLabel.font = boldFont;
  switchLabel.textColor = UIColor.whiteColor;
  switchLabel.numberOfLines = 1;
  self.switchLabel = switchLabel;
  [self.scnView addSubview:switchLabel];
  self.switchLabel.text = @"地形";

  UIButton *clearAllAnchorsButton = [UIButton buttonWithType:UIButtonTypeSystem];
  clearAllAnchorsButton.translatesAutoresizingMaskIntoConstraints = NO;
  [clearAllAnchorsButton setTitle:@"すべてのアンカーをクリアする" forState:UIControlStateNormal];
  clearAllAnchorsButton.titleLabel.font = boldFont;
  [clearAllAnchorsButton addTarget:self
                            action:@selector(clearAllAnchorsButtonPressed)
                  forControlEvents:UIControlEventTouchUpInside];
  clearAllAnchorsButton.hidden = YES;
  self.clearAllAnchorsButton = clearAllAnchorsButton;
  [self.view addSubview:clearAllAnchorsButton];

  [self.scnView.topAnchor constraintEqualToAnchor:self.view.topAnchor].active = YES;
  [self.scnView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;
  [self.scnView.leftAnchor constraintEqualToAnchor:self.view.leftAnchor].active = YES;
  [self.scnView.rightAnchor constraintEqualToAnchor:self.view.rightAnchor].active = YES;

  [trackingLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor].active =
      YES;
  [trackingLabel.leftAnchor constraintEqualToAnchor:self.view.leftAnchor].active = YES;
  [trackingLabel.rightAnchor constraintEqualToAnchor:self.view.rightAnchor].active = YES;
  [trackingLabel.heightAnchor constraintEqualToConstant:140].active = YES;

  [tapScreenLabel.bottomAnchor constraintEqualToAnchor:self.statusLabel.topAnchor].active = YES;
  [tapScreenLabel.leftAnchor constraintEqualToAnchor:self.view.leftAnchor].active = YES;
  [tapScreenLabel.rightAnchor constraintEqualToAnchor:self.view.rightAnchor].active = YES;
  [tapScreenLabel.heightAnchor constraintEqualToConstant:20].active = YES;

  [statusLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
      .active = YES;
  [statusLabel.leftAnchor constraintEqualToAnchor:self.view.leftAnchor].active = YES;
  [statusLabel.rightAnchor constraintEqualToAnchor:self.view.rightAnchor].active = YES;
  [statusLabel.heightAnchor constraintEqualToConstant:160].active = YES;

  [addAnchorButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
      .active = YES;
  [addAnchorButton.rightAnchor constraintEqualToAnchor:self.view.rightAnchor].active = YES;

  [terrainAnchorSwitch.topAnchor constraintEqualToAnchor:self.statusLabel.topAnchor].active = YES;
  [terrainAnchorSwitch.rightAnchor constraintEqualToAnchor:self.view.rightAnchor].active = YES;

  [switchLabel.topAnchor constraintEqualToAnchor:self.statusLabel.topAnchor].active = YES;
  [switchLabel.rightAnchor constraintEqualToAnchor:self.terrainAnchorSwitch.leftAnchor].active =
      YES;
  [switchLabel.heightAnchor constraintEqualToConstant:40].active = YES;

  [clearAllAnchorsButton.bottomAnchor
      constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
      .active = YES;
  [clearAllAnchorsButton.leftAnchor constraintEqualToAnchor:self.view.leftAnchor].active = YES;
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];

  BOOL privacyNoticeAcknowledged =
      [[NSUserDefaults standardUserDefaults] boolForKey:kPrivacyNoticeUserDefaultsKey];
  if (privacyNoticeAcknowledged) {
    [self setUpARSession];
    return;
  }

  UIAlertController *alertController =
      [UIAlertController alertControllerWithTitle:kPrivacyNoticeTitle
                                          message:kPrivacyNoticeText
                                   preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *getStartedAction = [UIAlertAction
      actionWithTitle:@"スタート"
                style:UIAlertActionStyleDefault
              handler:^(UIAlertAction *action) {
                [[NSUserDefaults standardUserDefaults] setBool:YES
                                                        forKey:kPrivacyNoticeUserDefaultsKey];
                [self setUpARSession];
              }];
  UIAlertAction *learnMoreAction = [UIAlertAction
      actionWithTitle:@"詳細はこちら"
                style:UIAlertActionStyleDefault
              handler:^(UIAlertAction *action) {
                [[UIApplication sharedApplication]
                              openURL:[NSURL URLWithString:kPrivacyNoticeLearnMoreURL]
                              options:@{}
                    completionHandler:nil];
              }];
  [alertController addAction:getStartedAction];
  [alertController addAction:learnMoreAction];
  [self presentViewController:alertController animated:NO completion:nil];
}

- (void)showVPSUnavailableNotice {
  UIAlertController *alertController =
      [UIAlertController alertControllerWithTitle:kVPSAvailabilityTitle
                                          message:kVPSAvailabilityText
                                   preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *continueAction = [UIAlertAction
      actionWithTitle:@"継続"
                style:UIAlertActionStyleDefault
              handler:^(UIAlertAction *action) {
              }];
  [alertController addAction:continueAction];
  [self presentViewController:alertController animated:NO completion:nil];
}

- (void)setUpARSession {
  ARWorldTrackingConfiguration *configuration = [[ARWorldTrackingConfiguration alloc] init];
  configuration.worldAlignment = ARWorldAlignmentGravity;
  // オプションです。地形アンカーを地面に設置する際の動的な位置合わせを支援します。
  configuration.planeDetection = ARPlaneDetectionHorizontal;
  self.arSession.delegate = self;
  // ARセッションを開始する - 初回はカメラの許可を求めるプロンプトが表示されます。
  [self.arSession runWithConfiguration:configuration];

  self.locationManager = [[CLLocationManager alloc] init];
  // これにより、メインスレッドで非同期に |locationManager:didChangeAuthorizationStatus:| または
  // |locationManagerDidChangeAuthorization:| (iOS バージョンによって異なる) が呼び出されます。
  // ロケーションパーミッションを取得したら、ARCoreのセッションを設定します。
  self.locationManager.delegate = self;
}

- (void)checkLocationPermission {
  CLAuthorizationStatus authorizationStatus;
  if (@available(iOS 14.0, *)) {
    authorizationStatus = self.locationManager.authorizationStatus;
  } else {
    authorizationStatus = [CLLocationManager authorizationStatus];
  }
  if (authorizationStatus == kCLAuthorizationStatusAuthorizedAlways ||
      authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse) {
    if (@available(iOS 14.0, *)) {
      if (self.locationManager.accuracyAuthorization != CLAccuracyAuthorizationFullAccuracy) {
        [self setErrorStatus:@"位置情報は完全な精度で許可されたものではありません。"];
        return;
      }
    }
    // VPSの可用性を確認するために、デバイスの位置をリクエストします。
    [self.locationManager requestLocation];
    [self setUpGARSession];
  } else if (authorizationStatus == kCLAuthorizationStatusNotDetermined) {
    // ARCoreのセッションを構成する前に、アプリが責任を持ってロケーションパーミッションを取得する必要があります。
    // ARCoreはロケーションパーミッションのシステムプロンプトを発生させません。
    [self.locationManager requestWhenInUseAuthorization];
  } else {
    [self setErrorStatus:@"位置情報の取得が拒否または制限されている。"];
  }
}

- (void)setErrorStatus:(NSString *)message {
  self.statusLabel.text = message;
  self.addAnchorButton.hidden = YES;
  self.tapScreenLabel.hidden = YES;
  self.clearAllAnchorsButton.hidden = YES;
}

- (SCNNode *)markerNodeIsTerrainAnchor:(BOOL)isTerrainAnchor {
  NSURL *objURL = [[NSBundle mainBundle] URLForResource:@"geospatial_marker" withExtension:@"obj"];
  MDLAsset *markerAsset = [[MDLAsset alloc] initWithURL:objURL];
  MDLMesh *markerObject = (MDLMesh *)[markerAsset objectAtIndex:0];
  MDLMaterial *material = [[MDLMaterial alloc] initWithName:@"baseMaterial"
                                         scatteringFunction:[[MDLScatteringFunction alloc] init]];
  NSURL *textureURL =
      isTerrainAnchor
          ? [[NSBundle mainBundle] URLForResource:@"spatial-marker-yellow" withExtension:@"png"]
          : [[NSBundle mainBundle] URLForResource:@"spatial-marker-baked" withExtension:@"png"];
  MDLMaterialProperty *materialPropetry =
      [[MDLMaterialProperty alloc] initWithName:@"texture"
                                       semantic:MDLMaterialSemanticBaseColor
                                            URL:textureURL];
  [material setProperty:materialPropetry];
  for (MDLSubmesh *submesh in markerObject.submeshes) {
    submesh.material = material;
  }
  return [SCNNode nodeWithMDLObject:markerObject];
}

- (void)setUpGARSession {
  if (self.garSession) {
    return;
  }

  NSError *error = nil;
  self.garSession = [GARSession sessionWithAPIKey:@"AIzaSyAuj570MWxvfjTNwAYvHFvIK_uF1ozfIhs"
                                 bundleIdentifier:nil
                                            error:&error];
  if (error) {
    [self setErrorStatus:[NSString
                             stringWithFormat:@"GARSessionの作成に失敗しました: %d", (int)error.code]];
    return;
  }

  self.localizationState = LocalizationStateFailed;

  if (![self.garSession isGeospatialModeSupported:GARGeospatialModeEnabled]) {
    [self setErrorStatus:@"GARGeospatialModeEnabled は、このデバイスではサポートされていません。"];
    return;
  }

  GARSessionConfiguration *configuration = [[GARSessionConfiguration alloc] init];
  configuration.geospatialMode = GARGeospatialModeEnabled;
  [self.garSession setConfiguration:configuration error:&error];
  if (error) {
    [self setErrorStatus:[NSString stringWithFormat:@"GARSessionの設定に失敗しました: %d",
                                                    (int)error.code]];
    return;
  }

  self.localizationState = LocalizationStatePretracking;
  self.lastStartLocalizationDate = [NSDate date];
}

- (void)checkVPSAvailabilityWithCoordinate:(CLLocationCoordinate2D)coordinate {
  [self.garSession checkVPSAvailabilityAtCoordinate:coordinate
                                  completionHandler:^(GARVPSAvailability availability) {
                                    if (availability != GARVPSAvailabilityAvailable) {
                                      [self showVPSUnavailableNotice];
                                    }
                                  }];
}

- (void)addSavedAnchors {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSArray<NSDictionary<NSString *, NSNumber *> *> *savedAnchors =
      [defaults arrayForKey:kSavedAnchorsUserDefaultsKey];
  for (NSDictionary<NSString *, NSNumber *> *savedAnchor in savedAnchors) {
    CLLocationDegrees latitude = savedAnchor[@"latitude"].doubleValue;
    CLLocationDegrees longitude = savedAnchor[@"longitude"].doubleValue;
    CLLocationDirection heading;
    simd_quatf eastUpSouthQTarget = simd_quaternion(0.f, 0.f, 0.f, 1.f);
    BOOL useHeading = [savedAnchor objectForKey:@"heading"];
    if (useHeading) {
      heading = savedAnchor[@"heading"].doubleValue;
    } else {
      eastUpSouthQTarget = simd_quaternion(
          (simd_float4){savedAnchor[@"x"].floatValue, savedAnchor[@"y"].floatValue,
                        savedAnchor[@"z"].floatValue, savedAnchor[@"w"].floatValue});
    }
    if ([savedAnchor objectForKey:@"altitude"]) {
      CLLocationDistance altitude = savedAnchor[@"altitude"].doubleValue;
      [self addAnchorWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude)
                           altitude:altitude
                            heading:heading
                 eastUpSouthQTarget:eastUpSouthQTarget
                         useHeading:useHeading
                         shouldSave:NO];
    } else {
      [self addTerrainAnchorWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude)
                                   heading:heading
                        eastUpSouthQTarget:eastUpSouthQTarget
                                useHeading:useHeading
                                shouldSave:NO];
    }
  }
}

- (void)updateLocalizationState {
  // 現在トラッキングを行っていない場合はnilとなる。
  GARGeospatialTransform *geospatialTransform = self.garFrame.earth.cameraGeospatialTransform;
  NSDate *now = [NSDate date];

  if (self.garFrame.earth.earthState != GAREarthStateEnabled) {
    self.localizationState = LocalizationStateFailed;
  } else if (self.garFrame.earth.trackingState != GARTrackingStateTracking) {
    self.localizationState = LocalizationStatePretracking;
  } else {
    if (self.localizationState == LocalizationStatePretracking) {
      self.localizationState = LocalizationStateLocalizing;
    } else if (self.localizationState == LocalizationStateLocalizing) {
      if (geospatialTransform != nil &&
          geospatialTransform.horizontalAccuracy <= kHorizontalAccuracyLowThreshold &&
          geospatialTransform.headingAccuracy <= kHeadingAccuracyLowThreshold) {
        self.localizationState = LocalizationStateLocalized;
        if (!self.restoredSavedAnchors) {
          [self addSavedAnchors];
          self.restoredSavedAnchors = YES;
        }
      } else if ([now timeIntervalSinceDate:self.lastStartLocalizationDate] >=
                 kLocalizationFailureTime) {
        self.localizationState = LocalizationStateFailed;
      }
    } else {
      // ローカライズされた状態から抜け出す際に高いしきい値を使用することで、状態変化のちらつきを回避する。
      if (geospatialTransform == nil ||
          geospatialTransform.horizontalAccuracy > kHorizontalAccuracyHighThreshold ||
          geospatialTransform.headingAccuracy > kHeadingAccuracyHighThreshold) {
        self.localizationState = LocalizationStateLocalizing;
        self.lastStartLocalizationDate = now;
      }
    }
  }
}

- (void)updateMarkerNodes {
  NSMutableSet<NSUUID *> *currentAnchorIDs = [NSMutableSet set];

  // トラッキングアンカー用のノードを追加・更新しました。
  for (GARAnchor *anchor in self.garFrame.anchors) {
    if (anchor.trackingState != GARTrackingStateTracking) {
      continue;
    }
    SCNNode *node = self.markerNodes[anchor.identifier];
    if (!node) {
      // 解決された地形アンカーと地理空間アンカーだけをレンダリングします。
      if (anchor.terrainState == GARTerrainAnchorStateSuccess) {
        node = [self markerNodeIsTerrainAnchor:YES];
      } else if (anchor.terrainState == GARTerrainAnchorStateNone) {
        node = [self markerNodeIsTerrainAnchor:NO];
      }
      self.markerNodes[anchor.identifier] = node;
      [self.scene.rootNode addChildNode:node];
    }
    node.simdTransform = anchor.transform;
    node.hidden = (self.localizationState != LocalizationStateLocalized);
    [currentAnchorIDs addObject:anchor.identifier];
  }

  // トラッキングが終了したアンカーのノードを削除します。
  for (NSUUID *anchorID in self.markerNodes.allKeys) {
    if (![currentAnchorIDs containsObject:anchorID]) {
      SCNNode *node = self.markerNodes[anchorID];
      [node removeFromParentNode];
      [self.markerNodes removeObjectForKey:anchorID];
    }
  }
}

- (NSString *)stringFromGAREarthState:(GAREarthState)earthState {
  switch (earthState) {
    case GAREarthStateErrorInternal:
      return @"ERROR_INTERNAL";
    case GAREarthStateErrorNotAuthorized:
      return @"ERROR_NOT_AUTHORIZED";
    case GAREarthStateErrorResourceExhausted:
      return @"ERROR_RESOURCE_EXHAUSTED";
    default:
      return @"ENABLED";
  }
}

- (void)updateTrackingLabel {
  if (self.localizationState == LocalizationStateFailed) {
    if (self.garFrame.earth.earthState != GAREarthStateEnabled) {
      NSString *earthState = [self stringFromGAREarthState:self.garFrame.earth.earthState];
      self.trackingLabel.text = [NSString stringWithFormat:@"Bad EarthState: %@", earthState];
    } else {
      self.trackingLabel.text = @"";
    }
    return;
  }

  if (self.garFrame.earth.trackingState == GARTrackingStatePaused) {
    self.trackingLabel.text = @"Not tracking.";
    return;
  }

  // 現在トラッキング中で、かつ良好なEarthStateであれば、これはゼロにはなりえません。
  GARGeospatialTransform *geospatialTransform = self.garFrame.earth.cameraGeospatialTransform;

  // CLLocationDirection 型で要求される [0, 360] の代わりに [-180, 180] (0=North) の範囲で方位を表示します。
  double heading = geospatialTransform.heading;
  if (heading > 180) {
    heading -= 360;
  }

  // 注意：ここでの高度値は、WGS84楕円体に対する相対値です（|CLLocation.ellipsoidalAltitude|に相当します）。
  self.trackingLabel.text = [NSString
      stringWithFormat:kGeospatialTransformFormat, geospatialTransform.coordinate.latitude,
                       geospatialTransform.coordinate.longitude,
                       geospatialTransform.horizontalAccuracy, geospatialTransform.altitude,
                       geospatialTransform.verticalAccuracy, heading,
                       geospatialTransform.headingAccuracy];
}

- (void)updateStatusLabelAndButtons {
  switch (self.localizationState) {
    case LocalizationStateLocalized: {
      [self.terrainAnchorIDToStartTime removeObjectsForKeys:[self.anchorIDsToRemove allObjects]];
      [self.anchorIDsToRemove removeAllObjects];
      NSString *message = nil;
      // 新しい地形アンカー状態がある場合、地形アンカー状態を表示する。
      for (GARAnchor *anchor in self.garFrame.anchors) {
        if (anchor.terrainState == GARTerrainAnchorStateNone) {
          continue;
        }

        if (self.terrainAnchorIDToStartTime[anchor.identifier] != nil) {
          message = [NSString stringWithFormat:@"Terrain Anchor State: %@",
                                               [self terrainStateString:anchor.terrainState]];

          NSDate *now = [NSDate date];
          if (anchor.terrainState == GARTerrainAnchorStateTaskInProgress) {
            if ([now timeIntervalSinceDate:self.terrainAnchorIDToStartTime[anchor.identifier]] >=
                kDurationNoTerrainAnchorResult) {
              message = @"地形アンカーはまだ解決していません。"
                        @"VPSが使える地域であることをご確認ください。";
              [self.anchorIDsToRemove addObject:anchor.identifier];
            }
          } else {
            // タスクが終了したら、削除してください。
            [self.anchorIDsToRemove addObject:anchor.identifier];
          }
        }
      }
      if (message != nil) {
        self.statusLabel.text = message;
      } else if (self.garFrame.anchors.count == 0) {
        self.statusLabel.text = kLocalizationComplete;
      } else if (!self.islastClickedTerrainAnchorButton) {
        self.statusLabel.text =
            [NSString stringWithFormat:@"Num anchors: %d", (int)self.garFrame.anchors.count];
      }
      self.clearAllAnchorsButton.hidden = (self.garFrame.anchors.count == 0);
      self.addAnchorButton.hidden = (self.garFrame.anchors.count >= kMaxAnchors);
      self.tapScreenLabel.hidden = (self.garFrame.anchors.count >= kMaxAnchors);
      break;
    }
    case LocalizationStatePretracking:
      self.statusLabel.text = kPretrackingMessage;
      break;
    case LocalizationStateLocalizing:
      self.statusLabel.text = kLocalizationTip;
      self.addAnchorButton.hidden = YES;
      self.tapScreenLabel.hidden = YES;
      self.clearAllAnchorsButton.hidden = YES;
      break;
    case LocalizationStateFailed:
      self.statusLabel.text = kLocalizationFailureMessage;
      self.addAnchorButton.hidden = YES;
      self.tapScreenLabel.hidden = YES;
      self.clearAllAnchorsButton.hidden = YES;
      break;
  }
  self.isTerrainAnchorMode = self.terrainAnchorSwitch.isOn;
}

- (NSString *)terrainStateString:(GARTerrainAnchorState)terrainAnchorState {
  switch (terrainAnchorState) {
    case GARTerrainAnchorStateNone:
      return @"None";
    case GARTerrainAnchorStateSuccess:
      return @"Success";
    case GARTerrainAnchorStateErrorInternal:
      return @"ErrorInternal";
    case GARTerrainAnchorStateTaskInProgress:
      return @"TaskInProgress";
    case GARTerrainAnchorStateErrorNotAuthorized:
      return @"ErrorNotAuthorized";
    case GARTerrainAnchorStateErrorUnsupportedLocation:
      return @"UnsupportedLocation";
    default:
      return @"Unknown";
  }
}

- (void)updateWithGARFrame:(GARFrame *)garFrame {
  self.garFrame = garFrame;
  [self updateLocalizationState];
  [self updateMarkerNodes];
  [self updateTrackingLabel];
  [self updateStatusLabelAndButtons];
}

- (void)addAnchorWithCoordinate:(CLLocationCoordinate2D)coordinate
                       altitude:(CLLocationDistance)altitude
                        heading:(CLLocationDirection)heading
             eastUpSouthQTarget:(simd_quatf)eastUpSouthQTarget
                     useHeading:(BOOL)useHeading
                     shouldSave:(BOOL)shouldSave {
  simd_quatf eastUpSouthQAnchor;
  if (useHeading) {
    // 3Dモデルの矢印はZ軸を指し、ヘディングは北から時計回りに計測されます。
    float angle = (M_PI / 180) * (180 - heading);
    eastUpSouthQAnchor = simd_quaternion(angle, simd_make_float3(0, 1, 0));
  } else {
    eastUpSouthQAnchor = eastUpSouthQTarget;
  }
  // |createAnchorWithCoordinate:altitude:eastUpSouthQAnchor:error:| の戻り値は、
  // アンカーの最初のスナップショット（これは不変です）だけです。
  // フレームごとに更新された値を取得するには、|GARFrame.anchors| で更新されたスナップショットを使用します。
  NSError *error = nil;
  [self.garSession createAnchorWithCoordinate:coordinate
                                     altitude:altitude
                           eastUpSouthQAnchor:eastUpSouthQAnchor
                                        error:&error];
  if (error) {
    NSLog(@"アンカー追加エラー: %@", error);
    return;
  }

  if (shouldSave) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray<NSDictionary<NSString *, NSNumber *> *> *savedAnchors =
        [defaults arrayForKey:kSavedAnchorsUserDefaultsKey] ?: @[];
    NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *newSavedAnchors =
        [savedAnchors mutableCopy];
    if (useHeading) {
      [newSavedAnchors addObject:@{
        @"latitude" : @(coordinate.latitude),
        @"longitude" : @(coordinate.longitude),
        @"altitude" : @(altitude),
        @"heading" : @(heading),
      }];
    } else {
      [newSavedAnchors addObject:@{
        @"latitude" : @(coordinate.latitude),
        @"longitude" : @(coordinate.longitude),
        @"altitude" : @(altitude),
        @"x" : @(eastUpSouthQTarget.vector[0]),
        @"y" : @(eastUpSouthQTarget.vector[1]),
        @"z" : @(eastUpSouthQTarget.vector[2]),
        @"w" : @(eastUpSouthQTarget.vector[3]),
      }];
    }
    [defaults setObject:newSavedAnchors forKey:kSavedAnchorsUserDefaultsKey];
  }
}

- (void)addTerrainAnchorWithCoordinate:(CLLocationCoordinate2D)coordinate
                               heading:(CLLocationDirection)heading
                    eastUpSouthQTarget:(simd_quatf)eastUpSouthQTarget
                            useHeading:(BOOL)useHeading
                            shouldSave:(BOOL)shouldSave {
  simd_quatf eastUpSouthQAnchor;
  if (useHeading) {
    // 3Dモデルの矢印はZ軸を指し、ヘディングは北から時計回りに計測されます。
    float angle = (M_PI / 180) * (180 - heading);
    eastUpSouthQAnchor = simd_quaternion(angle, simd_make_float3(0, 1, 0));
  } else {
    eastUpSouthQAnchor = eastUpSouthQTarget;
  }

  // |createAnchorWithCoordinate:altitude:eastUpSouthQAnchor:error:| の戻り値は、
  // アンカーの最初のスナップショット（これは不変です）だけです。
  // フレームごとに更新された値を取得するには、|GARFrame.anchors| で更新されたスナップショットを使用します。
  NSError *error = nil;
  GARAnchor *anchor = [self.garSession createAnchorWithCoordinate:coordinate
                                             altitudeAboveTerrain:0
                                               eastUpSouthQAnchor:eastUpSouthQAnchor
                                                            error:&error];
  if (error) {
    NSLog(@"アンカー追加エラー: %@", error);
    if (error.code == GARSessionErrorCodeResourceExhausted) {
      self.statusLabel.text =
          @"地形アンカーが多すぎるので、すでに保持されている。すべてのアンカーをクリアして、新しいアンカーを作成してください。";
    }
    return;
  }
  self.terrainAnchorIDToStartTime[anchor.identifier] = [NSDate date];
  if (shouldSave) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray<NSDictionary<NSString *, NSNumber *> *> *savedAnchors =
        [defaults arrayForKey:kSavedAnchorsUserDefaultsKey] ?: @[];
    NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *newSavedAnchors =
        [savedAnchors mutableCopy];
    if (useHeading) {
      [newSavedAnchors addObject:@{
        @"latitude" : @(coordinate.latitude),
        @"longitude" : @(coordinate.longitude),
        @"heading" : @(heading),
      }];
    } else {
      [newSavedAnchors addObject:@{
        @"latitude" : @(coordinate.latitude),
        @"longitude" : @(coordinate.longitude),
        @"x" : @(eastUpSouthQTarget.vector[0]),
        @"y" : @(eastUpSouthQTarget.vector[1]),
        @"z" : @(eastUpSouthQTarget.vector[2]),
        @"w" : @(eastUpSouthQTarget.vector[3]),
      }];
    }
    [defaults setObject:newSavedAnchors forKey:kSavedAnchorsUserDefaultsKey];
  }
}

- (void)addAnchorButtonPressed {
  // このボタンは、現在トラッキング中でなければ非表示になるので、nilにすることはできません。
  GARGeospatialTransform *geospatialTransform = self.garFrame.earth.cameraGeospatialTransform;
  if (self.isTerrainAnchorMode) {
    [self addTerrainAnchorWithCoordinate:geospatialTransform.coordinate
                                 heading:geospatialTransform.heading
                      eastUpSouthQTarget:simd_quaternion(0.f, 0.f, 0.f, 1.f)
                              useHeading:YES
                              shouldSave:YES];
  } else {
    [self addAnchorWithCoordinate:geospatialTransform.coordinate
                         altitude:geospatialTransform.altitude
                          heading:geospatialTransform.heading
               eastUpSouthQTarget:simd_quaternion(0.f, 0.f, 0.f, 1.f)
                       useHeading:YES
                       shouldSave:YES];
  }
  self.islastClickedTerrainAnchorButton = self.isTerrainAnchorMode;
}

- (void)clearAllAnchorsButtonPressed {
  for (GARAnchor *anchor in self.garFrame.anchors) {
    [self.garSession removeAnchor:anchor];
  }
  for (SCNNode *node in self.markerNodes.allValues) {
    [node removeFromParentNode];
  }
  [self.markerNodes removeAllObjects];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSavedAnchorsUserDefaultsKey];
  self.islastClickedTerrainAnchorButton = NO;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  if (touches.count < 1) {
    return;
  }
  if (self.garFrame.anchors.count >= kMaxAnchors) {
    return;
  }

  UITouch *touch = [[touches allObjects] firstObject];
  CGPoint touchLocation = [touch locationInView:self.scnView];
  NSArray<ARRaycastResult *> *rayCastResults = [self.arSession
      raycast:[self.scnView raycastQueryFromPoint:touchLocation
                                   allowingTarget:ARRaycastTargetExistingPlaneGeometry
                                        alignment:ARRaycastTargetAlignmentHorizontal]];

  if (rayCastResults.count > 0) {
    ARRaycastResult *result = rayCastResults.firstObject;
    NSError *error = nil;
    GARGeospatialTransform *geospatialTransform =
        [self.garSession geospatialTransformFromTransform:result.worldTransform error:&error];
    if (error) {
      NSLog(@"GARGeospatialTransform への変換トランスフォームの追加エラー: %@", error);
      return;
    }

    if (self.isTerrainAnchorMode) {
      [self addTerrainAnchorWithCoordinate:geospatialTransform.coordinate
                                   heading:0
                        eastUpSouthQTarget:geospatialTransform.eastUpSouthQTarget
                                useHeading:NO
                                shouldSave:YES];
    } else {
      [self addAnchorWithCoordinate:geospatialTransform.coordinate
                           altitude:geospatialTransform.altitude
                            heading:0
                 eastUpSouthQTarget:geospatialTransform.eastUpSouthQTarget
                         useHeading:NO
                         shouldSave:YES];
    }
    self.islastClickedTerrainAnchorButton = self.isTerrainAnchorMode;
  }
}

#pragma mark - CLLocationManagerDelegate

/** iOS < 14 用の認証コールバック。非推奨。ただし、デプロイメントターゲット >= 14.0 になるまでは必要。 */
- (void)locationManager:(CLLocationManager *)locationManager
    didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
  [self checkLocationPermission];
}

/** iOS 14の認証コールバック。 */
- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)locationManager
    API_AVAILABLE(ios(14.0)) {
  [self checkLocationPermission];
}

- (void)locationManager:(CLLocationManager *)locationManager
     didUpdateLocations:(NSArray<CLLocation *> *)locations {
  CLLocation *location = locations.lastObject;
  if (location) {
    [self checkVPSAvailabilityWithCoordinate:location.coordinate];
  }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
   NSLog(@"位置取得エラー: %@", error);
}

#pragma mark - ARSCNViewDelegate
- (nullable SCNNode *)renderer:(id<SCNSceneRenderer>)renderer nodeForAnchor:(ARAnchor *)anchor {
  return [[SCNNode alloc] init];
}

- (void)renderer:(id<SCNSceneRenderer>)renderer
      didAddNode:(SCNNode *)node
       forAnchor:(ARAnchor *)anchor {
  if ([anchor isKindOfClass:[ARPlaneAnchor class]]) {
    ARPlaneAnchor *planeAnchor = (ARPlaneAnchor *)anchor;

    CGFloat width = planeAnchor.extent.x;
    CGFloat height = planeAnchor.extent.z;
    SCNPlane *plane = [SCNPlane planeWithWidth:width height:height];

    plane.materials.firstObject.diffuse.contents = [UIColor colorWithRed:0.0f
                                                                   green:0.0f
                                                                    blue:1.0f
                                                                   alpha:0.7f];

    SCNNode *planeNode = [SCNNode nodeWithGeometry:plane];

    CGFloat x = planeAnchor.center.x;
    CGFloat y = planeAnchor.center.y;
    CGFloat z = planeAnchor.center.z;
    planeNode.position = SCNVector3Make(x, y, z);
    planeNode.eulerAngles = SCNVector3Make(-M_PI / 2, 0, 0);

    [node addChildNode:planeNode];
  }
}

- (void)renderer:(id<SCNSceneRenderer>)renderer
   didUpdateNode:(SCNNode *)node
       forAnchor:(ARAnchor *)anchor {
  if ([anchor isKindOfClass:[ARPlaneAnchor class]]) {
    ARPlaneAnchor *planeAnchor = (ARPlaneAnchor *)anchor;

    SCNNode *planeNode = node.childNodes.firstObject;
    NSAssert([planeNode.geometry isKindOfClass:[SCNPlane class]],
             @"planeNodeの子はSCNPlaneではありません"
             @"renderer:didAddNode:forAnchor:で何か問題があったのでしょうか？");
    SCNPlane *plane = (SCNPlane *)planeNode.geometry;

    CGFloat width = planeAnchor.extent.x;
    CGFloat height = planeAnchor.extent.z;
    plane.width = width;
    plane.height = height;

    CGFloat x = planeAnchor.center.x;
    CGFloat y = planeAnchor.center.y;
    CGFloat z = planeAnchor.center.z;
    planeNode.position = SCNVector3Make(x, y, z);
  }
}

- (void)renderer:(id<SCNSceneRenderer>)renderer
   didRemoveNode:(SCNNode *)node
       forAnchor:(ARAnchor *)anchor {
  if ([anchor isKindOfClass:[ARPlaneAnchor class]]) {
    SCNNode *planeNode = node.childNodes.firstObject;
    [planeNode removeFromParentNode];
  }
}

#pragma mark - ARSessionDelegate

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
  if (self.garSession == nil || self.localizationState == LocalizationStateFailed) {
    return;
  }
  GARFrame *garFrame = [self.garSession update:frame error:nil];
  [self updateWithGARFrame:garFrame];
}


@end
