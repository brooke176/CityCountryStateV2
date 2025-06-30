import UIKit
import Messages

class ClassicModeManager: NSObject, GameMode, UITextFieldDelegate {
    weak var viewController: MessagesViewController?
    
    var score: Int = 0
    private var timeRemaining: TimeInterval = 30
    private let timeLimit: TimeInterval = 5
    private var timer: Timer?
    private var currentLetter: String = ""
    private var usedWords = Set<String>()
    
    init(viewController: MessagesViewController) {
        self.viewController = viewController
        super.init()
        currentLetter = generateRandomLetter()
    }
    
    func startGame() {
        resetClassicGame()
        showGameUI()
        startTimer()
    }
    
    func stopGame() {
        timer?.invalidate()
    }
    
    private func showGameUI() {
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
        currentLetter = generateRandomLetter()
        usedWords.removeAll()
        timer?.invalidate()
        showGameUI()
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
        guard let vc = viewController,
        let conversation = vc.activeConversation else { return }

        let endMessage = """
        Time's up!

        You scored \(score) total:

        📍 Cities: \(usedWords.filter { GameData.allCities.contains($0) }.count)
        🌐 Countries: \(usedWords.filter { GameData.allCountries.contains($0) }.count)
        🗺️ States: \(usedWords.filter { GameData.allStates.contains($0) }.count)
        """

         vc.feedbackLabel.text = endMessage
         vc.feedbackLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
         vc.feedbackLabel.textColor = .label
         vc.feedbackLabel.textAlignment = .center
        
         vc.feedbackLabel.alpha = 0
         UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseOut], animations: {
             vc.feedbackLabel.alpha = 1
             vc.feedbackLabel.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
         }, completion: { _ in
             UIView.animate(withDuration: 0.2) {
                 vc.feedbackLabel.transform = .identity
             }
         })

        // Draft outgoing MSMessage with classic challenge result
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "mode", value: "classic"),
            URLQueryItem(name: "score", value: "\(score)")
        ]

        let layout = MSMessageTemplateLayout()
        layout.caption = "LET’S PLAY CITY COUNTRY STATE! (CLASSIC MODE)"
        layout.image = UIImage(named: "newimage")

        let message = MSMessage()
        message.layout = layout
        message.url = components.url

        conversation.insert(message) { error in
            if let error = error {
                print("Error sending message: \(error.localizedDescription)")
            } else {
                print("Classic challenge message sent successfully.")
            }
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
