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
