import UIKit
import Messages

class BattleRoomManager: NSObject, UITableViewDataSource, UITableViewDelegate {
private weak var viewController: MessagesViewController?
private let playerNameKey = "playerName"

struct Player {
    let id: String
    var name: String
    var isReady: Bool
}

private var players: [Player] = []
private let localPlayerIDKey = "localPlayerID"

private var localPlayerID: String {
    if let saved = UserDefaults.standard.string(forKey: localPlayerIDKey) {
        return saved
    } else {
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: localPlayerIDKey)
        return newID
    }
}
private weak var tableView: UITableView?
private weak var startButton: UIButton?
private weak var instructionLabel: UILabel?

private var savedLocalPlayerName: String? {
    UserDefaults.standard.string(forKey: playerNameKey)
}

init(viewController: MessagesViewController) {
    self.viewController = viewController
    super.init()
}

func joinRoom(from url: URL?) {
    print("Attempting to join room")
    players = []
    
    guard let url = url else {
        print("No URL provided - creating new room")
        players.append(Player(id: localPlayerID, name: savedLocalPlayerName ?? "You", isReady: false))
        showWaitingRoom()
        return
    }
    
    print("Joining room with URL: \(url)")
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        print("Failed to create URLComponents from URL")
//            players.append(Player(id: localPlayerID, name: "You", isReady: false))
        showWaitingRoom()
        return
    }
    
    guard let queryItems = components.queryItems else {
        print("No query items found in URL")
        players.append(Player(id: localPlayerID, name: "You", isReady: false))
        showWaitingRoom()
        return
    }
    
    var existingPlayers: [Player] = []
    for item in queryItems {
        if item.name.hasSuffix("id"),
           let playerId = item.value,
           let nameItem = queryItems.first(where: { $0.name == "\(item.name.dropLast(2))name" }),
           let name = nameItem.value,
           let readyItem = queryItems.first(where: { $0.name == "\(item.name.dropLast(2))ready" }),
           let readyStr = readyItem.value {
            let isReady = (readyStr == "true")
            existingPlayers.append(Player(id: playerId, name: name, isReady: isReady))
        }
    }
    
    players = existingPlayers
    if players.first(where: { $0.id == localPlayerID }) == nil {
        var defaultName = UserDefaults.standard.string(forKey: playerNameKey) ?? "You"
        // If defaultName already exists in players, disambiguate
        if players.contains(where: { $0.name == defaultName }) {
            defaultName += " (You)"
        }
        players.append(Player(id: localPlayerID, name: defaultName, isReady: false))
        if let conversation = viewController?.activeConversation {
            var components = URLComponents()
            components.queryItems = [
                URLQueryItem(name: "mode", value: "battle"),
                URLQueryItem(name: "type", value: "playerJoin"),
                URLQueryItem(name: "playerId", value: localPlayerID),
                URLQueryItem(name: "name", value: defaultName),
                URLQueryItem(name: "isReady", value: "false")
            ]
            
            conversation.selectedMessage?.url = components.url
        }
    }
    print("Players in room: \(players.map { $0.name })")
    
    showWaitingRoom()
}

func sendInviteMessage(in conversation: MSConversation) {
    var components = URLComponents()
    components.queryItems = [
        URLQueryItem(name: "mode", value: "battle"),
        URLQueryItem(name: "player1name", value: savedLocalPlayerName),
        URLQueryItem(name: "player1ready", value: "false"),
        URLQueryItem(name: "player1id", value: localPlayerID)
    ]

    let layout = MSMessageTemplateLayout()
    layout.caption = "LET’S PLAY CITY COUNTRY STATE!"
    layout.image = UIImage(named: "newimage")
    layout.subcaption = "Join the battle!"
    
    let message = MSMessage()
    message.layout = layout
    message.url = components.url
    
    conversation.insert(message) { error in
        if let error = error {
            print("Error sending battle invite: \(error.localizedDescription)")
        } else {
            print("Battle invite sent successfully")
        }
    }
}

func leaveRoom() {
    if let conversation = viewController?.activeConversation {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "mode", value: "battle"),
            URLQueryItem(name: "type", value: "playerLeave"),
            URLQueryItem(name: "playerId", value: localPlayerID)
        ]
        conversation.selectedMessage?.url = components.url
    }
    players.removeAll(where: { $0.id == localPlayerID })
    tableView?.reloadData()
}

