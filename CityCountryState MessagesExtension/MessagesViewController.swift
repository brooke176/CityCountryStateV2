import UIKit
import Messages

class MessagesViewController: MSMessagesAppViewController {
    var gameManager: GameManager?
    var battleRoomManager: BattleRoomManager?
    
    // UI Elements
    var timerLabel: UILabel!
    var scoreLabel: UILabel!
    var feedbackLabel: UILabel!
    var inputField: UITextField!
    var submitButton: UIButton!
    var letterDisplayLabel: UILabel!
    var timerRingLayer: CAShapeLayer!
    var playerStackView: UIStackView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize message port (not critical if it fails)
        try? initializeMessagePort()
        
        GameManager.shared.setup(with: self)
        showHomeScreen()
    }
    
    private func initializeMessagePort() throws {
        // Use app group container for message port
        let appGroup = "group.com.yourdomain.CityCountryState"
        let portName = "\(appGroup).MessagesPort"
        
        var context = CFMessagePortContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        guard let messagePort = CFMessagePortCreateLocal(
            nil,
            portName as CFString,
            { (port, messageId, data, info) -> Unmanaged<CFData>? in
                guard let info = info else { return nil }
                let viewController = Unmanaged<MessagesViewController>.fromOpaque(info).takeUnretainedValue()
                return viewController.handleMessage(messageId: messageId, data: data)
            },
            &context,
            nil
        ) else {
            print("Warning: Could not create message port - continuing without it")
            return
        }
        
        let runLoopSource = CFMessagePortCreateRunLoopSource(nil, messagePort, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    }
    
    private func handleMessage(messageId: Int32, data: CFData?) -> Unmanaged<CFData>? {
        // Handle incoming messages here
        return nil
    }
    
    func clearModeSpecificUI() {
        gameManager?.clearUI(in: view)
    }
    
    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        
        guard let url = conversation.selectedMessage?.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            showHomeScreen()
            return
        }
        
        if components.queryItems?.contains(where: { $0.name == "mode" && $0.value == "battle" }) == true {
            battleRoomManager = BattleRoomManager(viewController: self)
            battleRoomManager?.joinRoom(from: url)
        } else {
            GameManager.shared.handleIncomingMessage(components: components)
        }
    }
    
    func showHomeScreen() {
        gameManager?.showHomeScreen(in: view, target: self)
    }
    
    func configureUIElements(_ elements: (
        inputField: UITextField,
        submitButton: UIButton,
        timerLabel: UILabel,
        scoreLabel: UILabel,
        feedbackLabel: UILabel,
        letterDisplayLabel: UILabel,
        timerRingLayer: CAShapeLayer,
        plusOneLabel: UILabel
    )) {
        inputField = elements.inputField
        submitButton = elements.submitButton
        timerLabel = elements.timerLabel
        scoreLabel = elements.scoreLabel
        feedbackLabel = elements.feedbackLabel
        letterDisplayLabel = elements.letterDisplayLabel
        timerRingLayer = elements.timerRingLayer
    }
    
    @objc func startClassicMode() {
        GameManager.shared.startClassicMode()
    }
    
    @objc func sendBattleInviteMessage() {
        guard let conversation = activeConversation else { return }
        battleRoomManager = BattleRoomManager(viewController: self)
        battleRoomManager?.sendInviteMessage(in: conversation)
    }
    
    func startBattleMode(with playerNames: [String]) {
        GameManager.shared.startBattleMode(with: playerNames)
    }
}
