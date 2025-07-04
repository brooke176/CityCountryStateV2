import UIKit

struct GameUIHelper {
    static func updateLabels(timerLabel: UILabel, scoreLabel: UILabel, timerRingLayer: CAShapeLayer, timeRemaining: TimeInterval, timeLimit: TimeInterval, score: Int) {
        timerLabel.text = "\(Int(timeRemaining))"
        scoreLabel.text = "Score: \(score)"
        
        guard timeLimit > 0 else {
            timerRingLayer.strokeEnd = 0
            return
        }
        
        let rawProgress = timeRemaining / timeLimit
        let clampedProgress = max(0, min(1, rawProgress))
        
        timerRingLayer.strokeEnd = CGFloat(clampedProgress)
    }

    static func showFinalResult(feedbackLabel: UILabel, inputField: UITextField, submitButton: UIButton, p1: Int, p2: Int) {
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

    static func buildHomeScreen(in parentView: UIView, target: Any, classicSelector: Selector, battleSelector: Selector) {
        parentView.subviews.forEach { $0.removeFromSuperview() }

        let classicButton = UIButton(type: .system)
        classicButton.setTitle("Play Classic", for: .normal)
        classicButton.addTarget(target, action: classicSelector, for: .touchUpInside)
        classicButton.translatesAutoresizingMaskIntoConstraints = false

        let battleButton = UIButton(type: .system)
        battleButton.setTitle("Play Battle", for: .normal)
        battleButton.addTarget(target, action: battleSelector, for: .touchUpInside)
        battleButton.translatesAutoresizingMaskIntoConstraints = false

        parentView.addSubview(classicButton)
        parentView.addSubview(battleButton)

        NSLayoutConstraint.activate([
            classicButton.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),
            classicButton.centerYAnchor.constraint(equalTo: parentView.centerYAnchor, constant: -30),

            battleButton.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),
            battleButton.topAnchor.constraint(equalTo: classicButton.bottomAnchor, constant: 20)
        ])
    }

    static func buildGameUI(in parentView: UIView, delegate: UITextFieldDelegate) -> (
        inputField: UITextField,
        submitButton: UIButton,
        timerLabel: UILabel,
        scoreLabel: UILabel,
        feedbackLabel: UILabel,
        letterDisplayLabel: UILabel,
        timerRingLayer: CAShapeLayer,
        plusOneLabel: UILabel
    ) {
        var inputField: UITextField!
        var submitButton: UIButton!
        var timerLabel: UILabel!
        var scoreLabel: UILabel!
        var feedbackLabel: UILabel!
        var letterDisplayLabel: UILabel!
        var timerRingLayer: CAShapeLayer!
        var plusOneLabel: UILabel!

        parentView.subviews.forEach { $0.removeFromSuperview() }
        parentView.backgroundColor = .systemGroupedBackground

        inputField = UITextField()
        inputField.borderStyle = .roundedRect
        inputField.placeholder = "Enter place..."
        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.delegate = delegate
        parentView.addSubview(inputField)

        submitButton = UIButton(type: .system)
        submitButton.setTitle("Submit", for: .normal)
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(submitButton)

        timerLabel = UILabel()
        timerLabel.textAlignment = .center
        timerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .bold)
        timerLabel.textColor = .label
        timerLabel.translatesAutoresizingMaskIntoConstraints = false

        let timerRingContainer = UIView()
        timerRingContainer.translatesAutoresizingMaskIntoConstraints = false
        let ringDiameter: CGFloat = 60
        let ringPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: ringDiameter, height: ringDiameter))

        let backgroundRingLayer = CAShapeLayer()
        backgroundRingLayer.path = ringPath.cgPath
        backgroundRingLayer.strokeColor = UIColor.systemGray4.cgColor
        backgroundRingLayer.fillColor = UIColor.clear.cgColor
        backgroundRingLayer.lineWidth = 6
        timerRingContainer.layer.addSublayer(backgroundRingLayer)

        timerRingLayer = CAShapeLayer()
        timerRingLayer.path = ringPath.cgPath
        timerRingLayer.strokeColor = UIColor.systemBlue.cgColor
        timerRingLayer.fillColor = UIColor.clear.cgColor
        timerRingLayer.lineWidth = 6
        timerRingLayer.strokeEnd = 1.0
        timerRingContainer.layer.addSublayer(timerRingLayer)
        timerRingContainer.addSubview(timerLabel)
        parentView.addSubview(timerRingContainer)

        scoreLabel = UILabel()
        scoreLabel.textAlignment = .center
        scoreLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        scoreLabel.textColor = .label
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(scoreLabel)

        feedbackLabel = UILabel()
        feedbackLabel.textAlignment = .center
        feedbackLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        feedbackLabel.numberOfLines = 0
        feedbackLabel.lineBreakMode = .byWordWrapping
        feedbackLabel.textColor = .label
        feedbackLabel.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(feedbackLabel)

        let letterCaptionLabel = UILabel()
        letterCaptionLabel.translatesAutoresizingMaskIntoConstraints = false
        letterCaptionLabel.text = "Your letter is..."
        letterCaptionLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        letterCaptionLabel.textColor = .label
        letterCaptionLabel.textAlignment = .center
        parentView.addSubview(letterCaptionLabel)

        letterDisplayLabel = UILabel()
        letterDisplayLabel.translatesAutoresizingMaskIntoConstraints = false
        letterDisplayLabel.font = UIFont.systemFont(ofSize: 72, weight: .black)
        letterDisplayLabel.textAlignment = .center
        letterDisplayLabel.textColor = .systemIndigo
        parentView.addSubview(letterDisplayLabel)

        let instructionsLabel = UILabel()
        instructionsLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionsLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        instructionsLabel.textAlignment = .center
        instructionsLabel.textColor = .secondaryLabel
        instructionsLabel.text = "Type as many cities, countries, or states as you can."
        parentView.addSubview(instructionsLabel)

        plusOneLabel = UILabel()
        plusOneLabel.text = "+1"
        plusOneLabel.font = UIFont.systemFont(ofSize: 36, weight: .heavy)
        plusOneLabel.textColor = .systemYellow
        plusOneLabel.alpha = 0
        plusOneLabel.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(plusOneLabel)

        NSLayoutConstraint.activate([
            timerRingContainer.topAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.topAnchor, constant: 20),
            timerRingContainer.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),
            timerRingContainer.widthAnchor.constraint(equalToConstant: ringDiameter),
            timerRingContainer.heightAnchor.constraint(equalToConstant: ringDiameter),

            timerLabel.centerXAnchor.constraint(equalTo: timerRingContainer.centerXAnchor),
            timerLabel.centerYAnchor.constraint(equalTo: timerRingContainer.centerYAnchor),

            scoreLabel.topAnchor.constraint(equalTo: timerRingContainer.bottomAnchor, constant: 10),
            scoreLabel.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),

            feedbackLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 10),
            feedbackLabel.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),

            letterCaptionLabel.topAnchor.constraint(equalTo: feedbackLabel.bottomAnchor, constant: 20),
            letterCaptionLabel.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),

            letterDisplayLabel.topAnchor.constraint(equalTo: letterCaptionLabel.bottomAnchor, constant: 8),
            letterDisplayLabel.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),

            instructionsLabel.topAnchor.constraint(equalTo: letterDisplayLabel.bottomAnchor, constant: 10),
            instructionsLabel.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),

            inputField.topAnchor.constraint(equalTo: instructionsLabel.bottomAnchor, constant: 20),
            inputField.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 20),
            inputField.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -20),

            submitButton.topAnchor.constraint(equalTo: inputField.bottomAnchor, constant: 10),
            submitButton.centerXAnchor.constraint(equalTo: parentView.centerXAnchor),

            // Plus One Label (floating above input field)
            plusOneLabel.centerXAnchor.constraint(equalTo: inputField.centerXAnchor),
            plusOneLabel.bottomAnchor.constraint(equalTo: inputField.topAnchor, constant: -10),
        ])

        return (
            inputField: inputField,
            submitButton: submitButton,
            timerLabel: timerLabel,
            scoreLabel: scoreLabel,
            feedbackLabel: feedbackLabel,
            letterDisplayLabel: letterDisplayLabel,
            timerRingLayer: timerRingLayer,
            plusOneLabel: plusOneLabel
        )
    }

    static func buildGameOverView(score: Int) -> UIView {
        let gameOverView = UIView()
        gameOverView.backgroundColor = .systemBackground

        let scoreLabel = UILabel()
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        scoreLabel.text = "Score: \(score)"
        scoreLabel.font = UIFont.systemFont(ofSize: 48, weight: .bold)
        scoreLabel.textAlignment = .center
        scoreLabel.textColor = .label

        let feedbackLabel = UILabel()
        feedbackLabel.translatesAutoresizingMaskIntoConstraints = false
        feedbackLabel.text = ""
        feedbackLabel.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        feedbackLabel.textAlignment = .center
        feedbackLabel.textColor = .secondaryLabel
        feedbackLabel.numberOfLines = 0

        gameOverView.addSubview(scoreLabel)
        gameOverView.addSubview(feedbackLabel)

        NSLayoutConstraint.activate([
            scoreLabel.centerXAnchor.constraint(equalTo: gameOverView.centerXAnchor),
            scoreLabel.centerYAnchor.constraint(equalTo: gameOverView.centerYAnchor, constant: -20),

            feedbackLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 12),
            feedbackLabel.centerXAnchor.constraint(equalTo: gameOverView.centerXAnchor),
            feedbackLabel.leadingAnchor.constraint(greaterThanOrEqualTo: gameOverView.leadingAnchor, constant: 20),
            feedbackLabel.trailingAnchor.constraint(lessThanOrEqualTo: gameOverView.trailingAnchor, constant: -20)
        ])

        // Expose feedbackLabel as a stored property on gameOverView using associated object for access if needed
        objc_setAssociatedObject(gameOverView, &AssociatedKeys.feedbackLabelKey, feedbackLabel, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        return gameOverView
    }
}

private struct AssociatedKeys {
    static var feedbackLabelKey = "feedbackLabelKey"
}

extension UIView {
    var feedbackLabel: UILabel? {
        return objc_getAssociatedObject(self, &AssociatedKeys.feedbackLabelKey) as? UILabel
    }
}
