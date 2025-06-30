import UIKit
import Messages

protocol GameMode: AnyObject {
    // Required properties
    weak var viewController: MessagesViewController? { get set }
    var currentLetter: String { get }
    var score: Int { get }
    
    // Game lifecycle methods
    func startGame()
    func stopGame()
    func resetGame()
    
    // Gameplay methods
    func handleSubmit(input: String)
    func handleIncomingMessage(components: URLComponents)
    
    // UI methods
    func updateUI()
    func showGameUI()
}
