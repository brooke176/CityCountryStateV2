//
//  GameUIBuilder.swift
//  CityCountryState
//
//  Created by Brooke Skinner on 6/22/25.
//

import UIKit

class GameUIBuilder {
    static func build(in parentView: UIView, delegate: UITextFieldDelegate) -> (
        promptLabel: UILabel,
        inputField: UITextField,
        submitButton: UIButton,
        timerLabel: UILabel,
        scoreLabel: UILabel,
        feedbackLabel: UILabel
    ) {
        let promptLabel = UILabel()
        promptLabel.textAlignment = .center
        promptLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        promptLabel.numberOfLines = 0
        promptLabel.textColor = .label

        let inputField = UITextField()
        inputField.placeholder = "Type a place..."
        inputField.borderStyle = .roundedRect
        inputField.backgroundColor = .systemBackground
        inputField.textColor = .label
        inputField.layer.cornerRadius = 10
        inputField.font = UIFont.systemFont(ofSize: 18)
        inputField.delegate = delegate

        let submitButton = UIButton(type: .system)
        submitButton.setTitle("Submit", for: .normal)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        submitButton.backgroundColor = .systemBlue
        submitButton.layer.cornerRadius = 10

        let timerLabel = UILabel()
        timerLabel.textAlignment = .center
        timerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        timerLabel.textColor = .secondaryLabel

        let scoreLabel = UILabel()
        scoreLabel.textAlignment = .center
        scoreLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        scoreLabel.textColor = .secondaryLabel

        let feedbackLabel = UILabel()
        feedbackLabel.textAlignment = .center
        feedbackLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        feedbackLabel.textColor = .tertiaryLabel
        feedbackLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [
            promptLabel,
            inputField,
            submitButton,
            timerLabel,
            scoreLabel,
            feedbackLabel
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        parentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: parentView.centerYAnchor)
        ])

        return (promptLabel, inputField, submitButton, timerLabel, scoreLabel, feedbackLabel)
    }
}
