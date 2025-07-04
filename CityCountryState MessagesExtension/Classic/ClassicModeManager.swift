import UIKit
import Messages

class ClassicModeManager: NSObject, GameMode, UITextFieldDelegate {
    func resetGame() {
        resetClassicGame()
    }
    
    func handleIncomingMessage(components: URLComponents) {
        if let opponentScore = components.queryItems?.first(where: { $0.name == "score" })?.value.flatMap(Int.init) {
            if score == 0 {
                // This is the first player's turn
                score = opponentScore
                if let incomingLetter = components.queryItems?.first(where: { $0.name == "letter" })?.value {
                    currentLetter = incomingLetter
                }
                startGame()
            } else {
                // This is the response with opponent's score
                if score > opponentScore {
                    viewController?.feedbackLabel.text = "You won! 🎉\nYour score: \(score)\nOpponent: \(opponentScore)"
                } else if score < opponentScore {
                    viewController?.feedbackLabel.text = "You lost. 😢\nYour score: \(score)\nOpponent: \(opponentScore)"
                } else {
                    viewController?.feedbackLabel.text = "It’s a tie! 🤝\nScore: \(score)"
                }
            }
        }
    }
    
    private func showFinalResult(opponentScore: Int) {
        guard let vc = viewController else { return }
        GameUIHelper.showFinalResult(
            feedbackLabel: vc.feedbackLabel,
            inputField: vc.inputField,
            submitButton: vc.submitButton,
            p1: score,
            p2: opponentScore
        )
    }
    weak var viewController: MessagesViewController?
    
    var score: Int = 0
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
        resetClassicGame()
        setupUI()
        startTimer()
    }
    
    func sendInitialInvite() {
        guard let vc = viewController, let conversation = vc.activeConversation else { return }

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
                print("Error sending classic mode invite: \(error.localizedDescription)")
            } else {
                print("Classic mode invite sent.")
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
        guard let inputText = viewController?.inputField.text else { return }
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
            score: score
        )
        vc.letterDisplayLabel?.text = currentLetter
    }
    
    func resetClassicGame() {
        score = 0
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
        guard let viewController = viewController else { return }

        viewController.letterDisplayLabel?.isHidden = true
        viewController.inputField?.isHidden = true
        viewController.submitButton?.isHidden = true
        viewController.timerLabel?.isHidden = true
        viewController.scoreLabel?.isHidden = true
        viewController.requestPresentationStyle(.compact)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.showGameOverView()
        }
    }

    private func showGameOverView() {
        guard let vc = viewController, let conversation = vc.activeConversation else { return }

        let gameOverView = GameUIHelper.buildGameOverView(score: score)
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
            URLQueryItem(name: "score", value: "\(score)"),
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
        guard let vc = viewController else { return }
        let rawInput = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if rawInput.isEmpty {
            vc.feedbackLabel.text = "Please enter a word."
            return
        }

        if !rawInput.hasPrefix(currentLetter.lowercased()) {
            vc.feedbackLabel.text = "Hmm... doesn't start with \(currentLetter)"
            return
        }

        if usedWords.contains(rawInput) {
            vc.feedbackLabel.text = "That word was already used."
            return
        }

        if GameData.allCities.contains(rawInput) || GameData.allCountries.contains(rawInput) || GameData.allStates.contains(rawInput) {
            usedWords.insert(rawInput)
            score += 1
            GameManager.shared.animatePlusOne()
            updateUI()
        } else {
            vc.feedbackLabel.text = "We don't know this one!"
        }
        vc.inputField.text = ""
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let input = textField.text {
            handleSubmit(input: input)
        }
        return true
    }
}
