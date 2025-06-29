import UIKit
import Messages

class BattleModeManager {
    struct Player {
        var name: String
        var score: Int
        var isActive: Bool
    }
    
    weak var viewController: MessagesViewController?
    var players: [Player] = []
    var activePlayerIndex = 0
    var turnTimer: Timer?
    var timeRemaining: TimeInterval = 30
    var currentLetter: String
    private var usedWords = Set<String>()
    private var correctCities = 0
    private var correctCountries = 0
    private var correctStates = 0
    
    private let timeLimit: TimeInterval = 30
    
    init(viewController: MessagesViewController?, playerNames: [String]) {
        self.viewController = viewController
        self.players = playerNames.map { Player(name: $0, score: 0, isActive: false) }
        let allowedLetters = "ABCDEFGHIJKLMNOPRSTUVWZ"
        currentLetter = String(allowedLetters.randomElement()!)
    }
    
    func setupUI() {
        updateLetterDisplay()
        updatePlayerUI()
        startNewTurn()
    }
    
    func handleIncomingMessage(components: URLComponents) {
        guard let messageType = components.queryItems?.first(where: { $0.name == "type" })?.value else {
            print("Invalid message format")
            return
        }
        
        switch messageType {
        case "guess":
            if let guess = components.queryItems?.first(where: { $0.name == "guess" })?.value,
               let playerIndexStr = components.queryItems?.first(where: { $0.name == "playerIndex" })?.value,
               let playerIndex = Int(playerIndexStr) {
                handleIncomingGuess(guess, from: playerIndex)
            }
            
        case "turnUpdate":
            if let activeIndexStr = components.queryItems?.first(where: { $0.name == "activePlayerIndex" })?.value,
               let activeIndex = Int(activeIndexStr) {
                activePlayerIndex = activeIndex
                startNewTurn()
            }
            
        case "scoreUpdate":
            if let playerIndexStr = components.queryItems?.first(where: { $0.name == "playerIndex" })?.value,
               let playerIndex = Int(playerIndexStr),
               let scoreStr = components.queryItems?.first(where: { $0.name == "score" })?.value,
               let score = Int(scoreStr),
               playerIndex < players.count {
                players[playerIndex].score = score
                updateUI()
            }
            
        default:
            break
        }
    }
    
    private func handleIncomingGuess(_ guess: String, from playerIndex: Int) {
        guard playerIndex == activePlayerIndex else { return }
        handleSubmit(input: guess)
    }
    
    private func updateLetterDisplay() {
        viewController?.letterDisplayLabel.text = currentLetter
    }
    
    private func updatePlayerUI() {
        // Existing player UI update logic
    }
    
    private func startNewTurn() {
        for index in players.indices {
            players[index].isActive = (index == activePlayerIndex)
        }
        
        timeRemaining = timeLimit
        viewController?.inputField.text = ""
        viewController?.inputField.isEnabled = true
        viewController?.submitButton.isEnabled = true
        updateUI()
        
        turnTimer?.invalidate()
        turnTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.timerTick()
        }
        
        viewController?.feedbackLabel.text = "\(players[activePlayerIndex].name)'s Turn"
        GameManager.shared.updatePlayerUI()
    }
    
    private func timerTick() {
        timeRemaining -= 1
        guard let vc = viewController else { return }
        GameUIHelper.updateLabels(
            timerLabel: vc.timerLabel,
            scoreLabel: vc.scoreLabel,
            timerRingLayer: vc.timerRingLayer,
            timeRemaining: timeRemaining,
            timeLimit: timeLimit,
            score: players[activePlayerIndex].score
        )
        
        if timeRemaining <= 0 {
            turnTimer?.invalidate()
            handlePlayerTimeout()
        }
    }
    
    func handlePlayerTimeout() {
        viewController?.inputField.isEnabled = false
        viewController?.submitButton.isEnabled = false
        viewController?.feedbackLabel.text = "\(players[activePlayerIndex].name) ran out of time!"
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
            players[activePlayerIndex].score += 1
            
            if GameData.allCities.contains(rawInput) { correctCities += 1 }
            else if GameData.allCountries.contains(rawInput) { correctCountries += 1 }
            else if GameData.allStates.contains(rawInput) { correctStates += 1 }
            
            vc.feedbackLabel.text = "✅ Correct! Next player's turn."
            
            activePlayerIndex = (activePlayerIndex + 1) % players.count
            for index in players.indices {
                players[index].isActive = (index == activePlayerIndex)
            }
            GameManager.shared.updatePlayerTurnIndicators(players: players)
            startNewTurn()
        } else {
            vc.feedbackLabel.text = "❌ Not a valid place."
        }
    }
    
    @objc func handleSubmitButtonTapped() {
        if let input = viewController?.inputField.text {
            handleSubmit(input: input)
        }
    }
    
    private func setupPlayerIcons() {
        guard let container = viewController?.playerStackView else { return }
        container.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for (i, player) in players.enumerated() {
            let iconView = UIView()
            iconView.layer.cornerRadius = 14
            iconView.clipsToBounds = true
            iconView.backgroundColor = (i == activePlayerIndex) ? UIColor.systemBlue : UIColor.systemGray3
            iconView.layer.borderWidth = 2
            iconView.layer.borderColor = UIColor.white.cgColor
            
            let nameLabel = UILabel()
            nameLabel.text = player.name
            nameLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            nameLabel.textAlignment = .center
            nameLabel.textColor = .white
            
            iconView.addSubview(nameLabel)
            nameLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                nameLabel.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
                nameLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor)
            ])
            
            container.addArrangedSubview(iconView)
        }
    }
    
    private func updatePlayerIcons() {
        guard let container = viewController?.playerStackView else { return }
        for (i, view) in container.arrangedSubviews.enumerated() {
            view.backgroundColor = (i == activePlayerIndex) ? UIColor.systemBlue : UIColor.systemGray3
        }
    }
    
    func updateUI() {
        guard let vc = viewController else { return }
        GameUIHelper.updateLabels(
            timerLabel: vc.timerLabel,
            scoreLabel: vc.scoreLabel,
            timerRingLayer: vc.timerRingLayer,
            timeRemaining: timeRemaining,
            timeLimit: timeLimit,
            score: players[activePlayerIndex].score
        )
        GameManager.shared.updatePlayerUI()
        updatePlayerIcons()
    }
    
    func stopBattle() {
        turnTimer?.invalidate()
    }
}
