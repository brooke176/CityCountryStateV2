//
//  MessagesViewController.swift
//  CityCountryState MessagesExtension
//
//  Created by Brooke Skinner on 6/10/25.
//

import UIKit
import Messages
import AudioToolbox

class MessagesViewController: MSMessagesAppViewController, UITextFieldDelegate {

    // MARK: - Player Scores and Game Completion
    private var playerOneScore: Int?
    private var playerTwoScore: Int?
    private var gameIsCompleted: Bool = false

    // MARK: - Opponent Score
    private var opponentScoreFromMessage: Int?

    // MARK: - Game State
    private let timeLimit: TimeInterval = 60
    private var timer: Timer?
    private var timeRemaining: TimeInterval = 0
    private var score = 0
    private var currentLetter = "A"
    private var usedWords = Set<String>()

    // MARK: - Data
    private var allCities = Set<String>()
    private var allCountries = Set<String>()
    private var allStates = Set<String>()

    private var correctCities = 0
    private var correctCountries = 0
    private var correctStates = 0

    // MARK: - UI Components
    private var inputField: UITextField!
    private var submitButton: UIButton!
    private var timerLabel: UILabel!
    private var scoreLabel: UILabel!
    private var feedbackLabel: UILabel!
    private var letterDisplayLabel: UILabel!
    private var timerRingLayer: CAShapeLayer!
    private var plusOneLabel: UILabel!

