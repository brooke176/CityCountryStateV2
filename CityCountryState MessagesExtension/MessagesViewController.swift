import UIKit
import Messages

class MessagesViewController: MSMessagesAppViewController {
    private var gameManager: GameManager?
    private var battleRoomManager: BattleRoomManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        GameManager.shared.setup(with: self)
        showHomeScreen()
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
            battleRoomManager?.joinRoom(from: conversation.selectedMessage?.url)
            return
        }
        
        if let opponentScore = components.queryItems?.first(where: { $0.name == "score" })?.value.flatMap(Int.init) {
            GameManager.shared.handleIncomingMessage(opponentScore: opponentScore, components: components)
        } else {
            GameManager.shared.handleIncomingMessage(components: components)
        }
    }
    
    func showHomeScreen() {
        gameManager?.showHomeScreen(in: view, target: self)
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
