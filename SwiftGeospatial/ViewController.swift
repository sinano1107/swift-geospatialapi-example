//
//  ViewController.swift
//  SwiftGeospatial
//
//  Created by 長政輝 on 2022/11/27.
//

import UIKit
import ARKit
import ARCore
import SceneKit.ModelIO

// Thresholds for 'good enough' accuracy. These can be tuned for the application. We use both 'low'
// and 'high' values here to avoid flickering state changes.
// 「十分な」精度のための閾値。これらはアプリケーションに応じて調整することができます。
// ここでは、状態の変化がちらつくのを避けるために、「低」と「高」の両方の値を使用します。
private let kHorizontalAccuracyLowThreshold: Double = 10
private let kHorizontalAccuracyhighThreshold: Double = 20
private let kHeadingAccuracyLowThreshold: Double = 15
private let kHeadingAccuracyHighThreshold: Double = 25

// Time after which the app gives up if good enough accuracy is not achieved.
// 十分な精度が得られない場合、アプリが諦めるまでの時間。
private let kLocalizationFailureTime: TimeInterval = 3 * 60.0
// Time after showing resolving terrain anchors no result yet message.
// 地形アンカーを解決するメッセージが表示された後、時間が経過しました。
private let kDurationNoTerrainAnchorResult: TimeInterval = 10

// This sample allows up to 5 simultaneous anchors, although in principal ARCore supports an
// unlimited number.
// このサンプルでは最大5つのアンカーを同時に使用できますが、ARCoreは原則的に無制限にサポートします。
private let kMaxAnchors = 5

private let kPretrackingMessage = "Localizing your device to set anchor.\nアンカーを設定するデバイスのローカライズ。"
private let kLocalizationTip = "Point your camera at buildings, stores, and signs near you.\n身近な建物やお店、看板などにカメラを向けてみましょう。"
private let kLocalizationComplete = "Localization complete.\nローカライズ完了"
private let kLocalizationFailureMessage = "Localization not possible.\nClose and open the app to restart.\nローカライズができない。\n一度アプリを終了し、再度アプリを起動してください。"

private let kGeospatialTransformFormat =
"""
LAT/LONG（緯度/経度）: %.6f°, %.6f°\nACCURACY（精度）: %.2fm
ALTITUDE（高度）: %.2fm\n    ACCURACY（精度）: %.2fm
HEADING（方位）: %.1f°\n    ACCURACY（精度）: %.1f°
"""

private let kFontSize = CGFloat(14.0)

// Anchor coordinates are persisted between sessions.
// アンカー座標は、セッション間で永続化されます。
private let kSavedAnchorsUserDefaultsKey = "anchors"

// Show privacy notice before using features.
// 機能を使用する前にプライバシーポリシーを表示する。
private let kPrivacyNoticeUserDefaultsKey = "privacy_notice_acknowledged"

// Title of the privacy notice prompt.
// プライバシー通知プロンプトのタイトル。
private let kPrivacyNoticeTitle = "AR in the real world\n現実世界におけるAR"

// Content of the privacy notice prompt.
// 個人情報保護に関する注意喚起の内容
private let kPrivacyNoticeText =
"""
Your current location does not have VPS coverage. Your session will be using your GPS signal only if VPS is not available.
このセッションを動かすために、Googleはあなたのカメラからのビジュアルデータを処理します。
"""

// Link to learn more about the privacy content.
// プライバシーに関する内容を詳しく知るためのリンクです。
private let kPrivacyNoticeLearnMoreURL = "https://developers.google.com/ar/data-privacy"

// Title of the VPS availability notice prompt.
// VPS可用性通知プロンプトのタイトル。
private let kVPSAvailabilityTitle = "VPS not available\nVPSはご利用いただけません"

// Content of the VPS availability notice prompt.
// VPS可用性通知プロンプトの内容。
private let kVPSAvailabilityText = 
"""
Your current location does not have VPS coverage. Your session will be using your GPS signal only if VPS is not available.
現在地はVPSの通信エリアではありません。VPSが利用できない場合、セッションはGPS信号のみを使用します。
"""

enum LocalizationState : Int {
    case pretracking = 0
    case localizing = 1
    case localized = 2
    case failed = -1
}

class SwiftViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, CLLocationManagerDelegate {
    /**
     Location manager used to request and check for location permissions.
     位置情報の許可要求と確認に使用される位置情報マネージャー。
     */
    private var locationManager: CLLocationManager?
    
    /** ARKit session. */
    private var arSession: ARSession!
    
    /**
     ARCore session, used for geospatial localization. Created after obtaining location permission.
     ARCoreセッション、地理空間ローカライズに使用。ロケーションパーミッションを取得後、作成される。
     */
    private var garSession: GARSession!
    
    /**
     A view that shows an AR enabled camera feed and 3D content.
     AR対応のカメラ映像や3Dコンテンツを表示するビューです。
     */
    private var scnView: ARSCNView!
    
    /**
     SceneKit scene used for rendering markers.
     マーカーをレンダリングするために使用される SceneKit のシーン。
     */
    private var scene: SCNScene!
    
