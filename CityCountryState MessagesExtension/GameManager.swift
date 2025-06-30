import UIKit
import Messages

private var currentMode: GameMode?

class GameManager: NSObject, UITextFieldDelegate {
    static let shared = GameManager()
    var usedWords = Set<String>()
    weak var viewController: MessagesViewController?
    private var currentMode: Mode?
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
        guard let vc = viewController,
              let mode = currentMode else { return }
        switch mode {
        case .battle(let battleManager):
            vc.playerStackView?.arrangedSubviews.forEach { $0.removeFromSuperview() }

            for player in battleManager.players {
                let container = UIView()
                container.backgroundColor = .secondarySystemBackground
                container.layer.cornerRadius = 8
                container.layer.borderWidth = player.isActive ? 3 : 1
                container.layer.borderColor = player.isActive ? UIColor.systemGreen.cgColor : UIColor.lightGray.cgColor

                let nameLabel = UILabel()
                nameLabel.text = "\(player.name) (\(player.score))"
                nameLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
                nameLabel.textAlignment = .center
                nameLabel.translatesAutoresizingMaskIntoConstraints = false

                container.addSubview(nameLabel)
                NSLayoutConstraint.activate([
                    nameLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
                ])

                vc.playerStackView?.addArrangedSubview(container)
            }

            guard let stackView = vc.playerStackView else { return }

            stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

            for player in battleManager.players {
                let container = UIView()
                container.layer.cornerRadius = 10
                container.layer.borderWidth = player.isActive ? 3 : 1
                container.layer.borderColor = player.isActive ? UIColor.systemGreen.cgColor : UIColor.lightGray.cgColor
                container.backgroundColor = .secondarySystemBackground

                let nameLabel = UILabel()
                nameLabel.text = "\(player.name) (\(player.score))"
                nameLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
                nameLabel.textAlignment = .center
                nameLabel.translatesAutoresizingMaskIntoConstraints = false

                container.addSubview(nameLabel)
                NSLayoutConstraint.activate([
                    nameLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
                ])

                stackView.addArrangedSubview(container)
            }
        case .classic:
            // Do nothing for classic mode
            break
        }
    }
    
    func resetGame() {
        timer?.invalidate()
        switch currentMode {
        case .classic(let classicManager):
            classicManager.stopGame()
        case .battle(let battleManager):
            battleManager.stopGame()
        case .none:
            print("No current game mode to reset.")
        }
    }
    
    private func generateRandomLetter() -> String {
        let allowedLetters = "ABCDEFGHIJKLMNOPRSTUVWZ"
        return String(allowedLetters.randomElement()!)
    }
    
    @objc func startClassicMode() {
        guard let vc = viewController else { return }
        currentMode = ClassicModeManager(viewController: vc)
        currentMode?.startGame()
    }
    
    func startBattleMode(with playerNames: [String]) {
        guard let vc = viewController else { return }
        currentMode = BattleModeManager(viewController: vc, playerNames: playerNames)
        currentMode?.startGame()
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
        var p1Score = 0
        if let mode = currentMode {
            switch mode {
            case .classic(let classicManager):
                p1Score = classicManager.score
            case .battle:
                p1Score = 0
            }
        }
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
