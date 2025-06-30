import UIKit

protocol GameMode: AnyObject {
    var viewController: MessagesViewController? { get set }
    func startGame()
    func stopGame()
    func handleSubmit(input: String)
    func updateUI()
}