    /**
     Label used to show Earth tracking state at top of screen.
     画面上部に地球追跡の状態を表示するためのラベル。
     */
    private var trackingLabel: UILabel!
    
    /**
     Label used to show status at bottom of screen.
     画面下部のステータス表示に使用するラベル。
     */
    private var statusLabel: UILabel!
    
    /**
     Label used to show hint that tap screen to create anchors.
     画面をタップしてアンカーを作成するヒントを表示するためのラベルです。
     */
    private var tapScreenLabel: UILabel!
    
    /**Button used to place a new geospatial anchor.
     新しい地理空間アンカーを配置するために使用するボタンです。
     */
    private var addAnchorButton: UIButton!
    
    /**
     UISwitch for creating WGS84 anchor or Terrain anchor.
     WGS84アンカーまたはTerrainアンカーを作成するためのUISwitch。
     */
    private var terrainAnchorSwitch: UISwitch!
    
    /**
     Label of terrainAnchorSwitch.
     terrainAnchorSwitchのラベルです。
     */
    private var switchLabel: UILabel!
    
    /** Button used to clear all existing anchors.
     既存のアンカーをすべてクリアするためのボタンです。
     */
    private var clearAllAnchorsButton: UIButton!
    
    /**
     The most recent GARFrame.
     直近のGARFrame。
     */
    private var garFrame: GARFrame!
    
    /**
     Dictionary mapping anchor IDs to SceneKit nodes.
     アンカー ID を SceneKit ノードにマッピングするディクショナリ。
     */
    private var markerNodes: [UUID : SCNNode]!
    
    /**
     The last time we started attempting to localize. Used to implement failure timeout.
     ローカライズの試行を開始した最後の時間。失敗時のタイムアウトを実装するために使用します。
     */
    private var lastStartLocalizationDate: Date!
    
    /** Dictionary mapping terrain anchor IDs to time we started resolving.
     地形アンカーIDを解決し始めた時間に対応させた辞書。
     */
    private var terrainAnchorIDToStartTime: [UUID : Date]!
    
    /**
     Set of finished terrain anchor IDs to remove at next frame update.
     次のフレーム更新時に削除する終了した地形アンカーIDのセット。
     */
    private var anchorIDsToRemove: Set<UUID>!
    
    /**
     The current localization state.
     現在のローカライズの状態。
     */
    private var localizationState: LocalizationState!
    
    /**
     Whether we have restored anchors saved from the previous session.
     前回から保存したアンカーを復元したかどうか。
     */
    private var restoredSavedAnchors: Bool = false
    
    /**
     Whether the last anchor is terrain anchor.
     最後のアンカーが地形アンカーであるかどうか。
     */
    private var islastClickedTerrainAnchorButton: Bool = false
    
    /**
     Whether it is Terrain anchor mode.
     テレインアンカーモードであるかどうか。
     */
    private var isTerrainAnchorMode: Bool!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        markerNodes = [:]
        terrainAnchorIDToStartTime = [:]
        anchorIDsToRemove = []
        
        scnView = ARSCNView()
        scnView.translatesAutoresizingMaskIntoConstraints = false
        scnView.automaticallyUpdatesLighting = true
        scnView.autoenablesDefaultLighting = true
        scene = scnView.scene
        arSession = scnView.session
        scnView.delegate = self
        scnView.debugOptions = .showFeaturePoints
        
        view.addSubview(scnView)
        
        let font = UIFont.systemFont(ofSize: kFontSize)
        let boldFont = UIFont.boldSystemFont(ofSize: kFontSize)
        
        // trackingLabel
        trackingLabel = UILabel()
        trackingLabel.translatesAutoresizingMaskIntoConstraints = false
        trackingLabel.font = font
        trackingLabel.textColor = UIColor.white
        trackingLabel.backgroundColor = UIColor(white: 0, alpha: 0.5)
        trackingLabel.numberOfLines = 6
        scnView.addSubview(trackingLabel)
        
        // tapScreenLabel
        tapScreenLabel = UILabel()
        tapScreenLabel.translatesAutoresizingMaskIntoConstraints = false
        tapScreenLabel.font = boldFont
        tapScreenLabel.textColor = UIColor.white
        tapScreenLabel.numberOfLines = 2
        tapScreenLabel.textAlignment = NSTextAlignment.center
        tapScreenLabel.text = "画面をタップしてアンカーを作成"
        tapScreenLabel.isHidden = true
        scnView.addSubview(tapScreenLabel)
        
        // statusLabel
        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = font
        statusLabel.textColor = UIColor.white
        statusLabel.backgroundColor = UIColor(white: 0, alpha: 0.5)
        statusLabel.numberOfLines = 5
        scnView.addSubview(statusLabel)
        
