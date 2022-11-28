//
//  ViewController.swift
//  SwiftGeospatial
//
//  Created by 長政輝 on 2022/11/27.
//

import UIKit
import ARKit

private let kFontSize = CGFloat(14.0)

// 機能を使用する前にプライバシーポリシーを表示する。
private let kPrivacyNoticeUserDefaultsKey = "privacy_notice_acknowledged"

// プライバシー通知プロンプトのタイトル。
private let kPrivacyNoticeTitle = "現実世界におけるAR"

// 個人情報保護に関する注意喚起の内容
private let kPrivacyNoticeText = "このセッションを動かすために、Googleはあなたのカメラからのビジュアルデータを処理します。"

// プライバシーに関する内容を詳しく知るためのリンクです。
private let kPrivacyNoticeLearnMoreURL = "https://developers.google.com/ar/data-privacy"

class SwiftViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, CLLocationManagerDelegate {
    /** 位置情報の許可要求と確認に使用される位置情報マネージャー。 */
    private var locationManager: CLLocationManager?
    
    /** ARKit session. */
    private var arSession: ARSession?
    
    /** AR対応のカメラ映像や3Dコンテンツを表示するビューです。 */
    private var scnView: ARSCNView?
    
    /** マーカーをレンダリングするために使用される SceneKit のシーン。 */
    private var scene: SCNScene?
    
    /** 画面上部に地球追跡の状態を表示するためのラベル。 */
    private var trackingLabel: UILabel?
    
    /** 画面下部のステータス表示に使用するラベル。 */
    private var statusLabel: UILabel?
    
    /** 画面をタップしてアンカーを作成するヒントを表示するためのラベルです。 */
    private var tapScreenLabel: UILabel?
    
    /** 新しい地理空間アンカーを配置するために使用するボタンです。 */
    private var addAnchorButton: UIButton?
    
    /** WGS84アンカーまたはTerrainアンカーを作成するためのUISwitch。 */
    private var terrainAnchorSwitch: UISwitch?
    
    /** terrainAnchorSwitchのラベルです。 */
    private var switchLabel: UILabel?
    
    /** 既存のアンカーをすべてクリアするためのボタンです。 */
    private var clearAllAnchorsButton: UIButton?
    
    /** アンカー ID を SceneKit ノードにマッピングするディクショナリ。 */
    private var markerNodes: [UUID : SCNNode]?
    
    /** 地形アンカーIDを解決し始めた時間に対応させた辞書。 */
    private var terrainAnchorIDToStartTime: [UUID : NSDate]?
    
