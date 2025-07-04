import UIKit
import Messages

private weak var currentMode: GameMode?

class GameManager: NSObject, UITextFieldDelegate {
    static let shared = GameManager()
    var usedWords = Set<String>()
    weak var viewController: MessagesViewController?
    private let timeLimit: TimeInterval = 30
    private var timer: Timer?
    
    private override init() {
        super.init()
        GameData.loadData()
    }
    
    func setup(with viewController: MessagesViewController) {
        print("GameManager setup with viewController")
        self.viewController = viewController
        resetGame()
    }
    
    func clearUI(in view: UIView) {
        view.subviews.forEach { $0.removeFromSuperview() }
        view.layer.sublayers?.removeAll(where: { $0 is CAShapeLayer })
    }
    
    func showHomeScreen(in view: UIView, target: Any) {
        print("Showing home screen")
        clearUI(in: view)
        
        DispatchQueue.main.async {
            print("Building home screen UI")
            GameUIHelper.buildHomeScreen(
                in: view,
                target: target,
                classicSelector: #selector(MessagesViewController.startClassicMode),
                battleSelector: #selector(MessagesViewController.sendBattleInviteMessage)
            )
            self.viewController?.letterDisplayLabel?.text = ""
        }
    }
    
    func updatePlayerUI() {
        currentMode?.updateUI()
    }
    
    func resetGame() {
        timer?.invalidate()
        currentMode?.stopGame()
    }
    
    private func generateRandomLetter() -> String {
        let allowedLetters = "ABCDEFGHIJKLMNOPRSTUVWZ"
        return String(allowedLetters.randomElement()!)
    }
    
    @objc func startClassicMode() {
        guard let vc = viewController else { return }
        let classicManager = ClassicModeManager(viewController: vc)
        currentMode = classicManager
        classicManager.sendInitialInvite()
    }
    
    func startBattleMode(with playerNames: [String]) {
        guard let vc = viewController else { return }
        let battleManager = BattleModeManager(viewController: vc, playerNames: playerNames)
        currentMode = battleManager
        
        // First ensure UI is cleared
        clearUI(in: vc.view)
        
        // Setup UI synchronously
        battleManager.setupUI()
        
        // Start game after slight delay to ensure UI is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            battleManager.startGame()
        }
    }
    
    func processIncomingMessage(components: URLComponents) {
        guard let modeValue = components.queryItems?.first(where: { $0.name == "mode" })?.value else {
            print("No mode found in incoming message; ignoring.")
            return
        }

        switch modeValue {
        case "battle":
            if !(currentMode is BattleModeManager),
               let playerNames = extractPlayerNames(from: components) {
                startBattleMode(with: playerNames)
            }
            currentMode?.handleIncomingMessage(components: components)

        case "classic":
            if let opponentScore = components.queryItems?.first(where: { $0.name == "score" })?.value.flatMap(Int.init) {
                showFinalClassicResult(opponentScore: opponentScore, components: components)
            }
            guard (components.queryItems?.first(where: { $0.name == "letter" })?.value) != nil else {
                print("No letter found in classic message; ignoring.")
                return
            }
            guard let vc = viewController else { return }
            let classicManager = ClassicModeManager(viewController: vc)
            currentMode = classicManager
            classicManager.startGame()
            currentMode?.handleIncomingMessage(components: components)

        default:
            print("Unknown mode: \(modeValue); ignoring.")
        }
    }
    
    private func extractPlayerNames(from components: URLComponents) -> [String]? {
        let names = components.queryItems?
            .filter { $0.name.hasPrefix("player") && $0.name.contains("name") }
            .compactMap { $0.value }
        return names?.isEmpty == false ? names : nil
    }
    
    func showFinalClassicResult(opponentScore: Int, components: URLComponents) {
        let p1Score = currentMode?.score ?? 0
        GameUIHelper.showFinalResult(
            feedbackLabel: viewController?.feedbackLabel ?? UILabel(),
            inputField: viewController?.inputField ?? UITextField(),
            submitButton: viewController?.submitButton ?? UIButton(),
            p1: p1Score,
            p2: opponentScore
        )
    }
    
    func animatePlusOne() {
        guard let plusOneLabel = viewController?.plusOneLabel else { return }

        plusOneLabel.alpha = 1
        plusOneLabel.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)

        UIView.animate(withDuration: 0.6, delay: 0, options: [.curveEaseOut], animations: {
            plusOneLabel.alpha = 0
            plusOneLabel.transform = CGAffineTransform(translationX: 0, y: -30)
        }, completion: { _ in
            plusOneLabel.transform = .identity
        })
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        handleSubmitButtonTapped()
        return true
    }
    
    @objc func handleSubmitButtonTapped() {
        guard let input = viewController?.inputField?.text else { return }
        print("Submit button tapped with input: '\(input)'")

        currentMode?.handleSubmit(input: input)
    }
}
