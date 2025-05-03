import UIKit

class PrivacyPolicyViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let lastUpdatedLabel = UILabel()
    private let textView = UITextView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Privacy Policy"
        
        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // Configure content view
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Configure title label
        titleLabel.text = "Privacy Policy"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Configure last updated label
        lastUpdatedLabel.text = "Last Updated: April 26, 2024"
        lastUpdatedLabel.font = .systemFont(ofSize: 14)
        lastUpdatedLabel.textColor = .secondaryLabel
        lastUpdatedLabel.textAlignment = .center
        lastUpdatedLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(lastUpdatedLabel)
        
        // Configure text view
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.font = .systemFont(ofSize: 16)
        textView.text = """
        Welcome to OTracker. This Privacy Policy explains how we collect, use, and handle your information when you use our mobile application.

        Effective Date: April 26, 2024

        1. Information We Collect
        - Health Data: The app can access various HealthKit data types at your discretion when you link specific categories. This data is only read during app usage and is not duplicated or stored elsewhere.
        - Local Data: The app stores measurement data locally on your device using Core Data for non-HealthKit categories.
        - No Personal Data: The app does not collect or process any personal identification information.

        2. How We Use Your Information
        - Visualization: To display your health and measurement data in charts and graphs
        - Data Entry: To allow you to input and track your measurements
        - Local Storage: To maintain your measurement history on your device
        - HealthKit Integration: To read and write health data when you explicitly link categories
        - HealthKit Write Access: The app may write data to HealthKit only when you manually input measurements and have authorized the app to write to specific categories.

        3. HealthKit Integration
        - Data Access: We only access HealthKit data types that you explicitly authorize when linking categories
        - Data Storage: Linked categories store their data directly in HealthKit, not in the app's local storage
        - Data Handling: HealthKit data is only accessed during app usage and is not stored or transmitted elsewhere
        - Revocation: You can revoke HealthKit access at any time through your device's settings

        4. Data Storage and Security
        - Local Storage: All data is stored locally on your device using Core Data and HealthKit
        - No Cloud Storage: The app does not transmit or store data on external servers
        - No Data Access: As a developer, I have no access to your local data
        - System Security: Data is protected by iOS's built-in security measures for Core Data and HealthKit
        - Data Retention: Local data is retained on your device until you delete it or uninstall the app

        5. Your Rights and Responsibilities
        - Data Control: You have full control over your data through the app's import/export features
        - Data Backup: You are responsible for backing up your data
        - App Removal: Uninstalling the app will delete Core Data but will not affect HealthKit data
        - Limited Support: Due to the offline nature of the app, data recovery support is limited

        6. Children's Privacy
        Our app is not intended for use by children under the age of 13. We do not knowingly collect personal information from children under 13. If we learn that we have inadvertently collected data from a child under 13, we will take steps to delete such information promptly.

        7. Changes to This Privacy Policy
        We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page. Continued use of the app after any modifications to this Privacy Policy will constitute your acknowledgment and acceptance of the changes.

        8. Contact Us
        If you have any questions about this Privacy Policy, please contact:
        Onat Bas
        otracker@onat.me

        9. GDPR and CCPA Compliance
        As we do not collect or process personal data, the app is not subject to GDPR/CCPA data controller requirements. However, we respect your privacy rights and encourage you to contact us with any concerns.

        By using our app, you acknowledge that:
        - The app is completely offline and local
        - You are responsible for backing up your data
        - The developer cannot access your local data
        - The app is not intended for critical data storage
        """
        textView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textView)
        
        // Set up constraints
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
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            lastUpdatedLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            lastUpdatedLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            lastUpdatedLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            textView.topAnchor.constraint(equalTo: lastUpdatedLabel.bottomAnchor, constant: 20),
            textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
} 