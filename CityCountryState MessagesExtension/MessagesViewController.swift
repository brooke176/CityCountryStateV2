import UIKit
import Messages

class MessagesViewController: MSMessagesAppViewController {
    private var gameManager: GameManager?
    private var battleRoomManager: BattleRoomManager?
    var inputField: UITextField!
    var submitButton: UIButton!
    var timerLabel: UILabel!
    var scoreLabel: UILabel!
    var feedbackLabel: UILabel!
    var letterDisplayLabel: UILabel!
    var timerRingLayer: CAShapeLayer!
    var plusOneLabel: UILabel!
    var playerStackView: UIStackView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        GameManager.shared.setup(with: self)
        showHomeScreen()
    }
    
    func clearModeSpecificUI() {
        for subview in view.subviews {
            if subview != playerStackView {
                subview.removeFromSuperview()
            }
        }
        view.layer.sublayers?.removeAll(where: { $0 is CAShapeLayer })
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
            battleRoomManager?.joinRoom(from: conversation.selectedMessage?.url)
            return
        }
        
        GameManager.shared.handleIncomingMessage(opponentScore: <#T##Int#>: components)
    }
    
    func showHomeScreen() {
        GameUIHelper.buildHomeScreen(
            in: view,
            target: self,
            classicSelector: #selector(startClassicMode),
            battleSelector: #selector(sendBattleInviteMessage)
        )
    }
    
    @objc private func startClassicMode() {
        GameManager.shared.startClassicMode()
    }
    
    @objc private func sendBattleInviteMessage() {
        guard let conversation = activeConversation else { return }
        
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "mode", value: "battle"),
            URLQueryItem(name: "readyCount", value: "1"),
            URLQueryItem(name: "playerReady", value: "false")
        ]

        let layout = MSMessageTemplateLayout()
        layout.caption = "Join the Battle Waiting Room!"
        
        let message = MSMessage()
        message.layout = layout
        message.url = components.url
        
        conversation.insert(message, completionHandler: nil)
    }
    
    func startBattleMode(with playerNames: [String]) {
        GameManager.shared.startBattleMode(with: playerNames)
    }
}
