import UIKit
import Messages

class ClassicModeManager: NSObject, GameMode, UITextFieldDelegate {
    func handleIncomingMessage(components: URLComponents) {
        print("[ClassicModeManager] Handling incoming message...")
        if let opponentScore = components.queryItems?.first(where: { $0.name == "score" })?.value.flatMap(Int.init) {
            print("[ClassicModeManager] Opponent score received: \(opponentScore)")
            if score == nil {
                // This is the first player's turn
                if let incomingLetter = components.queryItems?.first(where: { $0.name == "letter" })?.value {
                    currentLetter = incomingLetter
                    print("[ClassicModeManager] Incoming letter set to: \(currentLetter)")
                }
                score = opponentScore
                startGame()
            } else {
                print("[ClassicModeManager] Comparing scores - Player: \(score ?? -1), Opponent: \(opponentScore)")
                // This is the response with opponent's score
                if (score ?? 0) > opponentScore {
                    print("[ClassicModeManager] Result: Player won")
                    viewController?.feedbackLabel.text = "You won! 🎉\nYour score: \(score ?? 0)\nOpponent: \(opponentScore)"
                } else if (score ?? 0) < opponentScore {
                    print("[ClassicModeManager] Result: Player lost")
                    viewController?.feedbackLabel.text = "You lost. 😢\nYour score: \(score ?? 0)\nOpponent: \(opponentScore)"
                } else {
                    print("[ClassicModeManager] Result: Tie")
                    viewController?.feedbackLabel.text = "It’s a tie! 🤝\nScore: \(score ?? 0)"
                }
            }
        } else {
            print("[ClassicModeManager] No opponent score found in incoming message")
        }
    }
    
    private func showFinalResult(opponentScore: Int) {
        guard let vc = viewController else { return }
        GameUIHelper.showFinalResult(
            feedbackLabel: vc.feedbackLabel,
            inputField: vc.inputField,
            submitButton: vc.submitButton,
            p1: score ?? 0,
            p2: opponentScore
        )
    }
    weak var viewController: MessagesViewController?
    
    var score: Int?
    private var timeRemaining: TimeInterval = 30
    private let timeLimit: TimeInterval = 20
    private var timer: Timer?
    internal var currentLetter: String = ""
    private var usedWords = Set<String>()
    
    init(viewController: MessagesViewController, initialLetter: String? = nil) {
        self.viewController = viewController
        super.init()
        if let letter = initialLetter {
            currentLetter = letter
        } else {
            currentLetter = generateRandomLetter()
        }
    }
    
    func startGame() {
        print("[ClassicModeManager] Starting game...")
        resetGame()
        setupUI()
        startTimer()
    }
    