func presentationStyleChanged(to style: MSMessagesAppPresentationStyle) {
    if style == .compact {
        leaveRoom()
    }
}

private func showWaitingRoom() {
    guard let vc = viewController else { return }
    vc.clearModeSpecificUI()

    vc.view.backgroundColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1) // deep red background

    let titleLabel = UILabel()
    titleLabel.text = "Battle Waiting Room"
    titleLabel.textAlignment = .center
    titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
    titleLabel.textColor = .white
    titleLabel.translatesAutoresizingMaskIntoConstraints = false

    // Container view for centering tableView vertically and limiting width
    let containerView = UIView()
    containerView.translatesAutoresizingMaskIntoConstraints = false
    containerView.backgroundColor = .clear

    let tableView = UITableView()
    tableView.dataSource = self
    tableView.delegate = self
    tableView.register(WaitingRoomPlayerCell.self, forCellReuseIdentifier: "playerCell")
    tableView.translatesAutoresizingMaskIntoConstraints = false
    tableView.backgroundColor = .clear
    tableView.separatorStyle = .none

    let instructionLabel = UILabel()
    instructionLabel.text = "Tap \"READY\" to start the match"
    instructionLabel.textColor = .white
    instructionLabel.font = UIFont.boldSystemFont(ofSize: 14)
    instructionLabel.textAlignment = .center
    instructionLabel.translatesAutoresizingMaskIntoConstraints = false

    let startButton = UIButton(type: .system)
    startButton.setTitle("READY", for: .normal)
    startButton.setTitleColor(.white, for: .normal)
    startButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
    startButton.backgroundColor = UIColor(red: 0, green: 0.6, blue: 0, alpha: 1) // green
    startButton.layer.cornerRadius = 12
    startButton.clipsToBounds = true
    startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
    startButton.translatesAutoresizingMaskIntoConstraints = false

    vc.view.addSubview(titleLabel)
    vc.view.addSubview(containerView)
    vc.view.addSubview(instructionLabel)
    vc.view.addSubview(startButton)
    containerView.addSubview(tableView)

    // Layout constants
    let horizontalPadding: CGFloat = 20
    let tableViewMaxWidth: CGFloat = 400
    let tableViewHeight: CGFloat = 60 * CGFloat(max(players.count, 1)) // 60pt per cell, at least 1 row
    let tableViewMinHeight: CGFloat = 60
    let tableViewSideInset: CGFloat = 16

    NSLayoutConstraint.activate([
        titleLabel.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor, constant: 20),
        titleLabel.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 20),
        titleLabel.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -20),

        // Center containerView vertically in view, below title
        containerView.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
        containerView.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
        // containerView width is at most view width minus horizontalPadding*2, and at most tableViewMaxWidth
        containerView.widthAnchor.constraint(lessThanOrEqualTo: vc.view.widthAnchor, constant: -(horizontalPadding * 2)),
        containerView.widthAnchor.constraint(lessThanOrEqualToConstant: tableViewMaxWidth),
        // containerView top at least below title
        containerView.topAnchor.constraint(greaterThanOrEqualTo: titleLabel.bottomAnchor, constant: 20),

        // TableView fills containerView, with side insets to prevent cells from spanning full width
        tableView.topAnchor.constraint(equalTo: containerView.topAnchor),
        tableView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        tableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: tableViewSideInset),
        tableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -tableViewSideInset),
        // TableView fixed height (at least one row, up to the number of players)
        tableView.heightAnchor.constraint(equalToConstant: max(tableViewMinHeight, CGFloat(players.count) * 60)),
        // TableView width is less than containerView width minus insets
        tableView.widthAnchor.constraint(lessThanOrEqualTo: containerView.widthAnchor, constant: -(tableViewSideInset * 2)),

        instructionLabel.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 20),
        instructionLabel.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -20),
        instructionLabel.bottomAnchor.constraint(equalTo: startButton.topAnchor, constant: -10),

        startButton.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
        startButton.widthAnchor.constraint(equalToConstant: 140),
        startButton.heightAnchor.constraint(equalToConstant: 44),
        startButton.bottomAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
    ])

    self.tableView = tableView
    self.startButton = startButton
    self.instructionLabel = instructionLabel
}

