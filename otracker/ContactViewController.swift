import UIKit

class ContactViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Contact Us"
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        let titleLabel = UILabel()
        titleLabel.text = "Contact Us"
        titleLabel.font = .boldSystemFont(ofSize: 28)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let infoLabel = UILabel()
        infoLabel.text = "OTracker is a small, independent project developed and maintained by a single developer.\n\nIf you have questions, feedback, or privacy concerns, you can reach out at:"
        infoLabel.font = .systemFont(ofSize: 17)
        infoLabel.numberOfLines = 0
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let nameLabel = UILabel()
        nameLabel.text = "Name: Onat Bas"
        nameLabel.font = .systemFont(ofSize: 17, weight: .medium)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let emailLabel = UILabel()
        emailLabel.text = "Email: otracker@onat.me"
        emailLabel.font = .systemFont(ofSize: 17, weight: .medium)
        emailLabel.textColor = .systemBlue
        emailLabel.translatesAutoresizingMaskIntoConstraints = false
        emailLabel.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(emailTapped))
        emailLabel.addGestureRecognizer(tap)
        
        let noteLabel = UILabel()
        noteLabel.text = "Please note:\n\n• This is a part-time, low-maintenance project.\n• While I'll do my best to respond, replies may be delayed.\n• Due to the app's offline nature, I cannot offer data recovery or technical support for lost data.\n\nThanks for understanding and for using OTracker!"
        noteLabel.font = .systemFont(ofSize: 16)
        noteLabel.numberOfLines = 0
        noteLabel.textColor = .secondaryLabel
        noteLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(infoLabel)
        contentView.addSubview(nameLabel)
        contentView.addSubview(emailLabel)
        contentView.addSubview(noteLabel)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            
            infoLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            infoLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            infoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            
            nameLabel.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 24),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            
            emailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            emailLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            emailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            
            noteLabel.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: 32),
            noteLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            noteLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            noteLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
    }
    
    @objc private func emailTapped() {
        if let url = URL(string: "mailto:otracker@onat.me") {
            UIApplication.shared.open(url)
        }
    }
} 