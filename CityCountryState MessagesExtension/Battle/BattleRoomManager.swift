import UIKit
import Messages

class BattleRoomManager: NSObject, UITableViewDataSource, UITableViewDelegate {
    private weak var viewController: MessagesViewController?
    
    struct Player {
        let id: String
        var name: String
        var isReady: Bool
    }
    
    struct LocalPlayerSettings {
        static var name: String {
            get { UserDefaults.standard.string(forKey: "localPlayerName") ?? "You" }
            set { UserDefaults.standard.set(newValue, forKey: "localPlayerName") }
        }

        static let id: String = UUID().uuidString
    }
    
    private var players: [Player] = []
    private var localPlayerID: String = LocalPlayerSettings.id
    private var gameStarted = false
    private weak var tableView: UITableView?
    private weak var startButton: UIButton?

    init(viewController: MessagesViewController) {
        self.viewController = viewController
    }
    
    private func showWaitingRoom() {
        guard let vc = viewController else { return }

        vc.view.subviews.forEach { $0.removeFromSuperview() }

        let titleLabel = UILabel()
        titleLabel.text = "Battle Waiting Room"
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(titleLabel)

        let startButton = UIButton(type: .system)
        startButton.setTitle("Start Game", for: .normal)
//        startButton.isEnabled = players.filter { $0.isReady }.count >= 2
        startButton.addTarget(self, action: #selector(startGameTapped), for: .touchUpInside)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(startButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),

            startButton.bottomAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            startButton.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor)
        ])

        if tableView == nil {
            let tableView = UITableView()
            tableView.translatesAutoresizingMaskIntoConstraints = false
            tableView.dataSource = self
            tableView.delegate = self
            tableView.register(WaitingRoomPlayerCell.self, forCellReuseIdentifier: "playerCell")
            vc.view.addSubview(tableView)
            self.tableView = tableView

            NSLayoutConstraint.activate([
                tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
                tableView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
                tableView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
                tableView.bottomAnchor.constraint(equalTo: startButton.topAnchor, constant: -10),
            ])
        }

        tableView?.reloadData()
        self.startButton = startButton
    }
    
    func joinRoom(from url: URL?) {
        players = []
        
        guard let url = url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            // No existing players, add local player as not ready
            players.append(Player(id: localPlayerID, name: LocalPlayerSettings.name, isReady: false))
            showWaitingRoom()
            return
        }
        
        var existingPlayers: [Player] = []
        for i in 1...10 {
            if let name = queryItems.first(where: { $0.name == "player\(i)name" })?.value,
               let readyStr = queryItems.first(where: { $0.name == "player\(i)ready" })?.value {
                let isReady = (readyStr == "true")
                let id = "player\(i)"
                existingPlayers.append(Player(id: id, name: name, isReady: isReady))
            }
        }
        
        if existingPlayers.firstIndex(where: { $0.id == localPlayerID }) != nil {
            players = existingPlayers
        } else {
            players = existingPlayers
            players.append(Player(id: localPlayerID, name: LocalPlayerSettings.name, isReady: false))
        }
        showWaitingRoom()
    }
    
    @objc private func startGameTapped() {
        guard let vc = viewController else { return }
        let playerNames = players.map { $0.name }
        vc.startBattleMode(with: playerNames)
    }
    
    func toggleReady(forPlayerAt index: Int, isReady: Bool) {
        guard players.indices.contains(index) else { return }
        players[index].isReady = isReady
//        startButton?.isEnabled = players.filter { $0.isReady }.count >= 2
        tableView?.reloadData()
        sendWaitingRoomMessage()
    }
    
    private func sendWaitingRoomMessage() {
        guard let conversation = viewController?.activeConversation else { return }
        guard players.count > 1 else { return }

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "mode", value: "battle"),
            URLQueryItem(name: "players", value: "\(players.count)")
        ]

        for (index, player) in players.enumerated() {
            components.queryItems?.append(URLQueryItem(name: "player\(index+1)name", value: player.name))
            components.queryItems?.append(URLQueryItem(name: "player\(index+1)ready", value: player.isReady ? "true" : "false"))
        }

        let layout = MSMessageTemplateLayout()
        layout.caption = "Battle Room: \(players.count) player(s), \(players.filter { $0.isReady }.count) ready"

        let message = MSMessage()
        message.layout = layout
        message.url = components.url

        conversation.insert(message) { error in
            if let error = error {
                print("Failed to send waiting room message:", error)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return players.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "playerCell", for: indexPath) as? WaitingRoomPlayerCell else {
            return UITableViewCell()
        }

        let player = players[indexPath.row]
        cell.nameChanged = { [weak self] newName in
            guard let self = self else { return }
            let finalName = newName.isEmpty ? "You" : newName
            self.players[indexPath.row].name = finalName

            if self.players[indexPath.row].id == self.localPlayerID {
                LocalPlayerSettings.name = finalName
            }

            self.sendWaitingRoomMessage()
        }
        cell.configure(with: player, isLocalPlayer: player.id == localPlayerID)
        cell.readyToggleChanged = { [weak self] isReady in
            self?.toggleReady(forPlayerAt: indexPath.row, isReady: isReady)
        }
        return cell
    }
}

