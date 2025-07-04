import UIKit
import Messages

class MessagesViewController: MSMessagesAppViewController {
    var battleRoomManager: BattleRoomManager?
    var timerLabel: UILabel!
    var scoreLabel: UILabel!
    var feedbackLabel: UILabel!
    var inputField: UITextField!
    var submitButton: UIButton!
    var letterDisplayLabel: UILabel!
    var timerRingLayer: CAShapeLayer!
    var playerStackView: UIStackView!
    var plusOneLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("MessagesViewController viewDidLoad")
        GameManager.shared.setup(with: self)
        self.submitButton?.addTarget(GameManager.shared, action: #selector(GameManager.handleSubmitButtonTapped), for: .touchUpInside)
    }
    
    func clearModeSpecificUI() {
        GameManager.shared.clearUI(in: view)
    }
    
    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        print("willBecomeActive with conversation: \(conversation)")
        print("Local participant: \(conversation.localParticipantIdentifier)")
        print("Remote participants: \(conversation.remoteParticipantIdentifiers)")

        guard let selectedMessage = conversation.selectedMessage,
              let url = selectedMessage.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            print("No valid selected message or URL — assuming user is initiating game. Showing home screen.")
            GameManager.shared.showHomeScreen(in: view, target: self)
            return
        }

        print("Selected message: \(selectedMessage)")
        print("Message URL: \(url)")

        if components.queryItems?.contains(where: { $0.name == "mode" && $0.value == "battle" }) == true {
            battleRoomManager = BattleRoomManager(viewController: self)
            battleRoomManager?.joinRoom(from: url)
        } else if components.queryItems?.contains(where: { $0.name == "mode" && $0.value == "classic" }) == true {
            GameManager.shared.processIncomingMessage(components: components)
        } else {
            print("Unknown or missing mode — doing nothing.")
        }
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
        self.submitButton = elements.submitButton
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
