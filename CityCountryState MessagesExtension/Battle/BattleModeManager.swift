import UIKit
import Messages

class BattleModeManager: NSObject, GameMode, UITextFieldDelegate {
    func resetGame() {
        players.forEach { $0.score = 0 }
        usedWords.removeAll()
        correctCities = 0
        correctCountries = 0
        correctStates = 0
        turnTimer?.invalidate()
        startNewTurn()
    }
    
    func startGame() {
        setupUI()
        resetGame()
    }

    var score: Int {
        return players.reduce(0) { $0 + $1.score }
    }
    class Player {
        let id: String
        var name: String
        var score: Int
        var isActive: Bool
        
        init(id: String = UUID().uuidString, name: String, score: Int = 0, isActive: Bool = false) {
            self.id = id
            self.name = name
            self.score = score
            self.isActive = isActive
        }
    }
    
    weak var viewController: MessagesViewController?
    var players: [Player] = []
    var activePlayerIndex = 0
    var turnTimer: Timer?
    var timeRemaining: TimeInterval = 30
    var currentLetter: String = "A"
    var usedWords = Set<String>()
    var correctCities = 0
    var correctCountries = 0
    var correctStates = 0
    
    let timeLimit: TimeInterval = 30
    
    init(viewController: MessagesViewController?, playerNames: [String]) {
        self.viewController = viewController
        self.players = playerNames.map { Player(name: $0, score: 0, isActive: false) }
        let allowedLetters = "ABCDEFGHIJKLMNOPRSTUVWZ"
        currentLetter = String(allowedLetters.randomElement()!)
        print("currentLetter", currentLetter)
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
    
    func startNewTurn() {
        guard let vc = viewController else {
            print("BattleModeManager: viewController is nil in startNewTurn")
            return
        }
        
        // Reset turn state
        timeRemaining = timeLimit
        vc.inputField.text = ""
        vc.inputField.isEnabled = true
        vc.submitButton.isEnabled = true
        
        // Update player states
        for index in players.indices {
            players[index].isActive = (index == activePlayerIndex)
        }
        
        // Update UI
        DispatchQueue.main.async {
            vc.letterDisplayLabel?.text = self.currentLetter
            vc.feedbackLabel.text = "\(self.players[self.activePlayerIndex].name)'s Turn"
            self.updateUI()
            
            // Start new timer
            self.turnTimer?.invalidate()
            self.turnTimer = Timer.scheduledTimer(
                withTimeInterval: 1, 
                repeats: true
            ) { [weak self] _ in
                self?.timerTick()
            }
        }
    }
    
    private func timerTick() {
        timeRemaining -= 1
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self, 
                  let vc = self.viewController,
                  let timerRingLayer = vc.timerRingLayer else {
                return
            }
            
            // Update timer ring
            let progress = CGFloat(self.timeRemaining / self.timeLimit)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            timerRingLayer.strokeEnd = progress
            CATransaction.commit()
            
            // Update labels
            vc.timerLabel?.text = "\(Int(self.timeRemaining))"
            vc.scoreLabel?.text = "Score: \(self.players[self.activePlayerIndex].score)"
            
            // Handle timeout
            if self.timeRemaining <= 0 {
                self.turnTimer?.invalidate()
                self.turnTimer = nil
                self.handlePlayerTimeout()
            }
        }
    }
    
    func handlePlayerTimeout() {
        viewController?.inputField.isEnabled = false
        viewController?.submitButton.isEnabled = false
        viewController?.inputField?.isHidden = true
        viewController?.submitButton?.isHidden = true
        viewController?.timerLabel?.isHidden = true
        viewController?.scoreLabel?.isHidden = true
        viewController?.feedbackLabel.text = "\(players[activePlayerIndex].name) loses!"
        viewController?.requestPresentationStyle(.compact)
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
        
        if GameData.allCities.contains(rawInput) {
            usedWords.insert(rawInput)
            players[activePlayerIndex].score += 1
            correctCities += 1
            handleCorrectAnswer()
        } else if GameData.allCountries.contains(rawInput) {
            usedWords.insert(rawInput)
            players[activePlayerIndex].score += 1
            correctCountries += 1
            handleCorrectAnswer()
        } else if GameData.allStates.contains(rawInput) {
            usedWords.insert(rawInput)
            players[activePlayerIndex].score += 1
            correctStates += 1
            handleCorrectAnswer()
        } else {
            vc.feedbackLabel.text = "We don't know this one!"
        }
    }
    
    private func handleCorrectAnswer() {
        guard let vc = viewController else { return }
        vc.feedbackLabel.text = "✅ Correct! Next player's turn."
        activePlayerIndex = (activePlayerIndex + 1) % players.count
        for index in players.indices {
            players[index].isActive = (index == activePlayerIndex)
        }
        startNewTurn()
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
    
    func setupUI() {
        guard let view = viewController?.view else {
            print("BattleModeManager: No view available for setupUI")
            return
        }
        
        // Clear UI first
        GameManager.shared.clearUI(in: view)
        
        // Build base UI
        let uiElements = GameUIHelper.buildGameUI(in: view, delegate: self)
        
        // Configure view controller references
        viewController?.inputField = uiElements.inputField
        viewController?.submitButton = uiElements.submitButton
        viewController?.timerLabel = uiElements.timerLabel
        viewController?.scoreLabel = uiElements.scoreLabel
        viewController?.feedbackLabel = uiElements.feedbackLabel
        viewController?.letterDisplayLabel = uiElements.letterDisplayLabel
        
        // Setup timer ring
        setupTimerRing(in: view, timerLabel: uiElements.timerLabel)
        
        // Start first turn
        startNewTurn()
    }
    
    private func setupTimerRing(in view: UIView, timerLabel: UILabel) {
        let timerRingContainer = UIView()
        timerRingContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(timerRingContainer)
        
        let ringDiameter: CGFloat = 60
        let ringPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: ringDiameter, height: ringDiameter))
        
        let backgroundRingLayer = CAShapeLayer()
        backgroundRingLayer.path = ringPath.cgPath
        backgroundRingLayer.strokeColor = UIColor.lightGray.cgColor
        backgroundRingLayer.lineWidth = 5
        backgroundRingLayer.fillColor = UIColor.clear.cgColor
        
        let timerRingLayer = CAShapeLayer()
        timerRingLayer.path = ringPath.cgPath
        timerRingLayer.strokeColor = UIColor.systemBlue.cgColor
        timerRingLayer.lineWidth = 5
        timerRingLayer.fillColor = UIColor.clear.cgColor
        timerRingLayer.strokeEnd = 1.0
        
        timerRingContainer.layer.addSublayer(backgroundRingLayer)
        timerRingContainer.layer.addSublayer(timerRingLayer)
        
        viewController?.timerRingLayer = timerRingLayer
        
        NSLayoutConstraint.activate([
            timerRingContainer.centerXAnchor.constraint(equalTo: timerLabel.centerXAnchor),
            timerRingContainer.centerYAnchor.constraint(equalTo: timerLabel.centerYAnchor),
            timerRingContainer.widthAnchor.constraint(equalToConstant: ringDiameter),
            timerRingContainer.heightAnchor.constraint(equalToConstant: ringDiameter)
        ])
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

    func stopGame() {
        turnTimer?.invalidate()
    }
}