@objc private func startButtonTapped() {
    guard let localIndex = players.firstIndex(where: { $0.id == localPlayerID }) else { return }
    let isCurrentlyReady = players[localIndex].isReady
    toggleReady(forPlayerAt: localIndex, isReady: !isCurrentlyReady)
}

// MARK: - UITableViewDataSource
func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return players.count
}

func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(withIdentifier: "playerCell", for: indexPath) as? WaitingRoomPlayerCell else {
        return UITableViewCell()
    }
    
    let player = players[indexPath.row]
    let isLocal = player.id == localPlayerID
    cell.configure(with: player, isLocalPlayer: isLocal, savedName: isLocal ? savedLocalPlayerName : nil)
    cell.readyToggleChanged = { [weak self] isReady in
        self?.toggleReady(forPlayerAt: indexPath.row, isReady: isReady)
    }
    cell.nameChanged = { [weak self] newName in
        self?.updatePlayerName(at: indexPath.row, newName: newName)
    }
    return cell
}

private func toggleReady(forPlayerAt index: Int, isReady: Bool) {
    guard players.indices.contains(index) else { return }
    players[index].isReady = isReady

    // Send ready state update to other players
    if let conversation = viewController?.activeConversation {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "mode", value: "battle"),
            URLQueryItem(name: "type", value: "playerReady"),
            URLQueryItem(name: "playerId", value: players[index].id),
            URLQueryItem(name: "isReady", value: isReady ? "true" : "false")
        ]
        conversation.selectedMessage?.url = components.url
    }

    // Update instruction label and button based on number of players and readiness
    let localPlayerCount = players.count
    let allReady = players.count > 1 && players.allSatisfy { $0.isReady }
    if let instructionLabel = self.instructionLabel, let startButton = self.startButton {
        if localPlayerCount == 1 && players[index].id == localPlayerID && isReady {
            // Only 1 player, local toggles ready
            startButton.backgroundColor = UIColor(red: 0.7, green: 0, blue: 0, alpha: 1) // red
            startButton.setTitle("CANCEL", for: .normal)
            instructionLabel.text = "Waiting for other players to join"
        } else if localPlayerCount == 1 && players[index].id == localPlayerID && !isReady {
            // Only 1 player, local toggles not ready
            startButton.backgroundColor = UIColor(red: 0, green: 0.6, blue: 0, alpha: 1) // green
            startButton.setTitle("READY", for: .normal)
            instructionLabel.text = "Tap \"READY\" to start the match"
        } else if localPlayerCount >= 2 {
            // 2+ players
            startButton.backgroundColor = UIColor(red: 0, green: 0.6, blue: 0, alpha: 1) // green
            startButton.setTitle("READY", for: .normal)
            if allReady {
                instructionLabel.text = "All players ready! Starting..."
            } else {
                instructionLabel.text = "Tap \"READY\" to start the match"
            }
        }
    }

    // Start game if 2+ players and all are ready
    if players.count >= 2 && players.allSatisfy({ $0.isReady }) {
        let playerNames = players.map { $0.name }
        viewController?.startBattleMode(with: playerNames)
    }

    tableView?.reloadData()
}

private func updatePlayerName(at index: Int, newName: String) {
    guard players.indices.contains(index) else { return }
    let nameToSave = newName.isEmpty ? "You" : newName
    players[index].name = nameToSave
    
    if players[index].id == localPlayerID {
        UserDefaults.standard.set(nameToSave, forKey: playerNameKey)
    }

    // Broadcast the name change to other participants
    if let conversation = viewController?.activeConversation {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "mode", value: "battle"),
            URLQueryItem(name: "type", value: "playerName"),
            URLQueryItem(name: "playerId", value: players[index].id),
            URLQueryItem(name: "name", value: nameToSave)
        ]
        conversation.selectedMessage?.url = components.url
    }
}

