import UIKit
import CoreData

class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView()
    private let settingsItems = [
        "App Version",
        "Contact",
        "Import",
        "Export",
        "Disk Usage",
        "Privacy Policy",
        "Terms of Service",
        "Data Collection",
        "Delete All Core Data"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Settings"
        
        // Configure table view
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingsItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        let item = settingsItems[indexPath.row]
        content.text = item
        
        // Add disclosure indicator for all items except App Version and Delete All Core Data
        if item != "App Version" && item != "Delete All Core Data" {
            cell.accessoryType = .disclosureIndicator
        } else {
            cell.accessoryType = .none
        }
        
        // For App Version, show the version number
        if item == "App Version" {
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                content.secondaryText = version
            }
        }
        // For Delete All Core Data, make the text red
        if item == "Delete All Core Data" {
            content.textProperties.color = .systemRed
        }
        
        cell.contentConfiguration = content
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = settingsItems[indexPath.row]
        
        switch item {
        case "App Version":
            // Show app version
            break
        case "Contact":
            let contactVC = ContactViewController()
            navigationController?.pushViewController(contactVC, animated: true)
            break
        case "Import":
            let importVC = ImportViewController()
            navigationController?.pushViewController(importVC, animated: true)
            break
        case "Export":
            let exportVC = ExportViewController()
            navigationController?.pushViewController(exportVC, animated: true)
            break
        case "Disk Usage":
            let diskVC = DiskUsageViewController()
            navigationController?.pushViewController(diskVC, animated: true)
            break
        case "Privacy Policy":
            let privacyVC = PrivacyPolicyViewController()
            navigationController?.pushViewController(privacyVC, animated: true)
            break
        case "Terms of Service":
            let termsVC = TermsOfServiceViewController()
            navigationController?.pushViewController(termsVC, animated: true)
            break
        case "Data Collection":
            let dataVC = DataCollectionViewController()
            navigationController?.pushViewController(dataVC, animated: true)
            break
        case "Delete All Core Data":
            let alert = UIAlertController(title: "Delete All Data?", message: "This will permanently delete all your measurement types and entries. This action cannot be undone.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
                self?.deleteAllCoreData()
            })
            present(alert, animated: true)
            break
        default:
            break
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    private func deleteAllCoreData() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let context = appDelegate.persistentContainer.viewContext
        let typesRequest: NSFetchRequest<NSFetchRequestResult> = MeasurementType.fetchRequest()
        let entriesRequest: NSFetchRequest<NSFetchRequestResult> = MeasurementEntry.fetchRequest()
        let batchDeleteTypes = NSBatchDeleteRequest(fetchRequest: typesRequest)
        let batchDeleteEntries = NSBatchDeleteRequest(fetchRequest: entriesRequest)
        do {
            try context.execute(batchDeleteEntries)
            try context.execute(batchDeleteTypes)
            try context.save()
        } catch {
            let errorAlert = UIAlertController(title: "Error", message: "Failed to delete all data: \(error.localizedDescription)", preferredStyle: .alert)
            errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
            present(errorAlert, animated: true)
            return
        }
        let doneAlert = UIAlertController(title: "All Data Deleted", message: "All Core Data has been deleted.", preferredStyle: .alert)
        doneAlert.addAction(UIAlertAction(title: "OK", style: .default))
        present(doneAlert, animated: true)
        tableView.reloadData()
    }
} 