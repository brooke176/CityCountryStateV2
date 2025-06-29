import UIKit
import AudioToolbox

class GameManager: NSObject, UITextFieldDelegate {
    static let shared = GameManager()
    
    weak var viewController: MessagesViewController?
    var selectedGameMode: GameMode = .classic
    private var battleManager: BattleModeManager?
    
    // Game state properties...
    // (Move relevant properties from MessagesViewController here)
    
    private override init() {}
    
    func setup(with viewController: MessagesViewController) {
        self.viewController = viewController
        // Setup any initial state
    }
    
    func startClassicMode() {
        selectedGameMode = .classic
        setupClassicModeUI()
    }
    
    func startBattleMode(with playerNames: [String]) {
        selectedGameMode = .battle
        battleManager = BattleModeManager(viewController: viewController, playerNames: playerNames)
        setupBattleModeUI()
        battleManager?.setupUI()
    }
    
    func handleIncomingMessage(components: URLComponents) {
        // Handle incoming message data
    }
    
    // All other game logic methods from MessagesViewController...
    // (setupUI, resetGame, handleSubmit, timer methods, etc.)
    
    private func setupClassicModeUI() {
        // Classic mode UI setup
    }
    
    private func setupBattleModeUI() {
        // Battle mode UI setup
    }
}
import UIKit
import Messages

class GameManager: NSObject, UITextFieldDelegate {
    static let shared = GameManager()
    
    weak var viewController: MessagesViewController?
    var selectedGameMode: GameMode = .classic
    private var battleManager: BattleModeManager?
    
    // Game state
    private var currentLetter: String = ""
    private var score: Int = 0
    private var timeRemaining: TimeInterval = 30
    private let timeLimit: TimeInterval = 30
    private var timer: Timer?
    
    private override init() {
        super.init()
        GameData.loadData()
    }
    
    func setup(with viewController: MessagesViewController) {
        self.viewController = viewController
        resetGame()
    }
    
    // MARK: - UI Management
    func clearUI(in view: UIView) {
        view.subviews.forEach { $0.removeFromSuperview() }
        view.layer.sublayers?.removeAll(where: { $0 is CAShapeLayer })
    }
    
    func showHomeScreen(in view: UIView, target: Any) {
        clearUI(in: view)
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
        viewController?.configureUIElements(uiElements)
        updateUI()
    }
    
    private func updateUI() {
        guard let vc = viewController else { return }
        GameUIHelper.updateLabels(
            timerLabel: vc.timerLabel,
            scoreLabel: vc.scoreLabel,
            timerRingLayer: vc.timerRingLayer,
            timeRemaining: timeRemaining,
            timeLimit: timeLimit,
            score: score
        )
    }
    
    // MARK: - Game Logic
    func resetGame() {
        score = 0
        timeRemaining = timeLimit
        currentLetter = generateRandomLetter()
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
        timeRemaining -= 1
        updateUI()
        
        if timeRemaining <= 0 {
            timer?.invalidate()
            handleTimeout()
        }
    }
    
    private func handleTimeout() {
        viewController?.inputField.isEnabled = false
        viewController?.submitButton.isEnabled = false
        viewController?.feedbackLabel.text = "Time's up!"
    }
    
    // MARK: - Mode Management
    func startClassicMode() {
        selectedGameMode = .classic
        showGameUI()
        startTimer()
    }
    
    func startBattleMode(with playerNames: [String]) {
        selectedGameMode = .battle
        battleManager = BattleModeManager(viewController: viewController, playerNames: playerNames)
        battleManager?.setupUI()
        showGameUI()
    }
    
    // MARK: - Message Handling
    func handleIncomingMessage(components: URLComponents) {
        guard let modeValue = components.queryItems?.first(where: { $0.name == "mode" })?.value else {
            showHomeScreen(in: viewController?.view ?? UIView(), target: viewController as Any)
            return
        }
        
        if modeValue == "battle" {
            battleManager?.handleIncomingMessage(components: components)
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