    // MARK: - Sounds & Feedback
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var correctSoundID: SystemSoundID = 0

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Load place data from plist
        if let url = Bundle.main.url(forResource: "place_data", withExtension: "plist") {
            if let data = try? Data(contentsOf: url),
               let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: [String]] {
                allCities = Set((dict["cities"] ?? []).map { $0.lowercased() })
                allCountries = Set((dict["countries"] ?? []).map { $0.lowercased() })
                allStates = Set((dict["states"] ?? []).map { $0.lowercased() })
                // print("Loaded \(allCities.count) cities, \(allCountries.count) countries, \(allStates.count) states")
            } else {
                // print("Error: Failed to parse place_data.plist")
            }
        } else {
            // print("Error: Could not find place_data.plist")
        }
        setupUI()
        inputField.delegate = self
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        guard let url = conversation.selectedMessage?.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            resetGame()
            return
        }

        let letter = components.queryItems?.first(where: { $0.name == "letter" })?.value
        let p1ScoreStr = components.queryItems?.first(where: { $0.name == "p1score" })?.value
        let p2ScoreStr = components.queryItems?.first(where: { $0.name == "p2score" })?.value
        let completedStr = components.queryItems?.first(where: { $0.name == "completed" })?.value

        if let letter = letter {
            currentLetter = letter
        }

        if let p1 = p1ScoreStr, let p1Int = Int(p1) {
            playerOneScore = p1Int
        }

        if let p2 = p2ScoreStr, let p2Int = Int(p2) {
            playerTwoScore = p2Int
        }

        gameIsCompleted = (completedStr == "true")

        if gameIsCompleted, let p1 = playerOneScore, let p2 = playerTwoScore {
            showFinalResult(p1: p1, p2: p2)
        } else if playerOneScore != nil && playerTwoScore == nil {
            resetGame()
        } else {
            resetGame()
        }
    }
    private func showFinalResult(p1: Int, p2: Int) {
        inputField.isEnabled = false
        submitButton.isEnabled = false

        let resultText: String
        if p2 > p1 {
            resultText = "🏆 Player 2 wins! (\(p2) vs \(p1))"
        } else if p2 < p1 {
            resultText = "🏆 Player 1 wins! (\(p1) vs \(p2))"
        } else {
            resultText = "🤝 It's a tie! (\(p1) vs \(p2))"
        }

        feedbackLabel.text = resultText
        feedbackLabel.textColor = .label
        feedbackLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        let ui = GameUIBuilder.build(in: view, delegate: self)
        inputField = ui.inputField
        submitButton = ui.submitButton
        timerLabel = ui.timerLabel
        scoreLabel = ui.scoreLabel
        feedbackLabel = ui.feedbackLabel
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)

        let instructionsLabel = UILabel()
        instructionsLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionsLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        instructionsLabel.textAlignment = .center
        instructionsLabel.textColor = .secondaryLabel
        instructionsLabel.text = "Type as many cities, countries, or states as you can."
        view.addSubview(instructionsLabel)
        NSLayoutConstraint.activate([
            instructionsLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            instructionsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        letterDisplayLabel = UILabel()
        letterDisplayLabel.translatesAutoresizingMaskIntoConstraints = false
        letterDisplayLabel.font = UIFont.systemFont(ofSize: 72, weight: .black)
        letterDisplayLabel.textAlignment = .center
        letterDisplayLabel.textColor = .systemIndigo
        letterDisplayLabel.text = currentLetter

        let letterCaptionLabel = UILabel()
        letterCaptionLabel.translatesAutoresizingMaskIntoConstraints = false
        letterCaptionLabel.text = "Your letter is..."
        letterCaptionLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        letterCaptionLabel.textColor = .label
        letterCaptionLabel.textAlignment = .center
        view.addSubview(letterCaptionLabel)
        view.addSubview(letterDisplayLabel)

        NSLayoutConstraint.activate([
            letterCaptionLabel.topAnchor.constraint(equalTo: instructionsLabel.bottomAnchor, constant: 12),
            letterCaptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            letterDisplayLabel.topAnchor.constraint(equalTo: letterCaptionLabel.bottomAnchor, constant: 4),
            letterDisplayLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        let ringDiameter: CGFloat = 60
        let ringPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: ringDiameter, height: ringDiameter))

        let timerContainer = UIView(frame: CGRect(x: 0, y: 0, width: ringDiameter, height: ringDiameter))
        timerContainer.translatesAutoresizingMaskIntoConstraints = false

        let backgroundRingLayer = CAShapeLayer()
        backgroundRingLayer.path = ringPath.cgPath
        backgroundRingLayer.strokeColor = UIColor.systemGray4.cgColor
        backgroundRingLayer.fillColor = UIColor.clear.cgColor
        backgroundRingLayer.lineWidth = 6
        timerContainer.layer.addSublayer(backgroundRingLayer)

        timerRingLayer = CAShapeLayer()
        timerRingLayer.path = ringPath.cgPath
        timerRingLayer.strokeColor = UIColor.systemBlue.cgColor
        timerRingLayer.fillColor = UIColor.clear.cgColor
        timerRingLayer.lineWidth = 6
        timerRingLayer.strokeEnd = 1.0
        timerContainer.layer.addSublayer(timerRingLayer)

        timerLabel.textAlignment = .center
        timerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .bold)
        timerLabel.textColor = .label
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        timerContainer.addSubview(timerLabel)
        NSLayoutConstraint.activate([
            timerLabel.centerXAnchor.constraint(equalTo: timerContainer.centerXAnchor),
            timerLabel.centerYAnchor.constraint(equalTo: timerContainer.centerYAnchor)
        ])

        view.addSubview(timerContainer)
        NSLayoutConstraint.activate([
            timerContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            timerContainer.topAnchor.constraint(equalTo: letterDisplayLabel.bottomAnchor, constant: 12),
            timerContainer.widthAnchor.constraint(equalToConstant: ringDiameter),
            timerContainer.heightAnchor.constraint(equalToConstant: ringDiameter)
        ])

        plusOneLabel = UILabel()
        plusOneLabel.text = "+1"
        plusOneLabel.font = UIFont.systemFont(ofSize: 36, weight: .heavy)
        plusOneLabel.textColor = .systemYellow
        plusOneLabel.alpha = 0
        plusOneLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(plusOneLabel)
        NSLayoutConstraint.activate([
            plusOneLabel.centerXAnchor.constraint(equalTo: scoreLabel.centerXAnchor),
            plusOneLabel.bottomAnchor.constraint(equalTo: scoreLabel.topAnchor, constant: -4)
        ])
    }

    // MARK: - Game Logic
    private func resetGame() {
        let allowedLetters = "ABCDEFGHIJKLMNOPRSTUVWZ"
        currentLetter = String(allowedLetters.randomElement()!)
        letterDisplayLabel.text = currentLetter
        score = 0
        timeRemaining = timeLimit
        usedWords.removeAll()
        correctCities = 0
        correctCountries = 0
        correctStates = 0
        updateLabels()
        startTimer()
    }

    // MARK: - Timer Control
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.timeRemaining -= 1
            self.updateLabels()
            if self.timeRemaining <= 0 {
                self.timer?.invalidate()
                self.inputField.isEnabled = false
                self.submitButton.isEnabled = false

                let endMessage = """
                Time's up!

                You scored \(self.score) total:

                📍 Cities: \(self.correctCities)
                🌐 Countries: \(self.correctCountries)
                🗺️ States: \(self.correctStates)
                """

                self.feedbackLabel.text = endMessage
                self.feedbackLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
                self.feedbackLabel.textColor = .label
                self.feedbackLabel.textAlignment = .center

                self.feedbackLabel.alpha = 0
                UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseOut]) {
                    self.feedbackLabel.alpha = 1
                    self.feedbackLabel.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
                } completion: { _ in
                    UIView.animate(withDuration: 0.2) {
                        self.feedbackLabel.transform = .identity
                    }
                }

                // Track scores for both players and completion
                if self.playerOneScore == nil {
                    self.playerOneScore = self.score
                } else {
                    self.playerTwoScore = self.score
                    self.gameIsCompleted = true
                }

                // Insert opponent score result if available
                if let p1 = self.playerOneScore, let p2 = self.playerTwoScore, self.gameIsCompleted {
                    self.showFinalResult(p1: p1, p2: p2)
                }

                self.requestPresentationStyle(.compact)

                let layout = MSMessageTemplateLayout()
                layout.image = UIImage(named: "newimage")
                layout.caption = "LET’S PLAY CITY COUNTRY STATE!"

                var components = URLComponents()
                // New logic for setting queryItems based on player turn
                if self.playerOneScore == nil {
                    // Player 1 just finished
                    self.playerOneScore = self.score
                    components.queryItems = [
                        URLQueryItem(name: "letter", value: self.currentLetter),
                        URLQueryItem(name: "p1score", value: String(self.playerOneScore!)),
                        URLQueryItem(name: "completed", value: "false")
                    ]
                } else {
                    // Player 2 just finished
                    self.playerTwoScore = self.score
                    components.queryItems = [
                        URLQueryItem(name: "letter", value: self.currentLetter),
                        URLQueryItem(name: "p1score", value: String(self.playerOneScore!)),
                        URLQueryItem(name: "p2score", value: String(self.playerTwoScore!)),
                        URLQueryItem(name: "completed", value: "true")
                    ]
                }

                let message = MSMessage()
                message.layout = layout
                message.url = components.url

                self.activeConversation?.insert(message, completionHandler: { error in
                    if let error = error {
                        // print("Error: Failed to send message: \(error.localizedDescription)")
                    } else {
                        // print("Game message sent to user")
                    }
                })
            }
        }
    }

    private func updateLabels() {
        timerLabel.text = "\(Int(timeRemaining))"
        scoreLabel.text = "Score: \(score)"
        let progress = CGFloat(timeRemaining / timeLimit)
        timerRingLayer.strokeEnd = progress
    }

    // MARK: - Gameplay Actions
    @objc private func submitTapped() {
        guard let rawInput = inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !rawInput.isEmpty else {
            feedbackLabel.text = "Huh"
            // print("Error: Empty or nil input")
            return
        }

        if !rawInput.hasPrefix(currentLetter.lowercased()) {
            feedbackLabel.text = "Hmm... doesn’t start with \(currentLetter)"
            // print("Error: Input does not start with \(currentLetter)")
            return
        }

        if usedWords.contains(rawInput) {
            feedbackLabel.text = "Already used that one!"
            // print("Error: Duplicate entry: \(rawInput)")
            return
        }

        if (allCities.contains(rawInput) || allCountries.contains(rawInput) || allStates.contains(rawInput)) {
            usedWords.insert(rawInput)
            score += 1
            if allCities.contains(rawInput) { correctCities += 1 }
            else if allCountries.contains(rawInput) { correctCountries += 1 }
            else if allStates.contains(rawInput) { correctStates += 1 }
            feedbackLabel.text = "Nice one!"
            feedbackGenerator.impactOccurred()
            AudioServicesPlaySystemSound(1306) // Apple Pay chime
            UIView.animate(withDuration: 0.2, animations: {
                self.feedbackLabel.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            }) { _ in
                UIView.animate(withDuration: 0.2) {
                    self.feedbackLabel.transform = .identity
                }
            }
            plusOneLabel.alpha = 1
            plusOneLabel.transform = CGAffineTransform(scaleX: 1.5, y: 1.5).translatedBy(x: 0, y: 0)
            UIView.animate(withDuration: 0.6, animations: {
                self.plusOneLabel.transform = CGAffineTransform(scaleX: 1.0, y: 1.0).translatedBy(x: 0, y: -60)
                self.plusOneLabel.alpha = 0
            })
        } else {
            feedbackLabel.text = "Oop, not a valid place"
        }

        inputField.text = ""
        updateLabels()
    }

    // MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        submitTapped()
        return true
    }

    // MARK: - Message Handling
    private func handleIncomingMessage(opponentScore: Int) {
        inputField.isEnabled = true
        submitButton.isEnabled = true

        let resultText: String
        if score > opponentScore {
            resultText = "🏆 You win! (\(score) vs \(opponentScore))"
        } else if score < opponentScore {
            resultText = "😞 You lose... (\(score) vs \(opponentScore))"
        } else {
            resultText = "🤝 It's a tie! (\(score) vs \(opponentScore))"
        }

        feedbackLabel.text = resultText
        feedbackLabel.textColor = .label
        feedbackLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
    }

}

private extension UITextField {
    func setLeftPaddingPoints(_ amount: CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.height))
        self.leftView = paddingView
        self.leftViewMode = .always
    }
}