    /** 次のフレーム更新時に削除する終了した地形アンカーIDのセット。 */
    private var anchorIDsToRemove: Set<UUID>?
    
    
    override func viewDidLoad() {
        print("Swift走ってます")
        super.viewDidLoad()
        
        markerNodes = [:]
        terrainAnchorIDToStartTime = [:]
        anchorIDsToRemove = []
        
        let scnView = ARSCNView()
        scnView.translatesAutoresizingMaskIntoConstraints = false
        scnView.automaticallyUpdatesLighting = true
        scnView.autoenablesDefaultLighting = true
        self.scnView = scnView
        scene = scnView.scene
        arSession = scnView.session
        scnView.delegate = self
        scnView.debugOptions = .showFeaturePoints
        
        view.addSubview(scnView)
        
        let font = UIFont.systemFont(ofSize: kFontSize)
        let boldFont = UIFont.boldSystemFont(ofSize: kFontSize)
        
        // trackingLabelを初期化
        let trackingLabel = UILabel()
        trackingLabel.translatesAutoresizingMaskIntoConstraints = false
        trackingLabel.font = font
        trackingLabel.textColor = UIColor.white
        trackingLabel.backgroundColor = UIColor(white: 0, alpha: 0.5)
        trackingLabel.numberOfLines = 6
        self.trackingLabel = trackingLabel
        self.scnView!.addSubview(trackingLabel)
        
        // tapScreenLabelを初期化
        let tapScreenLabel = UILabel()
        tapScreenLabel.translatesAutoresizingMaskIntoConstraints = false
        tapScreenLabel.font = boldFont
        tapScreenLabel.textColor = UIColor.white
        tapScreenLabel.numberOfLines = 2
        tapScreenLabel.textAlignment = NSTextAlignment.center
        tapScreenLabel.text = "画面をタップしてアンカーを作成"
        tapScreenLabel.isHidden = true
        self.tapScreenLabel = tapScreenLabel
        self.scnView!.addSubview(tapScreenLabel)
        
        // statusLabelを初期化
        let statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = font
        statusLabel.textColor = UIColor.white
        statusLabel.backgroundColor = UIColor(white: 0, alpha: 0.5)
        statusLabel.numberOfLines = 2
        self.statusLabel = statusLabel
        self.scnView!.addSubview(statusLabel)
        
        // addAnchorButtonを初期化
        let addAnchorButton = UIButton(type: .system)
        addAnchorButton.translatesAutoresizingMaskIntoConstraints = false
        addAnchorButton.setTitle("カメラアンカーを追加する", for: .normal)
        addAnchorButton.titleLabel?.font = boldFont
        addAnchorButton.addTarget(self, action: #selector(addAnchorButtonPressed), for: .touchUpInside)
        addAnchorButton.isHidden = true
        self.addAnchorButton = addAnchorButton
        self.view.addSubview(addAnchorButton)
        
        // terrainAnchorSwitchを初期化
        let terrainAnchorSwitch = UISwitch()
        terrainAnchorSwitch.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(terrainAnchorSwitch)
        self.terrainAnchorSwitch = terrainAnchorSwitch
        
        // switchLabelを初期化
        let switchLabel = UILabel()
        switchLabel.translatesAutoresizingMaskIntoConstraints = false
        switchLabel.font = boldFont
        switchLabel.textColor = UIColor.white
        switchLabel.numberOfLines = 1
        self.switchLabel = switchLabel
        self.scnView!.addSubview(switchLabel)
        self.switchLabel!.text = "地形"
        
        // clearAllAnchorsButtonを初期化
        let clearAllAnchorsButton = UIButton(type: .system)
        clearAllAnchorsButton.translatesAutoresizingMaskIntoConstraints = false
        clearAllAnchorsButton.setTitle("全てのアンカーをクリアする", for: .normal)
        clearAllAnchorsButton.titleLabel?.font = boldFont
        clearAllAnchorsButton.addTarget(self, action: #selector(clearAllAnchorsButtonPressed), for: .touchUpInside)
        clearAllAnchorsButton.isHidden = true
        self.clearAllAnchorsButton = clearAllAnchorsButton
        self.view.addSubview(clearAllAnchorsButton)
        
        // アンカーの設定
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
        tapScreenLabel.bottomAnchor.constraint(equalTo: self.statusLabel!.topAnchor).isActive = true
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
        let getStartedAction = UIAlertAction(title: "スタート", style: .default) { action in
            UserDefaults.standard.set(true, forKey: kPrivacyNoticeUserDefaultsKey)
            self.setUpARSession()
        }
        let learnMoreAction = UIAlertAction(title: "詳細はこちら", style: .default) { action in
            if let url = URL(string: kPrivacyNoticeLearnMoreURL) {
                UIApplication.shared.open(url)
            }
        }
        alertController.addAction(getStartedAction)
        alertController.addAction(learnMoreAction)
        present(alertController, animated: false)
    }
    
    func setUpARSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        // オプションです。地形アンカーを地面に設置する際の動的な位置合わせを支援します。
        configuration.planeDetection = .horizontal
        arSession?.delegate = self
        // ARセッションを開始する - 初回はカメラの許可を求めるプロンプトが表示されます。
        arSession?.run(configuration)
        
        locationManager = CLLocationManager()
        // これにより、メインスレッドで非同期に |locationManager:didChangeAuthorizationStatus:| または
        // |locationManagerDidChangeAuthorization:| (iOS バージョンによって異なる) が呼び出されます。
        // ロケーションパーミッションを取得したら、ARCoreのセッションを設定します。
        locationManager?.delegate = self
    }
    
    @objc
    func addAnchorButtonPressed() {
        print("アンカーを追加する")
    }
    
    @objc
    func clearAllAnchorsButtonPressed() {
        print("アンカーを全てクリアする")
    }
}
