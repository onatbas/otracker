import UIKit
import CoreData
import ZIPFoundation

class ExportViewController: UIViewController {
    private let context: NSManagedObjectContext
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()
    
    init() {
        self.context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        exportData()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Export Data"
        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        view.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func exportData() {
        activityIndicator.startAnimating()
        statusLabel.text = "Preparing data for export..."
        
        // Create a temporary directory
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("otracker_export")
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            showError("Failed to create temporary directory")
            return
        }
        
        // Export Core Data to JSON
        let measurementTypesRequest: NSFetchRequest<MeasurementType> = MeasurementType.fetchRequest()
        let entriesRequest: NSFetchRequest<MeasurementEntry> = MeasurementEntry.fetchRequest()
        
        do {
            let types = try context.fetch(measurementTypesRequest)
            let entries = try context.fetch(entriesRequest)
            
            // Convert to dictionaries
            let typesData = types.map { type -> [String: Any] in
                var dict: [String: Any] = [:]
                dict["name"] = type.name
                dict["unit"] = type.unit
                dict["color"] = type.color
                dict["isFormula"] = type.isFormula
                dict["formula"] = type.formula
                dict["dependencies"] = type.dependencies
                dict["healthKitIdentifier"] = type.healthKitIdentifier
                dict["isVisible"] = type.isVisible
                return dict
            }
            
            let entriesData = entries.map { entry -> [String: Any] in
                var dict: [String: Any] = [:]
                dict["value"] = entry.value
                dict["timestamp"] = entry.timestamp?.timeIntervalSince1970
                dict["note"] = entry.note
                dict["typeName"] = entry.type?.name
                if let imageData = entry.image {
                    // Save image to file
                    let imageName = "\(entry.objectID.uriRepresentation().lastPathComponent).jpg"
                    let imagePath = tempDir.appendingPathComponent(imageName)
                    try? imageData.write(to: imagePath)
                    dict["image"] = imageName
                }
                return dict
            }
            
            // Write JSON files
            let typesPath = tempDir.appendingPathComponent("measurement_types.json")
            let entriesPath = tempDir.appendingPathComponent("measurement_entries.json")
            
            let typesJSON = try JSONSerialization.data(withJSONObject: typesData, options: .prettyPrinted)
            let entriesJSON = try JSONSerialization.data(withJSONObject: entriesData, options: .prettyPrinted)
            
            try typesJSON.write(to: typesPath)
            try entriesJSON.write(to: entriesPath)
            
            // Create ZIP file
            let zipPath = FileManager.default.temporaryDirectory.appendingPathComponent("otracker_export.zip")
            try? FileManager.default.removeItem(at: zipPath) // Remove if exists
            
            try FileManager.default.zipItem(at: tempDir, to: zipPath)
            
            // Clean up temp directory
            try? FileManager.default.removeItem(at: tempDir)
            
            // Share the ZIP file
            DispatchQueue.main.async { [weak self] in
                self?.activityIndicator.stopAnimating()
                self?.shareFile(at: zipPath)
            }
            
        } catch {
            showError("Failed to export data: \(error.localizedDescription)")
        }
    }
    
    private func shareFile(at url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.completionWithItemsHandler = { [weak self] _, _, _, _ in
            // Clean up the ZIP file after sharing
            try? FileManager.default.removeItem(at: url)
            self?.navigationController?.popViewController(animated: true)
        }
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
        
        present(activityVC, animated: true)
    }
    
    private func showError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.activityIndicator.stopAnimating()
            self?.statusLabel.text = "Error: \(message)"
            
            let alert = UIAlertController(title: "Export Failed", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            })
            self?.present(alert, animated: true)
        }
    }
} 