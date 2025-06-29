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
        print("MessagesViewController viewDidLoad")
        
        // Initialize without message port for now
        GameManager.shared.setup(with: self)
        showHomeScreen()
        
        // Try to initialize message port in background
        DispatchQueue.global(qos: .background).async {
            do {
                try self.initializeMessagePort()
                print("Message port initialized successfully")
            } catch {
                print("Message port initialization failed: \(error)")
            }
        }
    }
    
    func clearModeSpecificUI() {
        gameManager?.clearUI(in: view)
    }
    
    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        print("willBecomeActive with conversation: \(conversation)")
        print("Local participant: \(conversation.localParticipantIdentifier)")
        print("Remote participants: \(conversation.remoteParticipantIdentifiers)")
        
        guard let selectedMessage = conversation.selectedMessage else {
            print("No selected message - showing home screen")
            showHomeScreen()
            return
        }
        
        print("Selected message: \(selectedMessage)")
        guard let url = selectedMessage.url else {
            print("Message has no URL - showing home screen")
            showHomeScreen()
            return
        }
        
        print("Message URL: \(url)")
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            print("Failed to parse URL components - showing home screen")
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
    
    private func initializeMessagePort() throws {
        // Skip message port initialization in simulator
        #if targetEnvironment(simulator)
        print("Skipping message port initialization in simulator")
        return
        #else
        // Use app group container for message port
        let appGroup = "group.com.yourdomain.CityCountryState"
        let portName = "\(appGroup).MessagesPort"
        
        print("Attempting to create message port with name: \(portName)")
        
        var context = CFMessagePortContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        var shouldFree = false
        guard let messagePort = CFMessagePortCreateLocal(
            nil,
            portName as CFString,
            { (port, messageId, data, info) -> Unmanaged<CFData>? in
                guard let info = info else { return nil }
                let viewController = Unmanaged<MessagesViewController>.fromOpaque(info).takeUnretainedValue()
                return viewController.handleMessage(messageId: messageId, data: data)
            },
            &context,
            &shouldFree
        ) else {
            throw NSError(domain: "com.yourdomain.CityCountryState", 
                         code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create message port"])
        }
        
        print("Message port created successfully")
        
        let runLoopSource = CFMessagePortCreateRunLoopSource(nil, messagePort, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        #endif
    }
    
    private func handleMessage(messageId: Int32, data: CFData?) -> Unmanaged<CFData>? {
        print("Received message with ID: \(messageId)")
        // Handle incoming messages here
        return nil
    }
    
    func startBattleMode(with playerNames: [String]) {
        GameManager.shared.startBattleMode(with: playerNames)
    }
}
