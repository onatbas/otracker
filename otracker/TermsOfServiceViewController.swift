import UIKit

class TermsOfServiceViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Terms of Service"
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        let titleLabel = UILabel()
        titleLabel.text = "Terms of Service"
        titleLabel.font = .boldSystemFont(ofSize: 28)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let termsTextView = UITextView()
        termsTextView.text = "Terms of Service\n\nEffective Date: April 26, 2024\n\nWelcome to OTracker! By using this app, you agree to the following terms and conditions. If you do not agree, please do not use the app.\n\n1. Acceptance of Terms\nBy downloading or using OTracker, you accept these Terms of Service and our Privacy Policy. Continued use of the app after updates to these terms constitutes your acceptance of the changes.\n\n2. About the App\nOTracker is a personal health tracking tool developed and maintained by a single independent developer. It is provided as-is, with no guarantees of accuracy, reliability, or fitness for any particular purpose. Support is limited and responses may be delayed.\n\n3. Use of the App\nOTracker is intended for personal, non-commercial use only. You may not use the app for illegal or unauthorized purposes.\n\n4. Health Disclaimer\nOTracker is not a medical device and is not intended to diagnose, treat, cure, or prevent any health condition. It is for general tracking and visualization only. Always consult a healthcare professional before making medical decisions based on app data.\n\n5. Data Handling and User Responsibility\nAll data is stored locally on your device.\nThe app does not collect, transmit, or access personal data.\nYou are fully responsible for managing and backing up your own data.\nThe developer cannot recover lost or deleted data.\n\n6. Compliance\nYou are solely responsible for ensuring that your use of OTracker complies with any applicable laws or regulations in your jurisdiction.\n\n7. Intellectual Property\nAll content, design, and code in OTracker is the intellectual property of the developer, unless otherwise noted. You may not copy, modify, or distribute any part of the app without permission.\n\n8. Limitation of Liability\nThe developer is not liable for any direct, indirect, incidental, or consequential damages arising out of or in connection with your use of the app. Use OTracker at your own risk.\n\n9. Termination\nYou may stop using OTracker at any time. The developer reserves the right to modify or discontinue the app at any time without notice or liability.\n\n10. Changes to These Terms\nThese Terms may be updated periodically. You are responsible for reviewing them, and continued use of the app constitutes acceptance of any changes.\n\n11. Contact\nIf you have any questions or concerns about these Terms, you can contact:\nEmail: otracker@onat.me"
        termsTextView.font = .systemFont(ofSize: 16)
        termsTextView.isEditable = false
        termsTextView.isSelectable = true
        termsTextView.backgroundColor = .clear
        termsTextView.textColor = .label
        termsTextView.translatesAutoresizingMaskIntoConstraints = false
        termsTextView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        termsTextView.isScrollEnabled = false
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(termsTextView)
        
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
            
            termsTextView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            termsTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            termsTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            termsTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
    }
} 