        // addAnchorButton
        addAnchorButton = UIButton(type: .system)
        addAnchorButton.translatesAutoresizingMaskIntoConstraints = false
        addAnchorButton.setTitle("カメラアンカーを追加する", for: .normal)
        addAnchorButton.titleLabel?.font = boldFont
        addAnchorButton.addTarget(self, action: #selector(addAnchorButtonPressed), for: .touchUpInside)
        addAnchorButton.isHidden = true
        view.addSubview(addAnchorButton)
        
        // terrainAnchorSwitch
        terrainAnchorSwitch = UISwitch()
        terrainAnchorSwitch.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(terrainAnchorSwitch)
        
        // switchLabel
        switchLabel = UILabel()
        switchLabel.translatesAutoresizingMaskIntoConstraints = false
        switchLabel.font = boldFont
        switchLabel.textColor = UIColor.white
        switchLabel.numberOfLines = 1
        scnView.addSubview(switchLabel)
        switchLabel.text = "地形"
        
        // clearAllAnchorsButton
        clearAllAnchorsButton = UIButton(type: .system)
        clearAllAnchorsButton.translatesAutoresizingMaskIntoConstraints = false
        clearAllAnchorsButton.setTitle("全てのアンカーをクリアする", for: .normal)
        clearAllAnchorsButton.titleLabel?.font = boldFont
        clearAllAnchorsButton.addTarget(self, action: #selector(clearAllAnchorsButtonPressed), for: .touchUpInside)
        clearAllAnchorsButton.isHidden = true
        view.addSubview(clearAllAnchorsButton)
        
        // Anchors setting
        // scnView
        scnView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        scnView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        scnView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        scnView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        
        // trackingLabel
        trackingLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        trackingLabel.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        trackingLabel.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        trackingLabel.heightAnchor.constraint(equalToConstant: 140).isActive = true
        
        // tapScreenLabel
        tapScreenLabel.bottomAnchor.constraint(equalTo: statusLabel.topAnchor).isActive = true
        tapScreenLabel.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        tapScreenLabel.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        tapScreenLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        // statusLabel
        statusLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        statusLabel.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        statusLabel.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        statusLabel.heightAnchor.constraint(equalToConstant: 160).isActive = true
        
        // addAnchorButton
        addAnchorButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        addAnchorButton.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        
        // terrainAnchorSwitch
        terrainAnchorSwitch.topAnchor.constraint(equalTo: statusLabel.topAnchor).isActive = true
        terrainAnchorSwitch.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        
        // switchLabel
        switchLabel.topAnchor.constraint(equalTo: statusLabel.topAnchor).isActive = true
        switchLabel.rightAnchor.constraint(equalTo: terrainAnchorSwitch.leftAnchor).isActive = true
        switchLabel.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        // clearAllAnchorButton
        clearAllAnchorsButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        clearAllAnchorsButton.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let privacyNoticeAcknowledged = UserDefaults.standard.bool(forKey: kPrivacyNoticeUserDefaultsKey)
        if privacyNoticeAcknowledged {
            setUpARSession()
            return
        }
        
        let alertController = UIAlertController(title: kPrivacyNoticeTitle, message: kPrivacyNoticeText, preferredStyle: .alert)
        let getStartedAction = UIAlertAction(title: "Get started（スタート）", style: .default) { action in
            UserDefaults.standard.set(true, forKey: kPrivacyNoticeUserDefaultsKey)
            self.setUpARSession()
        }
        let learnMoreAction = UIAlertAction(title: "Learn more（詳細はこちら）", style: .default) { action in
            if let url = URL(string: kPrivacyNoticeLearnMoreURL) {
                UIApplication.shared.open(url)
            }
        }
        alertController.addAction(getStartedAction)
        alertController.addAction(learnMoreAction)
        present(alertController, animated: false)
    }
    
    func showVPSUnavailableNotice() {
        let alertController = UIAlertController(title: kVPSAvailabilityTitle, message: kVPSAvailabilityText, preferredStyle: .alert)
        let continueAction = UIAlertAction(title: "Continue（継続）", style: .default, handler: nil)
        alertController.addAction(continueAction)
        present(alertController, animated: false)
    }
    
    func setUpARSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        // Optional. It will help the dynamic alignment of terrain anchors on ground.
        // オプションです。地形アンカーを地面に設置する際の動的な位置合わせを支援します。
        configuration.planeDetection = .horizontal
        arSession?.delegate = self
        // Start AR session - this will prompt for camera permissions the first time.
        // ARセッションを開始する - 初回はカメラの許可を求めるプロンプトが表示されます。
        arSession?.run(configuration)
        
        locationManager = CLLocationManager()
        // This will cause either |locationManager:didChangeAuthorizationStatus:| or
        // |locationManagerDidChangeAuthorization:| (depending on iOS version) to be called asynchronously
        // on the main thread. After obtaining location permission, we will set up the ARCore session.
        // これにより、メインスレッドで非同期に |locationManager:didChangeAuthorizationStatus:| または
        // |locationManagerDidChangeAuthorization:| (iOS バージョンによって異なる) が呼び出されます。
        // ロケーションパーミッションを取得したら、ARCoreのセッションを設定します。
        locationManager?.delegate = self
    }
    
