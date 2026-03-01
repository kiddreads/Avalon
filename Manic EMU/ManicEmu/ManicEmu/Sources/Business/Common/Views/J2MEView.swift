//
//  J2MEView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/2/28.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
import WebKit

/// Genesis/Sega CD/32X 6键手柄按钮映射
/// 这些值对应 KeyboardEvent.code 字符串，用于与 JGenesis 核心通信
enum J2MEButton: String, CaseIterable {
    // 方向键
    case up
    case down
    case left
    case right
    case fire
    
    // 数字键
    case num0
    case num1
    case num2
    case num3
    case num4
    case num5
    case num6
    case num7
    case num8
    case num9
    case star
    case pound
    
    // 功能键
    case softkeyLeft
    case softkeyRight
}

class J2MEView: BaseView {
    
    /// ROM路径
    var romPath: String? = nil
    private let serverType: LocalWebServer.ServerType
    
    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // 添加消息处理器
        let contentController = WKUserContentController()
        let proxy = WeakScriptMessageHandler(target: self)
        contentController.add(proxy, name: "console")
        configuration.userContentController = contentController
        
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.navigationDelegate = self
        view.uiDelegate = self
        view.allowsBackForwardNavigationGestures = false
        view.scrollView.isScrollEnabled = false
        
        let consoleHookJS = """
        (function () {
            function wrap(type) {
                const original = console[type];
                console[type] = function () {
                    window.webkit.messageHandlers.console.postMessage({
                        type: type,
                        message: Array.from(arguments).join(' ')
                    });
                    original.apply(console, arguments);
                };
            }

            ['log', 'warn', 'error', 'info', 'debug'].forEach(wrap);
        })();
        """
        let script = WKUserScript(
            source: consoleHookJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        view.configuration.userContentController.addUserScript(script)
        
        return view
    }()
    
    private lazy var localServer: LocalWebServer = {
        let server = LocalWebServer()
        try? server.start(serverType: serverType)
        return server
    }()
    
    deinit {
        Log.debug("\(String(describing: Self.self)) deinit")
        localServer.stop()
    }
    
    init(serverType: LocalWebServer.ServerType) {
        self.serverType = serverType
        super.init(frame: .zero)

        addSubview(webView)
        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        if let url = localServer.getURL() {
            webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - 公开接口
extension J2MEView {
    
    /// 运行Jar
    func openJar(filePath: String) {
        
    }
    
    /// 重置模拟器
    func reset() {
        
    }
    
    /// 保存 SRAM 存档到文件
    /// - Parameters:
    ///   - path: 保存路径
    ///   - completion: 完成回调
    func save(to path: String, completion: ((_ isSucess: Bool)->Void)? = nil) {
        
    }
    
    /// 从文件加载 SRAM 存档
    /// - Parameter path: 存档文件路径
    func loadSave(path: String) {
        
    }
    
    /// 设置纵横比
    func setAspect(width: Int, height: Int) {

    }
    
    // MARK: 输入控制
    /// - Parameters:
    ///   - button: 按钮
    ///   - pressed: true 表示按下，false 表示释放
    func pressButton(_ button: J2MEButton, pressed: Bool) {

    }
    
    /// 设置是否静音
    func setMute(_ mute: Bool) {
        
    }
    
    /// 获取截图
    /// - Note: 通过 WebView 截图获取当前画面
    func snapShot() -> UIImage? {
        // 使用 WebView 的截图能力
        let renderer = UIGraphicsImageRenderer(bounds: webView.bounds)
        let image = renderer.image { _ in
            webView.drawHierarchy(in: webView.bounds, afterScreenUpdates: true)
        }
        return image
    }
    
    /// 快进 - 设置模拟器运行速度
    /// - Parameter speed: 速度倍率 (1.0 = 正常速度, 2.0 = 2倍速, 等等)
    func fastForward(speed: Float) {
        
    }
    
    /// 暂停模拟器
    func pause() {

    }
    
    /// 恢复模拟器
    func resume() {

    }
    
}

// MARK: - WKScriptMessageHandler
extension J2MEView: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "console" {
            Log.debug("JS: \(message.body)")
        }
    }
}

// MARK: - WKNavigationDelegate
extension J2MEView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Log.debug("✅ WebView 加载完成")
    }
}

// MARK: - WKUIDelegate
extension J2MEView: WKUIDelegate {
    
}
