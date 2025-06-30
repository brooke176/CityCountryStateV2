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
    
    private func showGameUI(completion: @escaping () -> Void) {
        guard let view = viewController?.view else {
            print("Error: No view controller view available")
            return
        }
        clearUI(in: view)
        
        DispatchQueue.main.async {
            let uiElements = GameUIHelper.buildGameUI(in: view, delegate: self)

            self.viewController?.inputField = uiElements.inputField
            self.viewController?.submitButton = uiElements.submitButton
            self.viewController?.timerLabel = uiElements.timerLabel
            self.viewController?.timerLabel?.backgroundColor = UIColor.blue.withAlphaComponent(0.3)
            self.viewController?.scoreLabel = uiElements.scoreLabel
            self.viewController?.feedbackLabel = uiElements.feedbackLabel
            self.viewController?.letterDisplayLabel = uiElements.letterDisplayLabel
            self.viewController?.timerRingLayer = uiElements.timerRingLayer
            self.viewController?.submitButton?.addTarget(self, action: #selector(self.handleSubmitButtonTapped), for: .touchUpInside)

            completion()
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
        classicManager.startGame()
    }
    
    func startBattleMode(with playerNames: [String]) {
        guard let vc = viewController else { return }
        let battleManager = BattleModeManager(viewController: vc, playerNames: playerNames)
        currentMode = battleManager
        battleManager.startGame()
    }
    
    func processIncomingMessage(components: URLComponents) {
        guard let modeValue = components.queryItems?.first(where: { $0.name == "mode" })?.value else {
            DispatchQueue.main.async {
                self.showHomeScreen(in: self.viewController?.view ?? UIView(), target: self.viewController as Any)
            }
            return
        }
        
        if modeValue == "battle" && !(currentMode is BattleModeManager) {
            if let playerNames = extractPlayerNames(from: components) {
                startBattleMode(with: playerNames)
            }
        }
        
        currentMode?.handleIncomingMessage(components: components)
    }
    
    private func handleClassicMessage(components: URLComponents) {
        if let opponentScore = components.queryItems?.first(where: { $0.name == "score" })?.value.flatMap(Int.init) {
            showFinalClassicResult(opponentScore: opponentScore, components: components)
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
        currentMode?.handleSubmit(input: input)
    }
}
