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
        
        // Delegate message handling to appropriate manager
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
    
    @objc private func startClassicMode() {
        GameManager.shared.startClassicMode()
    }
    
    @objc private func sendBattleInviteMessage() {
        guard let conversation = activeConversation else { return }
        battleRoomManager = BattleRoomManager(viewController: self)
        battleRoomManager?.sendInviteMessage(in: conversation)
    }
    
    func startBattleMode(with playerNames: [String]) {
        GameManager.shared.startBattleMode(with: playerNames)
    }
}
