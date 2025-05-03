import UIKit
import CoreData

class DiskUsageViewController: UIViewController, UITableViewDataSource {
    private var usageByCategory: [(name: String, usage: Int64)] = []
    private let tableView = UITableView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        calculateDiskUsage()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Disk Usage"
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func calculateDiskUsage() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let context = appDelegate.persistentContainer.viewContext
        let typeRequest: NSFetchRequest<MeasurementType> = MeasurementType.fetchRequest()
        do {
            let types = try context.fetch(typeRequest)
            var usageList: [(String, Int64)] = []
            for type in types {
                var total: Int64 = 0
                if let entries = type.entries?.allObjects as? [MeasurementEntry] {
                    for entry in entries {
                        if let imageData = entry.image {
                            total += Int64(imageData.count)
                        } else {
                            // Estimate a small size for non-image entries (e.g., value, date, note)
                            let noteSize = Int64(entry.note?.utf8.count ?? 0)
                            total += 32 + noteSize // 32 bytes for value/date
                        }
                    }
                }
                usageList.append((type.name ?? "(Unnamed)", total))
            }
            // Sort by largest usage first
            usageByCategory = usageList.sorted { $0.1 > $1.1 }
            tableView.reloadData()
        } catch {
            usageByCategory = []
        }
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return usageByCategory.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let (name, usage) = usageByCategory[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = name
        content.secondaryText = formatBytes(usage)
        cell.contentConfiguration = content
        return cell
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
} 