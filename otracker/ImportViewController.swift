import UIKit
import CoreData
import ZIPFoundation

class ImportViewController: UIViewController, UIDocumentPickerDelegate {
    private let context: NSManagedObjectContext
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()
    private let importButton = UIButton(type: .system)
    
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
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Import Data"
        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.text = "Select a previously exported ZIP file to import your data."
        view.addSubview(statusLabel)
        
        importButton.setTitle("Select ZIP File", for: .normal)
        importButton.backgroundColor = .systemBlue
        importButton.setTitleColor(.white, for: .normal)
        importButton.layer.cornerRadius = 8
        importButton.addTarget(self, action: #selector(importButtonTapped), for: .touchUpInside)
        importButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(importButton)
        
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            importButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            importButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            importButton.widthAnchor.constraint(equalToConstant: 200),
            importButton.heightAnchor.constraint(equalToConstant: 44),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    @objc private func importButtonTapped() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.zip])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true)
    }
    
    // MARK: - UIDocumentPickerDelegate
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let zipURL = urls.first else { return }
        
        // Start import process
        activityIndicator.startAnimating()
        statusLabel.text = "Importing data..."
        importButton.isEnabled = false
        
        // Create a temporary directory for extraction
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("otracker_import")
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // Extract ZIP file
            try FileManager.default.unzipItem(at: zipURL, to: tempDir)
            
            // Read JSON files
            var typesPath = tempDir.appendingPathComponent("measurement_types.json")
            var entriesPath = tempDir.appendingPathComponent("measurement_entries.json")
            
            // If not found at root, search recursively
            if !FileManager.default.fileExists(atPath: typesPath.path) || !FileManager.default.fileExists(atPath: entriesPath.path) {
                if let enumerator = FileManager.default.enumerator(at: tempDir, includingPropertiesForKeys: nil) {
                    for case let fileURL as URL in enumerator {
                        if fileURL.lastPathComponent == "measurement_types.json" {
                            typesPath = fileURL
                        }
                        if fileURL.lastPathComponent == "measurement_entries.json" {
                            entriesPath = fileURL
                        }
                    }
                }
            }
            
            let typesData = try Data(contentsOf: typesPath)
            let entriesData = try Data(contentsOf: entriesPath)
            
            let typesJSON = try JSONSerialization.jsonObject(with: typesData) as! [[String: Any]]
            let entriesJSON = try JSONSerialization.jsonObject(with: entriesData) as! [[String: Any]]
            
            // Clear existing data
            let typesRequest: NSFetchRequest<MeasurementType> = MeasurementType.fetchRequest()
            let entriesRequest: NSFetchRequest<MeasurementEntry> = MeasurementEntry.fetchRequest()
            
            let existingTypes = try context.fetch(typesRequest)
            let existingEntries = try context.fetch(entriesRequest)
            
            for entry in existingEntries {
                context.delete(entry)
            }
            
            for type in existingTypes {
                context.delete(type)
            }
            
            try context.save()
            
            // Import measurement types
            var typeMap: [String: MeasurementType] = [:]
            for typeDict in typesJSON {
                let type = MeasurementType(context: context)
                type.name = typeDict["name"] as? String
                type.unit = typeDict["unit"] as? String
                type.color = typeDict["color"] as? String
                type.isFormula = typeDict["isFormula"] as? Bool ?? false
                type.formula = typeDict["formula"] as? String
                type.dependencies = typeDict["dependencies"] as? String
                type.healthKitIdentifier = typeDict["healthKitIdentifier"] as? String
                type.isVisible = typeDict["isVisible"] as? Bool ?? true
                
                if let name = type.name {
                    typeMap[name] = type
                }
            }
            
            // Import measurement entries
            for entryDict in entriesJSON {
                let entry = MeasurementEntry(context: context)
                entry.value = entryDict["value"] as? Double ?? 0
                if let timestamp = entryDict["timestamp"] as? TimeInterval {
                    entry.timestamp = Date(timeIntervalSince1970: timestamp)
                }
                entry.note = entryDict["note"] as? String
                
                if let typeName = entryDict["typeName"] as? String {
                    entry.type = typeMap[typeName]
                }
                
                if let imageName = entryDict["image"] as? String {
                    var imagePath = tempDir.appendingPathComponent(imageName)
                    var imageData: Data? = nil
                    if FileManager.default.fileExists(atPath: imagePath.path) {
                        imageData = try? Data(contentsOf: imagePath)
                    } else {
                        // Search recursively for the image file
                        if let enumerator = FileManager.default.enumerator(at: tempDir, includingPropertiesForKeys: nil) {
                            for case let fileURL as URL in enumerator {
                                if fileURL.lastPathComponent == imageName {
                                    imageData = try? Data(contentsOf: fileURL)
                                    break
                                }
                            }
                        }
                    }
                    if let data = imageData {
                        entry.image = data
                    }
                }
            }
            
            try context.save()
            
            // Clean up
            try? FileManager.default.removeItem(at: tempDir)
            
            // Show success message
            DispatchQueue.main.async { [weak self] in
                self?.activityIndicator.stopAnimating()
                self?.statusLabel.text = "Import successful!"
                self?.importButton.isEnabled = true
                
                let alert = UIAlertController(title: "Import Complete", message: "Your data has been successfully imported.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                    self?.navigationController?.popViewController(animated: true)
                })
                self?.present(alert, animated: true)
            }
            
        } catch {
            // Show error message
            DispatchQueue.main.async { [weak self] in
                self?.activityIndicator.stopAnimating()
                self?.statusLabel.text = "Error: \(error.localizedDescription)"
                self?.importButton.isEnabled = true
                
                let alert = UIAlertController(title: "Import Failed", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            }
            
            // Clean up on error
            try? FileManager.default.removeItem(at: tempDir)
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // User cancelled the import
    }
} 