import UIKit
import Messages

class ClassicModeManager: NSObject, UITextFieldDelegate {
    weak var viewController: MessagesViewController?
    
    private var score: Int = 0
    private var timeRemaining: TimeInterval = 30
    private let timeLimit: TimeInterval = 30
    private var timer: Timer?
    private var currentLetter: String = ""
    private var usedWords = Set<String>()
    
    init(viewController: MessagesViewController) {
        self.viewController = viewController
        super.init()
        currentLetter = generateRandomLetter()
    }
    
    func startGame() {
        resetGame()
        showGameUI()
        startTimer()
    }
    
    private func showGameUI() {
        guard let view = viewController?.view else { return }
        GameManager.shared.clearUI(in: view)
        
        DispatchQueue.main.async {
            let uiElements = GameUIHelper.buildGameUI(in: view, delegate: self)
            
            self.viewController?.inputField = uiElements.inputField
            self.viewController?.submitButton = uiElements.submitButton
            self.viewController?.timerLabel = uiElements.timerLabel
            self.viewController?.scoreLabel = uiElements.scoreLabel
            self.viewController?.feedbackLabel = uiElements.feedbackLabel
            self.viewController?.letterDisplayLabel = uiElements.letterDisplayLabel
            self.viewController?.timerRingLayer = uiElements.timerRingLayer
            
            self.updateUI()
        }
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
        vc.letterDisplayLabel?.text = currentLetter
    }
    
    private func resetGame() {
        score = 0
        timeRemaining = timeLimit
        currentLetter = generateRandomLetter()
        usedWords.removeAll()
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
            startTimer()
            updateUI()
        } else {
            vc.feedbackLabel.text = "❌ Not a valid place."
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let input = textField.text {
            handleSubmit(input: input)
        }
        return true
    }
}