class WaitingRoomPlayerCell: UITableViewCell {
    private let nameField = UITextField()
    private let readySwitch = UISwitch()
    var readyToggleChanged: ((Bool) -> Void)?
    var nameChanged: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(nameField)
        contentView.addSubview(readySwitch)

        nameField.borderStyle = .roundedRect
        nameField.translatesAutoresizingMaskIntoConstraints = false
        readySwitch.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            nameField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameField.trailingAnchor.constraint(equalTo: readySwitch.leadingAnchor, constant: -10),

            readySwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            readySwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        readySwitch.addTarget(self, action: #selector(readySwitchChanged), for: .valueChanged)
        nameField.addTarget(self, action: #selector(nameFieldChanged), for: .editingChanged)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with player: BattleRoomManager.Player, isLocalPlayer: Bool) {
        nameField.text = player.name
        nameField.isEnabled = isLocalPlayer
        nameField.textColor = isLocalPlayer ? .label : .secondaryLabel
        readySwitch.isOn = player.isReady
        readySwitch.isEnabled = isLocalPlayer
    }

    @objc private func readySwitchChanged() {
        readyToggleChanged?(readySwitch.isOn)
    }

    @objc private func nameFieldChanged() {
        nameChanged?(nameField.text ?? "")
    }
}
import UIKit
import Messages

class BattleRoomManager: NSObject, UITableViewDataSource, UITableViewDelegate {
    private weak var viewController: MessagesViewController?
    
    struct Player {
        let id: String
        var name: String
        var isReady: Bool
    }
    
    private var players: [Player] = []
    private var localPlayerID: String = UUID().uuidString
    private weak var tableView: UITableView?
    private weak var startButton: UIButton?
    
    init(viewController: MessagesViewController) {
        self.viewController = viewController
        super.init()
    }
    
    func joinRoom(from url: URL?) {
        players = []
        
        guard let url = url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            players.append(Player(id: localPlayerID, name: "You", isReady: false))
            showWaitingRoom()
            return
        }
        
        var existingPlayers: [Player] = []
        for i in 1...10 {
            if let name = queryItems.first(where: { $0.name == "player\(i)name" })?.value,
               let readyStr = queryItems.first(where: { $0.name == "player\(i)ready" })?.value {
                let isReady = (readyStr == "true")
                let id = "player\(i)"
                existingPlayers.append(Player(id: id, name: name, isReady: isReady))
            }
        }
        
        players = existingPlayers
        if !players.contains(where: { $0.id == localPlayerID }) {
            players.append(Player(id: localPlayerID, name: "You", isReady: false))
        }
        
        showWaitingRoom()
    }
    
    func sendInviteMessage(in conversation: MSConversation) {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "mode", value: "battle"),
            URLQueryItem(name: "player1name", value: "You"),
            URLQueryItem(name: "player1ready", value: "false")
        ]

        let layout = MSMessageTemplateLayout()
        layout.caption = "Join the Battle Waiting Room!"
        
        let message = MSMessage()
        message.layout = layout
        message.url = components.url
        
        conversation.insert(message, completionHandler: nil)
    }
    
    private func showWaitingRoom() {
        guard let vc = viewController else { return }
        vc.clearModeSpecificUI()
        
        let titleLabel = UILabel()
        titleLabel.text = "Battle Waiting Room"
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let tableView = UITableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(WaitingRoomPlayerCell.self, forCellReuseIdentifier: "playerCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        let startButton = UIButton(type: .system)
        startButton.setTitle("Start Game", for: .normal)
        startButton.addTarget(self, action: #selector(startGameTapped), for: .touchUpInside)
        startButton.isEnabled = players.filter { $0.isReady }.count >= 2
        startButton.translatesAutoresizingMaskIntoConstraints = false
        
        vc.view.addSubview(titleLabel)
        vc.view.addSubview(tableView)
        vc.view.addSubview(startButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -20),
            
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            tableView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: startButton.topAnchor, constant: -20),
            
            startButton.bottomAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            startButton.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor)
        ])
        
        self.tableView = tableView
        self.startButton = startButton
    }
    
    @objc private func startGameTapped() {
        guard let vc = viewController else { return }
        let playerNames = players.map { $0.name }
        vc.startBattleMode(with: playerNames)
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
        cell.configure(with: player, isLocalPlayer: player.id == localPlayerID)
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
        startButton?.isEnabled = players.filter { $0.isReady }.count >= 2
        tableView?.reloadData()
    }
    
    private func updatePlayerName(at index: Int, newName: String) {
        guard players.indices.contains(index) else { return }
        players[index].name = newName.isEmpty ? "You" : newName
    }
}