// MARK: - Message Handling
func handleIncomingMessage(components: URLComponents) {
    guard let messageType = components.queryItems?.first(where: { $0.name == "type" })?.value else {
        return
    }
    
    switch messageType {
    case "playerReady":
        if let playerId = components.queryItems?.first(where: { $0.name == "playerId" })?.value,
           let isReadyStr = components.queryItems?.first(where: { $0.name == "isReady" })?.value {
            let isReady = (isReadyStr == "true")
            updatePlayerReadyStatus(playerId: playerId, isReady: isReady)
        }
        
    case "playerName":
        if let playerId = components.queryItems?.first(where: { $0.name == "playerId" })?.value,
           let newName = components.queryItems?.first(where: { $0.name == "name" })?.value {
            updatePlayerName(playerId: playerId, newName: newName)
        }
    case "playerJoin":
        if let playerId = components.queryItems?.first(where: { $0.name == "playerId" })?.value,
           let name = components.queryItems?.first(where: { $0.name == "name" })?.value,
           let isReadyStr = components.queryItems?.first(where: { $0.name == "isReady" })?.value {
            
            let isReady = (isReadyStr == "true")
            if players.contains(where: { $0.id == playerId }) == false {
                players.append(Player(id: playerId, name: name, isReady: isReady))
                tableView?.reloadData()
            }
        }
    case "playerLeave":
        if let playerId = components.queryItems?.first(where: { $0.name == "playerId" })?.value {
            players.removeAll(where: { $0.id == playerId })
            tableView?.reloadData()
        }
    default:
        break
    }
}

private func updatePlayerReadyStatus(playerId: String, isReady: Bool) {
    if let index = players.firstIndex(where: { $0.id == playerId }) {
        players[index].isReady = isReady
        tableView?.reloadData()
        let readyPlayers = players.filter { $0.isReady }
        if readyPlayers.count >= 2 {
            let playerNames = readyPlayers.map { $0.name }
            viewController?.startBattleMode(with: playerNames)
        }
    }
}

private func updatePlayerName(playerId: String, newName: String) {
    if let index = players.firstIndex(where: { $0.id == playerId }) {
        players[index].name = newName
        tableView?.reloadData()
    }
}
}

class WaitingRoomPlayerCell: UITableViewCell {
private let avatarImageView = UIImageView()
private let nameLabel = UITextField()
private let readySwitch = UISwitch()
var readyToggleChanged: ((Bool) -> Void)?
var nameChanged: ((String) -> Void)?

override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    backgroundColor = .clear
    contentView.backgroundColor = .white
    contentView.layer.cornerRadius = 12
    contentView.clipsToBounds = true
    
    avatarImageView.translatesAutoresizingMaskIntoConstraints = false
    avatarImageView.contentMode = .scaleAspectFit
    avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")?.withRenderingMode(.alwaysTemplate)
    avatarImageView.tintColor = UIColor.systemGray3
    
    nameLabel.translatesAutoresizingMaskIntoConstraints = false
    nameLabel.textAlignment = .center
    nameLabel.font = UIFont.boldSystemFont(ofSize: 16)
    nameLabel.borderStyle = .none
    nameLabel.backgroundColor = .clear
    nameLabel.autocorrectionType = .no
    nameLabel.autocapitalizationType = .words
    
    readySwitch.translatesAutoresizingMaskIntoConstraints = false
    
    contentView.addSubview(avatarImageView)
    contentView.addSubview(nameLabel)
    contentView.addSubview(readySwitch)

    NSLayoutConstraint.activate([
        avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
        avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        avatarImageView.widthAnchor.constraint(equalToConstant: 40),
        avatarImageView.heightAnchor.constraint(equalToConstant: 40),
        
        nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
        nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        
        readySwitch.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 12),
        readySwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
        readySwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        
        nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: readySwitch.leadingAnchor, constant: -12)
    ])

    readySwitch.addTarget(self, action: #selector(readySwitchChanged), for: .valueChanged)
    nameLabel.addTarget(self, action: #selector(nameFieldChanged), for: .editingChanged)
}

required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
}

func configure(with player: BattleRoomManager.Player, isLocalPlayer: Bool, savedName: String?) {
    if isLocalPlayer, let savedName = savedName {
        nameLabel.text = savedName
    } else {
        nameLabel.text = player.name
    }
    nameLabel.isUserInteractionEnabled = isLocalPlayer
    nameLabel.textColor = isLocalPlayer ? .black : .darkGray
    readySwitch.isOn = player.isReady
    readySwitch.isEnabled = isLocalPlayer
}

@objc private func readySwitchChanged() {
    readyToggleChanged?(readySwitch.isOn)
}

@objc private func nameFieldChanged() {
    nameChanged?(nameLabel.text ?? "")
}
}
