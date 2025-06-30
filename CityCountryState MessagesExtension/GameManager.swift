import UIKit
import Messages

class GameManager: NSObject, UITextFieldDelegate {
    static let shared = GameManager()
    var usedWords = Set<String>()

    weak var viewController: MessagesViewController?
    private var classicManager: ClassicModeManager?
    private var battleManager: BattleModeManager?
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
              let battleManager = battleManager else { return }

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
    }
    
    func resetGame() {
        timer?.invalidate()
        classicManager?.stopGame()
        battleManager?.stopBattle()
        classicManager = nil
    }
    
    private func generateRandomLetter() -> String {
        let allowedLetters = "ABCDEFGHIJKLMNOPRSTUVWZ"
        return String(allowedLetters.randomElement()!)
    }
    
    func startClassicMode() {
        guard let vc = viewController else { return }
        classicManager = ClassicModeManager(viewController: vc)
        battleManager = nil
        classicManager?.startGame()
    }
    
    func startBattleMode(with playerNames: [String]) {
        guard viewController != nil else { return }
        let battleManager = BattleModeManager(viewController: viewController, playerNames: playerNames)
        self.battleManager = battleManager
        showGameUI {
            battleManager.setupUI()
        }
    }
    
    func processIncomingMessage(components: URLComponents) {
        guard let modeValue = components.queryItems?.first(where: { $0.name == "mode" })?.value else {
            DispatchQueue.main.async {
                self.showHomeScreen(in: self.viewController?.view ?? UIView(), target: self.viewController as Any)
            }
            return
        }
        
        if modeValue == "battle" {
            if let battleManager = battleManager {
                battleManager.handleIncomingMessage(components: components)
            } else {
                // Handle case where we receive battle message but aren't in battle mode
                let playerNames = components.queryItems?
                    .filter { $0.name.hasPrefix("player") }
                    .compactMap { $0.value }
                if let names = playerNames, !names.isEmpty {
                    startBattleMode(with: names)
                    battleManager?.handleIncomingMessage(components: components)
                }
            }
        } else {
            if let opponentScore = components.queryItems?.first(where: { $0.name == "score" })?.value.flatMap(Int.init) {
                showFinalClassicResult(opponentScore: opponentScore, components: components)
            }
        }
    }
    
    func showFinalClassicResult(opponentScore: Int, components: URLComponents) {
        GameUIHelper.showFinalResult(
            feedbackLabel: viewController?.feedbackLabel ?? UILabel(),
            inputField: viewController?.inputField ?? UITextField(),
            submitButton: viewController?.submitButton ?? UIButton(),
            p1: classicManager?.score ?? 0,
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
        if let classic = classicManager {
            classic.handleSubmit(input: input)
        } else if let battle = battleManager {
            battle.handleSubmit(input: input)
        }
    }
}
