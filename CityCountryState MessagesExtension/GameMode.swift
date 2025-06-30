import UIKit
import Messages

protocol GameMode: AnyObject {
    var viewController: MessagesViewController? { get set }
    var currentLetter: String { get }
    var score: Int { get }
    
    func startGame()
    func stopGame()
    func handleSubmit(input: String)
    func updateUI()
    func handleIncomingMessage(components: URLComponents)
    func resetGame()
    
    // UI Components
    func setupUI()
    func showGameUI()
}