    func sendInitialInvite() {
        guard let vc = viewController, let conversation = vc.activeConversation else {
            print("[ClassicModeManager] Failed to send invite: no view controller or conversation")
            return
        }
        
        print("[ClassicModeManager] Sending initial invite...")
        
        let layout = MSMessageTemplateLayout()
        layout.caption = "LET’S PLAY CITY COUNTRY STATE!"
        layout.image = UIImage(named: "newimage")
        layout.subcaption = "Classic Mode"
        
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "mode", value: "classic"),
            URLQueryItem(name: "score", value: "0"),
            URLQueryItem(name: "letter", value: generateRandomLetter())
        ]
        
        let message = MSMessage()
        message.layout = layout
        message.url = components.url
        
        conversation.insert(message) { error in
            if let error = error {
                print("[ClassicModeManager] Error sending classic mode invite: \(error.localizedDescription)")
            } else {
                print("[ClassicModeManager] Classic mode invite sent successfully.")
            }
        }
    }
    
    func stopGame() {
        timer?.invalidate()
    }
    
    internal func setupUI() {
        guard let view = viewController?.view else { return }
        GameManager.shared.clearUI(in: view)
        
        DispatchQueue.main.async {
            let uiElements = GameUIHelper.buildGameUI(in: view, delegate: self)
            
            self.viewController?.inputField = uiElements.inputField
            self.viewController?.submitButton = uiElements.submitButton
            self.viewController?.submitButton.addTarget(self, action: #selector(self.submitButtonTapped), for: .touchUpInside)
            self.viewController?.timerLabel = uiElements.timerLabel
            self.viewController?.scoreLabel = uiElements.scoreLabel
            self.viewController?.feedbackLabel = uiElements.feedbackLabel
            self.viewController?.letterDisplayLabel = uiElements.letterDisplayLabel
            self.viewController?.timerRingLayer = uiElements.timerRingLayer
            self.viewController?.plusOneLabel = uiElements.plusOneLabel
            
            self.updateUI()
        }
    }
    
    @objc private func submitButtonTapped() {
        guard let inputText = viewController?.inputField.text else {
            print("[ClassicModeManager] Submit button tapped but input field is empty")
            return
        }
        print("[ClassicModeManager] Submit button tapped with input: \(inputText)")
        handleSubmit(input: inputText)
    }
    
    internal func updateUI() {
        guard let vc = viewController else { return }
        GameUIHelper.updateLabels(
            timerLabel: vc.timerLabel,
            scoreLabel: vc.scoreLabel,
            timerRingLayer: vc.timerRingLayer,
            timeRemaining: timeRemaining,
            timeLimit: timeLimit,
            score: score ?? 0
        )
        vc.letterDisplayLabel?.text = currentLetter
    }
    
    func resetGame() {
        print("[ClassicModeManager] Resetting classic game state")
        score = nil
        timeRemaining = timeLimit
        if currentLetter.isEmpty { currentLetter = generateRandomLetter() }
        usedWords.removeAll()
        timer?.invalidate()
        setupUI()
        startTimer()
    }
    
    private func generateRandomLetter() -> String {
        let allowedLetters = "ABCDEFGHIJKLMNOPRSTUVWZ"
        return String(allowedLetters.randomElement()!)
    }
    
    private func startTimer() {
        print("[ClassicModeManager] Starting timer with \(timeRemaining) seconds remaining")
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
            print("[ClassicModeManager] Timer expired")
            timer?.invalidate()
            handleTimeout()
        }
    }
    
    private func handleTimeout() {
        print("[ClassicModeManager] Handling timeout - time's up!")
        guard let viewController = viewController else {
            print("[ClassicModeManager] No view controller in handleTimeout")
            return
        }
        
        viewController.letterDisplayLabel?.isHidden = true
        viewController.inputField?.isHidden = true
        viewController.submitButton?.isHidden = true
        viewController.timerLabel?.isHidden = true
        viewController.scoreLabel?.isHidden = true
        viewController.requestPresentationStyle(.compact)
        
        DispatchQueue.main.async {
            self.showGameOverView()
        }
    }

    private func showGameOverView() {
        print("[ClassicModeManager] Showing game over view with score: \(score ?? 0)")
        guard let vc = viewController, let conversation = vc.activeConversation else {
            print("[ClassicModeManager] Missing view controller or conversation in showGameOverView")
            return
        }
        
        let gameOverView = GameUIHelper.buildGameOverView(score: score ?? 0)
        GameManager.shared.clearUI(in: vc.view)
        vc.view.addSubview(gameOverView)
        
        gameOverView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            gameOverView.topAnchor.constraint(equalTo: vc.view.topAnchor),
            gameOverView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
            gameOverView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            gameOverView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor)
        ])
        
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "mode", value: "classic"),
            URLQueryItem(name: "score", value: "\(score ?? 0)"),
            URLQueryItem(name: "letter", value: currentLetter)
        ]
        
        let layout = MSMessageTemplateLayout()
        layout.caption = "LET’S PLAY CITY COUNTRY STATE!"
        layout.image = UIImage(named: "newimage")
        layout.subcaption = "Classic Mode"
        
        conversation.selectedMessage?.url = components.url
        conversation.selectedMessage?.layout = layout
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        gameOverView.feedbackLabel?.text = "Score sent ✓"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.animateWaitingDots(in: gameOverView.feedbackLabel!)
        }
    }
    
    private func animateWaitingDots(in label: UILabel) {
        var dotCount = 1
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if self.timer == nil { timer.invalidate(); return }
            let dots = String(repeating: ".", count: dotCount)
            label.text = "Waiting for opponent" + dots
            dotCount = dotCount % 3 + 1
        }
    }
    
    func handleSubmit(input: String) {
        guard let vc = viewController else {
            print("[ClassicModeManager] handleSubmit called but no view controller")
            return
        }
        let rawInput = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        print("[ClassicModeManager] Handling submit with input: '\(rawInput)'")
        
        if rawInput.isEmpty {
            print("[ClassicModeManager] Input empty - prompting user")
            vc.feedbackLabel.text = "Please enter a word."
            return
        }
        
        if !rawInput.hasPrefix(currentLetter.lowercased()) {
            print("[ClassicModeManager] Input does not start with required letter '\(currentLetter)'")
            vc.feedbackLabel.text = "Hmm... doesn't start with \(currentLetter)"
            return
        }
        
        if usedWords.contains(rawInput) {
            print("[ClassicModeManager] Input word '\(rawInput)' already used")
            vc.feedbackLabel.text = "That word was already used."
            return
        }
        
        if GameData.allCities.contains(rawInput) || GameData.allCountries.contains(rawInput) || GameData.allStates.contains(rawInput) {
            print("[ClassicModeManager] Accepted word '\(rawInput)'. Incrementing score")
            usedWords.insert(rawInput)
            if score == nil { score = 0 }
            score! += 1
            GameManager.shared.animatePlusOne()
            updateUI()
        } else {
            print("[ClassicModeManager] Unknown word '\(rawInput)'")
            vc.feedbackLabel.text = "We don't know this one!"
        }
        vc.inputField.text = ""
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let input = textField.text {
            print("[ClassicModeManager] TextField return pressed with input: '\(input)'")
            handleSubmit(input: input)
        }
        return true
    }
}