    func checkLocationPermission() {
        var authorizationStatus: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            authorizationStatus = CLAuthorizationStatus(rawValue: locationManager!.authorizationStatus.rawValue)!
        } else {
            authorizationStatus = CLLocationManager.authorizationStatus()
        }
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            if #available(iOS 14.0, *) {
                if locationManager?.accuracyAuthorization != .fullAccuracy {
                    setErrorStatus("Location permission not granted with full accuracy.（位置情報は完全な精度で許可されたものではありません。）")
                    return
                }
            }
            // Request device location for check VPS availability.
            // VPSの可用性を確認するために、デバイスの位置をリクエストします。
            locationManager!.requestLocation()
            setUpGARSession()
        } else if (authorizationStatus == .notDetermined) {
            // The app is responsible for obtaining the location permission prior to configuring the ARCore
            // session. ARCore will not cause the location permission system prompt.
            // ARCoreのセッションを構成する前に、アプリが責任を持ってロケーションパーミッションを取得する必要があります。
            // ARCoreはロケーションパーミッションのシステムプロンプトを発生させません。
            locationManager?.requestWhenInUseAuthorization()
        } else {
            setErrorStatus("Location permission denied or restricted.（位置情報の取得が拒否または制限されている。）")
        }
    }
    
    func setErrorStatus(_ message: String) {
        statusLabel.text = message
        addAnchorButton.isHidden = true
        tapScreenLabel.isHidden = true
        clearAllAnchorsButton.isHidden = true
    }
    
    func markerNodeIsTerrainAnchor(_ isTerrainAnchor: Bool) -> SCNNode {
        let objURL = Bundle.main.url(forResource: "geospatial_marker", withExtension: "obj")!
        let markerAsset = MDLAsset(url: objURL)
        let markerObject = markerAsset[0] as! MDLMesh
        let material = MDLMaterial(name: "baseMaterial", scatteringFunction: MDLScatteringFunction())
        let textureURL = isTerrainAnchor
            ? Bundle.main.url(forResource: "spatial-marker-yellow", withExtension: "png")
            : Bundle.main.url(forResource: "spatial-marker-baked", withExtension: "png")
        let materialProperty = MDLMaterialProperty(name: "texture", semantic: .baseColor, url: textureURL)
        material.setProperty(materialProperty)
        
        for submesh in markerObject.submeshes ?? [] {
            (submesh as! MDLSubmesh).material = material
        }
        return SCNNode(mdlObject: markerObject)
    }
    
    func setUpGARSession() {
        if (garSession != nil) {
            return
        }
        
        do {
            garSession = try GARSession(apiKey: "AIzaSyAuj570MWxvfjTNwAYvHFvIK_uF1ozfIhs", bundleIdentifier: nil)
        } catch let error {
            setErrorStatus("Failed to create GARSession（GARSessionの作成に失敗しました）: \(error)")
            return
        }
        
        localizationState = .failed
        
        if !(garSession.isGeospatialModeSupported(.enabled)) {
            setErrorStatus("GARGeospatialModeEnabled is not supported on this device.（GARGeospatialModeEnabled は、このデバイスではサポートされていません。）")
            return
        }
        
        let configuration = GARSessionConfiguration()
        configuration.geospatialMode = .enabled
        
        var error: NSError? = nil
        garSession!.setConfiguration(configuration, error: &error)
        if error != nil {
            setErrorStatus("ailed to configure GARSession（GARSessionの設定に失敗しました）: \(error!.code)")
            return
        }
        
        localizationState = .pretracking
        lastStartLocalizationDate = Date()
    }
    
    func checkVPSAvailability(withCoordinate coordinate: CLLocationCoordinate2D) {
        garSession?.checkVPSAvailability(coordinate: coordinate) { availability in
            if availability != GARVPSAvailability.available {
                self.showVPSUnavailableNotice()
            }
        }
    }
    
    func addSavedAnchors() {
        let defaults = UserDefaults.standard
        let savedAnchors: [[String : NSNumber]] = defaults.array(forKey: kSavedAnchorsUserDefaultsKey) as? [[String : NSNumber]] ?? []
        for savedAnchor in savedAnchors {
            let latitude = savedAnchor["latitude"]!.doubleValue
            let longitude = savedAnchor["longitude"]!.doubleValue
            var heading: CLLocationDirection = 0
            var eastUpSouthQTarget: simd_quatf = simd_quaternion(0.0, 0.0, 0.0, 1.0)
            let useHeading = savedAnchor["heading"] != nil
            if useHeading {
                heading = savedAnchor["heading"]!.doubleValue
            } else {
                eastUpSouthQTarget = simd_quaternion(
                    savedAnchor["x"]!.floatValue,
                    savedAnchor["y"]!.floatValue,
                    savedAnchor["z"]!.floatValue,
                    savedAnchor["w"]!.floatValue
                )
            }
            if (savedAnchor["altitude"] != nil) {
                let altitude = savedAnchor["altitude"]!.doubleValue
                addAnchorWithCoordinate(
                    CLLocationCoordinate2DMake(latitude, longitude),
                    altitude: altitude, heading: heading,
                    eastUpSouthQTarget:eastUpSouthQTarget,
                    useHeading: useHeading,
                    shouldSave: false
                )
            } else {
                addTerrainAnchorWithCoordinate(
                    CLLocationCoordinate2DMake(latitude, longitude),
                    heading: heading,
                    eastUpSouthQTarget: eastUpSouthQTarget,
                    useHeading: useHeading,
                    shouldSave: false
                )
            }
        }
    }
    
    func updateLocalizationState() {
        // This will be nil if not currently tracking.
        // 現在トラッキングを行なっていない場合はnilとなる。
        let geospatialTransform = garFrame.earth!.cameraGeospatialTransform
        let now = Date()
        
        if garFrame.earth?.earthState != .enabled {
            localizationState = .failed
        } else if garFrame.earth?.trackingState != .tracking {
            localizationState = .pretracking
        } else {
            if localizationState == .pretracking {
                localizationState = .localizing
            } else if localizationState == .localizing {
                if geospatialTransform != nil
                    && geospatialTransform!.horizontalAccuracy <= kHorizontalAccuracyLowThreshold
                    && geospatialTransform!.headingAccuracy <= kHeadingAccuracyLowThreshold {
                    localizationState = .localized
                    if !restoredSavedAnchors {
                        addSavedAnchors()
                        restoredSavedAnchors = true
                    }
                } else if now.timeIntervalSince(lastStartLocalizationDate) >= kLocalizationFailureTime {
                    localizationState = .failed
                }
            } else {
                // Use higher thresholds for exiting 'localized' state to avoid flickering state changes.
                // ローカライズされた状態から抜け出す際に高いしきい値を使用することで、状態変化のちらつきを回避する。
                if geospatialTransform == nil
                    || geospatialTransform!.horizontalAccuracy > kHorizontalAccuracyhighThreshold
                    || geospatialTransform!.headingAccuracy > kHeadingAccuracyHighThreshold {
                    localizationState = .localizing
                    lastStartLocalizationDate = now
                }
            }
        }
    }
    
    func updateMarkerNodes() {
        var currentAnchorIDs: Set<UUID> = []
        
        // Add/update nodes for tracking anchors.
        // トラッキングアンカー用のノードを追加・更新しました。
        for anchor in garFrame.anchors {
            if anchor.trackingState != .tracking {
                continue
            }
            var node = markerNodes[anchor.identifier]
            if node == nil {
                // Only render resolved Terrain Anchors and Geospatial anchors.
                // 解決された地形アンカーと地理空間アンカーだけをレンダリングします
                if anchor.terrainState == .success {
                    node = markerNodeIsTerrainAnchor(true)
                } else if anchor.terrainState == .none {
                    node = markerNodeIsTerrainAnchor(false)
                }
                markerNodes[anchor.identifier] = node
                scene.rootNode.addChildNode(node!)
            }
            guard let node = node else { return }
            node.simdTransform = anchor.transform
            node.isHidden = localizationState != .localized
            currentAnchorIDs.insert(anchor.identifier)
        }
        
        // Remove nodes for anchors that are no longer tracking.
        // トラッキングが終了したアンカーのノードを削除します。
        for anchorID in markerNodes.keys {
            if !currentAnchorIDs.contains(anchorID) {
                guard let node = markerNodes[anchorID] else { continue }
                node.removeFromParentNode()
                markerNodes.removeValue(forKey: anchorID)
            }
        }
    }
    
    func stringFromGAREarthState(_ earthState: GAREarthState) -> String {
        switch earthState {
        case .errorInternal:
            return "ERROR_INTERNAL"
        case.errorNotAuthorized:
            return "ERROR_NOT_AUTHORIZED"
        case .errorResourceExhausted:
            return "ERROR_RESOURCE_EXHAUSTED"
        default:
            return "ENABLED"
        }
    }
    
    func updateTrackingLabel() {
        guard let earth = garFrame.earth else { return }
        
        if localizationState == .failed {
            if earth.earthState != .enabled {
                let earthState = stringFromGAREarthState(earth.earthState)
                trackingLabel.text = "Bad EarthState: \(earthState)"
            } else {
                trackingLabel.text = ""
            }
            return
        }
        
        if earth.trackingState == .paused {
            trackingLabel.text = "Not racking."
            return
        }
        
        // This can't be nil if currently tracking and in a good EarthState.
        // 現在トラッキング中で、かつ良好なEarthStateであれば、これはゼロにはなりえません。
        guard let geospatialTransform = earth.cameraGeospatialTransform else { return }
        
        // Display heading in range [-180, 180], with 0=North, instead of [0, 360), as required by the
        // type CLLocationDirection.
        // CLLocationDirection 型で要求される [0, 360] の代わりに [-180, 180] (0=North) の範囲で方位を表示します。
        var heading = geospatialTransform.heading
        if heading > 180 {
            heading -= 360
        }
        
        // Note: the altitude value here is relative to the WGS84 ellipsoid (equivalent to
        // |CLLocation.ellipsoidalAltitude|).
        // 注意：ここでの高度値は、WGS84楕円体に対する相対値です（|CLLocation.ellipsoidalAltitude|に相当します）。
        trackingLabel?.text = String(
            format: kGeospatialTransformFormat,
            geospatialTransform.coordinate.latitude,
            geospatialTransform.coordinate.longitude,
            geospatialTransform.horizontalAccuracy,
            geospatialTransform.altitude,
            geospatialTransform.verticalAccuracy,
            heading,
            geospatialTransform.headingAccuracy
        )
    }
    
    func updateStatusLabelAndButtons() {
        switch localizationState {
        case .localized:
            for id in Array(anchorIDsToRemove) {
                terrainAnchorIDToStartTime.removeValue(forKey: id)
            }
            anchorIDsToRemove.removeAll()
            var message: String?
            // If there is a new terrain anchor state, show terrain anchor state.
            // 新しい地形アンカー状態がある場合、地形アンカー状態を表示する。
            for anchor in garFrame.anchors {
                if anchor.terrainState == .none {
                    continue
                }
                
                if terrainAnchorIDToStartTime[anchor.identifier] != nil {
                    message = "Terrain Anchor State: \(terrainStateString(anchor.terrainState))"
                    
                    let now = Date()
                    if anchor.terrainState == .taskInProgress {
                        if now.timeIntervalSince(terrainAnchorIDToStartTime[anchor.identifier]!) >= kDurationNoTerrainAnchorResult {
                            message =
                            """
Still resolving the terrain anchor. Please make sure you\'re in an area that has VPS coverage.
地形アンカーはまだ解決していません。
VPSが使える地域であることをご確認ください。
"""
                            anchorIDsToRemove.insert(anchor.identifier)
                        }
                    } else {
                        // Remove it if task has finished.
                        // タスクが完了したら、削除してください。
                        anchorIDsToRemove.insert(anchor.identifier)
                    }
                }
            }
            if message != nil {
                statusLabel.text = message
            } else if garFrame.anchors.count == 0 {
                statusLabel.text = kLocalizationComplete
            } else if !islastClickedTerrainAnchorButton {
                statusLabel.text = "Num anchors: \(garFrame.anchors.count)"
            }
            clearAllAnchorsButton.isHidden = garFrame.anchors.count == 0
            addAnchorButton.isHidden = garFrame.anchors.count >= kMaxAnchors
            break
        case .pretracking:
            statusLabel.text = kPretrackingMessage
            break
        case .localizing:
            statusLabel.text = kLocalizationTip
            addAnchorButton.isHidden = true
            tapScreenLabel.isHidden = true
            clearAllAnchorsButton.isHidden = true
            break
        case .failed:
            statusLabel.text = kLocalizationFailureMessage
            addAnchorButton.isHidden = true
            tapScreenLabel.isHidden = true
            clearAllAnchorsButton.isHidden = true
            break
        case .none:
            print("none")
        }
        isTerrainAnchorMode = terrainAnchorSwitch.isOn
    }
    
    func terrainStateString(_ terrainAnchorState: GARTerrainAnchorState) -> String {
        switch terrainAnchorState {
        case .none:
            return "None"
        case .success:
            return "Success"
        case .errorInternal:
            return "ErrorInternal"
        case .taskInProgress:
            return "TaskInProgress"
        case .errorNotAuthorized:
            return "ErrorNotAuthorized"
        case .errorUnsupportedLocation:
            return "UnsupportedLocation"
        default:
            return "Unknown"
        }
    }
    
    func updateWithGARFrame(_ garFrame: GARFrame) {
        self.garFrame = garFrame
        updateLocalizationState()
        updateMarkerNodes()
        updateTrackingLabel()
        updateStatusLabelAndButtons()
    }
    
    func addAnchorWithCoordinate(
        _ coordinate: CLLocationCoordinate2D,
        altitude: CLLocationDistance,
        heading: CLLocationDirection,
        eastUpSouthQTarget: simd_quatf,
        useHeading: Bool,
        shouldSave: Bool
    ) {
        var eastUpSouthQAnchor: simd_quatf?
        if useHeading {
            // The arrow of the 3D model points towards the Z-axis, while heading is measured clockwise from
                // North.
            // 3Dモデルの矢印はZ軸を指し、ヘディングは北から時計回りに計測されます。
            let angle = Float((.pi / 180) * (180 - heading))
            eastUpSouthQAnchor = simd_quaternion(angle, 0, 1, 0)
        } else {
            eastUpSouthQAnchor = eastUpSouthQTarget
        }
        // The return value of |createAnchorWithCoordinate:altitude:eastUpSouthQAnchor:error:| is just the
        // first snapshot of the anchor (which is immutable). Use the updated snapshots in
        // |GARFrame.anchors| to get updated values on a frame-by-frame basis.
        // |createAnchorWithCoordinate:altitude:eastUpSouthQAnchor:error:| の戻り値は、
        // アンカーの最初のスナップショット（これは不変です）だけです。
        // フレームごとに更新された値を取得するには、|GARFrame.anchors| で更新されたスナップショットを使用します。
        do {
            try garSession.createAnchor(
                coordinate: coordinate,
                altitude: altitude,
                eastUpSouthQAnchor: eastUpSouthQAnchor!
            )
        } catch let error {
            print("Error adding anchor（アンカー追加エラー）: \(error)")
            return
        }
        
        if shouldSave {
            let defaults = UserDefaults.standard
            let savedAnchors: [[String : NSNumber]] = defaults.array(forKey: kSavedAnchorsUserDefaultsKey) as? [[String : NSNumber]] ?? []
            var newSavedAnchors = savedAnchors
            if useHeading {
                newSavedAnchors.append([
                    "latitude": NSNumber(value: coordinate.latitude),
                    "longitude": NSNumber(value: coordinate.longitude),
                    "altitude": NSNumber(value: altitude),
                    "heading": NSNumber(value: heading)
                ])
            } else {
                newSavedAnchors.append([
                    "latitude": NSNumber(value: coordinate.latitude),
                    "longitude": NSNumber(value: coordinate.longitude),
                    "altitude": NSNumber(value: altitude),
                    "x": NSNumber(value: eastUpSouthQTarget.vector[0]),
                    "y": NSNumber(value: eastUpSouthQTarget.vector[1]),
                    "z": NSNumber(value: eastUpSouthQTarget.vector[2]),
                    "w": NSNumber(value: eastUpSouthQTarget.vector[3]),
                ])
            }
            defaults.set(newSavedAnchors, forKey: kSavedAnchorsUserDefaultsKey)
        }
    }
    
    func addTerrainAnchorWithCoordinate(
        _ coordinate: CLLocationCoordinate2D,
        heading: CLLocationDirection,
        eastUpSouthQTarget: simd_quatf,
        useHeading: Bool,
        shouldSave: Bool
    ) {
        var eastUpSouthQAnchor: simd_quatf?
        if useHeading {
            // The arrow of the 3D model points towards the Z-axis, while heading is measured clockwise from
            // North.
            // 3Dモデルの矢印はZ軸を指し、ヘディングは北から時計回りに計測されます。
            let angle = Float((.pi / 180) * (180 - heading))
            eastUpSouthQAnchor = simd_quaternion(angle, 0, 1, 0)
        } else {
            eastUpSouthQAnchor = eastUpSouthQTarget
        }
        
        do {
            // The return value of |createAnchorWithCoordinate:altitude:eastUpSouthQAnchor:error:| is just the
            // first snapshot of the anchor (which is immutable). Use the updated snapshots in
            // |GARFrame.anchors| to get updated values on a frame-by-frame basis.
            // |createAnchorWithCoordinate:altitude:eastUpSouthQAnchor:error:| の戻り値は、
            // アンカーの最初のスナップショット（これは不変です）だけです。
            // フレームごとに更新された値を取得するには、|GARFrame.anchors| で更新されたスナップショットを使用します。
            let anchor = try garSession.createAnchorOnTerrain(
                coordinate: coordinate,
                altitudeAboveTerrain: 0,
                eastUpSouthQAnchor: eastUpSouthQAnchor!
            )
            terrainAnchorIDToStartTime[anchor.identifier] = Date()
        } catch GARSessionError.resourceExhausted {
            statusLabel.text =
"""
Too many terrain anchors have already been held. Clear all anchors to create new ones.
地形アンカーが多すぎるので、すでに保持されている。すべてのアンカーをクリアして、新しいアンカーを作成してください。
"""
            return
        } catch let error {
            print("Error adding anchor（追加エラー）: \(error)")
            return
        }
        
        if shouldSave {
            let defaults = UserDefaults.standard
            let savedAnchors = (defaults.array(forKey: kSavedAnchorsUserDefaultsKey) ?? []) as! [[String : NSNumber]]
            var newSavedAnchors = savedAnchors
            if useHeading {
                newSavedAnchors.append([
                    "latitude": NSNumber(value: coordinate.latitude),
                    "longitude": NSNumber(value: coordinate.longitude),
                    "heading": NSNumber(value: heading)
                ])
            } else {
                newSavedAnchors.append([
                    "latitude": NSNumber(value: coordinate.latitude),
                    "longitude": NSNumber(value: coordinate.longitude),
                    "x": NSNumber(value: eastUpSouthQTarget.vector[0]),
                    "y": NSNumber(value: eastUpSouthQTarget.vector[1]),
                    "z": NSNumber(value: eastUpSouthQTarget.vector[2]),
                    "w": NSNumber(value: eastUpSouthQTarget.vector[3]),
                ])
            }
            defaults.set(newSavedAnchors, forKey: kSavedAnchorsUserDefaultsKey)
        }
    }
    
    @objc
    func addAnchorButtonPressed() {
        // This button will be hidden if not currently tracking, so this can't be nil.
        // このボタンは、現在トラッキング中でなければ非表示になるので、nilにすることはできません。
        guard let geospatialTransform = garFrame.earth?.cameraGeospatialTransform else { return }
        if isTerrainAnchorMode {
            addTerrainAnchorWithCoordinate(geospatialTransform.coordinate,
                                           heading: geospatialTransform.heading,
                                           eastUpSouthQTarget: simd_quaternion(0, 0, 0, 1),
                                           useHeading: true,
                                           shouldSave: true)
        } else {
            addAnchorWithCoordinate(geospatialTransform.coordinate,
                                    altitude: geospatialTransform.altitude,
                                    heading: geospatialTransform.heading,
                                    eastUpSouthQTarget: simd_quaternion(0, 0, 0, 1),
                                    useHeading: true,
                                    shouldSave: true)
        }
        islastClickedTerrainAnchorButton = isTerrainAnchorMode
    }
    
    @objc
    func clearAllAnchorsButtonPressed() {
        for anchor in garFrame.anchors {
            garSession.remove(anchor)
        }
        for node in markerNodes.values {
            node.removeFromParentNode()
        }
        markerNodes.removeAll()
        UserDefaults.standard.removeObject(forKey: kSavedAnchorsUserDefaultsKey)
        islastClickedTerrainAnchorButton = false
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.count < 1 {
            return
        }
        guard touches.count >= 1 else { return }
        guard let count = garFrame?.anchors.count, count < kMaxAnchors else { return }
        guard localizationState == .localized else { return }
        
        guard let touch = touches.first else { return }
        let touchLocation = touch.location(in: scnView)
        guard let rayCastQuery = scnView.raycastQuery(from: touchLocation, allowing: .existingPlaneGeometry, alignment: .horizontal) else { return }
        let rayCastResults = arSession.raycast(rayCastQuery)
        
        if rayCastResults.count > 0 {
            guard let result = rayCastResults.first else { return }

            var geospatialTransform: GARGeospatialTransform?
            do {
                geospatialTransform = try garSession.geospatialTransform(transform: result.worldTransform)
            } catch let error {
                print("Error adding convert transform to GARGeospatialTransform（GARGeospatialTransform への変換トランスフォームの追加エラー）: \(error)")
                return
            }
            
            guard let geospatialTransform = geospatialTransform else { return }
            if isTerrainAnchorMode {
                addTerrainAnchorWithCoordinate(geospatialTransform.coordinate,
                                               heading: 0,
                                               eastUpSouthQTarget: geospatialTransform.eastUpSouthQTarget,
                                               useHeading: false,
                                               shouldSave: true)
            } else {
                addAnchorWithCoordinate(geospatialTransform.coordinate,
                                        altitude: geospatialTransform.altitude,
                                        heading: 0,
                                        eastUpSouthQTarget: geospatialTransform.eastUpSouthQTarget,
                                        useHeading: false,
                                        shouldSave: true)
            }
            islastClickedTerrainAnchorButton = isTerrainAnchorMode
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    /**
     Authorization callback for iOS < 14. Deprecated, but needed until deployment target >= 14.0.
     iOS < 14 用の認証コールバック。非推奨。ただし、デプロイメントターゲット >= 14.0 になるまでは必要。
     */
    func locationManager(locationManager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        checkLocationPermission()
    }
    
    /**
     Authorization callback for iOS 14.
     iOS 14の認証コールバック。
     */
    @available(iOS 14.0, *)
    func locationManagerDidChangeAuthorization(_ locationManager: CLLocationManager) {
        checkLocationPermission()
    }
    
    func locationManager(_ locationManager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            checkVPSAvailability(withCoordinate: location.coordinate)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error get location（位置取得エラー）: \(error)")
    }
    
    // MARK: - ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        return SCNNode()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if anchor is ARPlaneAnchor {
            let planeAnchor = anchor as! ARPlaneAnchor
            
            let width = planeAnchor.planeExtent.width
            let height = planeAnchor.planeExtent.height
            let plane = SCNPlane(width: CGFloat(width), height: CGFloat(height))
            
            plane.materials.first?.diffuse.contents = UIColor(red: 0, green: 0, blue: 1, alpha: 0.7)
            
            let planeNode = SCNNode(geometry: plane)
            
            let x = planeAnchor.center.x
            let y = planeAnchor.center.y
            let z = planeAnchor.center.z
            planeNode.position = SCNVector3Make(x, y, z)
            planeNode.eulerAngles = SCNVector3Make(-.pi / 2, 0, 0)
            
            node.addChildNode(planeNode)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if anchor is ARPlaneAnchor {
            let planeAnchor = anchor as! ARPlaneAnchor
            
            let planeNode = node.childNodes.first!
            assert(planeNode.geometry is SCNPlane,
"""
planeNode's child is not an SCNPlane--did something go wrong in renderer:didAddNode:forAnchor:?
（planeNodeの子はSCNPlaneではありません。renderer:didAddNode:forAnchor:で何か問題があったのでしょうか？）
""")
            let plane = planeNode.geometry as! SCNPlane
            
            let width = planeAnchor.planeExtent.width
            let height = planeAnchor.planeExtent.height
            plane.width = CGFloat(width)
            plane.height = CGFloat(height)
            
            let x = planeAnchor.center.x
            let y = planeAnchor.center.y
            let z = planeAnchor.center.z
            planeNode.position = SCNVector3Make(x, y, z)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        if anchor is ARPlaneAnchor {
            let planeNode = node.childNodes.first!
            planeNode.removeFromParentNode()
        }
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if garSession == nil || localizationState == .failed {
            return
        }
        let garFrame = try! garSession.update(frame)
        updateWithGARFrame(garFrame)
    }
}
