import UIKit
import Messages

class GameManager: NSObject, UITextFieldDelegate {
    static let shared = GameManager()
    
    weak var viewController: MessagesViewController?
    enum GameState {
        case idle
        case classic(score: Int, timeRemaining: TimeInterval, currentLetter: String)
        case battle(BattleModeManager)
    }
    
    private var state: GameState = .idle {
        didSet {
            updateUI()
        }
    }
    
    private let timeLimit: TimeInterval = 30
    private var timer: Timer?
    
    private var currentLetter: String {
        switch state {
        case .classic(_, _, let letter): return letter
        default: return ""
        }
    }
    
    private var score: Int {
        switch state {
        case .classic(let score, _, _): return score
        default: return 0
        }
    }
    
    private override init() {
        super.init()
        GameData.loadData()
    }
    
    func setup(with viewController: MessagesViewController) {
        print("GameManager setup with viewController")
        self.viewController = viewController
        resetGame()
    }
    
    // MARK: - UI Management
    func clearUI(in view: UIView) {
        view.subviews.forEach { $0.removeFromSuperview() }
        view.layer.sublayers?.removeAll(where: { $0 is CAShapeLayer })
    }
    
    func showHomeScreen(in view: UIView, target: Any) {
        print("Showing home screen")
        clearUI(in: view)
        print("Building home screen UI")
        GameUIHelper.buildHomeScreen(
            in: view,
            target: target,
            classicSelector: #selector(MessagesViewController.startClassicMode),
            battleSelector: #selector(MessagesViewController.sendBattleInviteMessage)
        )
    }
    
    private func showGameUI() {
        guard let view = viewController?.view else { return }
        clearUI(in: view)
        let uiElements = GameUIHelper.buildGameUI(in: view, delegate: self)
        
        // Safely configure UI elements
        if let vc = viewController {
            vc.inputField = uiElements.inputField
            vc.submitButton = uiElements.submitButton
            vc.timerLabel = uiElements.timerLabel
            vc.scoreLabel = uiElements.scoreLabel
            vc.feedbackLabel = uiElements.feedbackLabel
            vc.letterDisplayLabel = uiElements.letterDisplayLabel
            vc.timerRingLayer = uiElements.timerRingLayer
        }
        
        updateUI()
    }
    
    private func updateUI() {
        guard let vc = viewController,
              let timerLabel = vc.timerLabel,
              let scoreLabel = vc.scoreLabel,
              let timerRingLayer = vc.timerRingLayer else { return }
        
        switch state {
        case .classic(let score, let timeRemaining, _):
            GameUIHelper.updateLabels(
                timerLabel: timerLabel,
                scoreLabel: scoreLabel,
                timerRingLayer: timerRingLayer,
                timeRemaining: timeRemaining,
                timeLimit: timeLimit,
                score: score
            )
            
        case .battle(let battleManager):
            battleManager.updateUI()
            
        case .idle:
            break
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

        updatePlayerTurnIndicators(players: battleManager.players)
    }

    func updatePlayerTurnIndicators(players: [BattleModeManager.Player]) {
        guard let vc = viewController else { return }

        vc.view.subviews.filter { $0.tag == 999 }.forEach { $0.removeFromSuperview() }

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.distribution = .fillEqually
        stackView.tag = 999
        stackView.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor, constant: 10),
            stackView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -10),
            stackView.heightAnchor.constraint(equalToConstant: 60)
        ])

        for player in players {
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
    
    // MARK: - Game Logic
    func resetGame() {
        state = .idle
        timer?.invalidate()
    }
    
    private func generateRandomLetter() -> String {
        let allowedLetters = "ABCDEFGHIJKLMNOPRSTUVWZ"
        return String(allowedLetters.randomElement()!)
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(timerTick),
            userInfo: nil,
            repeats: true
        )
    }
    
    @objc private func timerTick() {
        guard case .classic(let score, let timeRemaining, let letter) = state else {
            timer?.invalidate()
            return
        }
        
        let newTime = timeRemaining - 1
        if newTime <= 0 {
            timer?.invalidate()
            handleTimeout()
        } else {
            state = .classic(
                score: score,
                timeRemaining: newTime,
                currentLetter: letter
            )
        }
    }
    
    private func handleTimeout() {
        viewController?.inputField.isEnabled = false
        viewController?.submitButton.isEnabled = false
        viewController?.feedbackLabel.text = "Time's up!"
    }
    
    // MARK: - Mode Management
    func startClassicMode() {
        state = .classic(
            score: 0,
            timeRemaining: timeLimit,
            currentLetter: generateRandomLetter()
        )
        showGameUI()
        startTimer()
    }
    
    func startBattleMode(with playerNames: [String]) {
        let battleManager = BattleModeManager(
            viewController: viewController,
            playerNames: playerNames
        )
        state = .battle(battleManager)
        battleManager.setupUI()
        showGameUI()
    }
    
    // MARK: - Message Handling
    private var battleManager: BattleModeManager? {
        switch state {
        case .battle(let manager): return manager
        default: return nil
        }
    }
    
    func handleIncomingMessage(components: URLComponents) {
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
                handleIncomingMessage(opponentScore: opponentScore, components: components)
            }
        }
    }
    
    func handleIncomingMessage(opponentScore: Int, components: URLComponents) {
        GameUIHelper.showFinalResult(
            feedbackLabel: viewController?.feedbackLabel ?? UILabel(),
            inputField: viewController?.inputField ?? UITextField(),
            submitButton: viewController?.submitButton ?? UIButton(),
            p1: score,
            p2: opponentScore
        )
    }
}
