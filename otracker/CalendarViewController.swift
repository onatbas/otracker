import UIKit
import FSCalendar
import CoreData
import HealthKit

class CalendarViewController: UIViewController, FSCalendarDataSource, FSCalendarDelegate, FSCalendarDelegateAppearance, UITableViewDataSource, UITableViewDelegate {
    private var calendar: FSCalendar!
    private var tableView: UITableView!
    private var measurementsByDate: [Date: [(UIColor, MeasurementEntry)]] = [:]
    private var selectedMeasurements: [Any] = [] // Can be MeasurementEntry or FormulaResult
    private var allMeasurementTypes: [MeasurementType] = []
    private let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
    
    struct FormulaResult {
        let type: MeasurementType
        let value: Double
        let date: Date
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Calendar"
        view.backgroundColor = .systemBackground
        setupCalendar()
        setupTableView()
        fetchMeasurements()
        // Select today by default
        calendar.select(Date())
        updateSelectedMeasurements(for: Date())
        NotificationCenter.default.addObserver(self, selector: #selector(measurementAdded), name: .measurementAdded, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .measurementAdded, object: nil)
    }
    
    @objc private func measurementAdded() {
        fetchMeasurements()
        let selected = calendar.selectedDate ?? Date()
        updateSelectedMeasurements(for: selected)
    }
    
    private func setupCalendar() {
        calendar = FSCalendar()
        calendar.translatesAutoresizingMaskIntoConstraints = false
        calendar.dataSource = self
        calendar.delegate = self
        view.addSubview(calendar)
        NSLayoutConstraint.activate([
            calendar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            calendar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            calendar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            calendar.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5)
        ])
        updateCalendarAppearance()
    }

    private func setupTableView() {
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: calendar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func updateCalendarAppearance() {
        let labelColor: UIColor
        if traitCollection.userInterfaceStyle == .dark {
            labelColor = .white
        } else {
            labelColor = .black
        }
        calendar.appearance.titleDefaultColor = labelColor
        calendar.appearance.headerTitleColor = labelColor
        calendar.appearance.weekdayTextColor = labelColor
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateCalendarAppearance()
    }
    
    private func fetchMeasurements() {
        let request: NSFetchRequest<MeasurementType> = MeasurementType.fetchRequest()
        request.predicate = NSPredicate(format: "isVisible == YES")
        do {
            allMeasurementTypes = try context.fetch(request)
            tableView.reloadData()
        } catch {
            print("Error fetching measurement types: \(error)")
        }
        
        // Clear existing measurements
        measurementsByDate = [:]
        
        // Fetch Core Data entries for non-HealthKit types
        let requestEntries: NSFetchRequest<MeasurementEntry> = MeasurementEntry.fetchRequest()
        do {
            let entries = try context.fetch(requestEntries)
            for entry in entries {
                guard let timestamp = entry.timestamp, let type = entry.type, let colorHex = type.color else { continue }
                // Skip HealthKit-linked types
                if type.healthKitIdentifier != nil { continue }
                let day = dateFormatter.date(from: dateFormatter.string(from: timestamp))!
                let color = UIColor(hex: colorHex)
                if measurementsByDate[day] != nil {
                    measurementsByDate[day]?.append((color, entry))
                } else {
                    measurementsByDate[day] = [(color, entry)]
                }
            }
        } catch {
            print("Error fetching measurements: \(error)")
        }
        
        // Fetch HealthKit data for linked types
        let group = DispatchGroup()
        for type in allMeasurementTypes {
            if let hkIdStr = type.healthKitIdentifier {
                let hkId = HKQuantityTypeIdentifier(rawValue: hkIdStr)
                group.enter()
                HealthKitManager.shared.fetchAllQuantitySamples(for: hkId) { [weak self] samples in
                    defer { group.leave() }
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        for sample in samples {
                            let day = self.dateFormatter.date(from: self.dateFormatter.string(from: sample.endDate))!
                            if let colorHex = type.color {
                                let color = UIColor(hex: colorHex)
                                // Create a temporary MeasurementEntry for display purposes only
                                let entry = MeasurementEntry(context: self.context)
                                entry.timestamp = sample.endDate
                                entry.type = type
                                
                                // Convert the sample value to the appropriate unit
                                let value: Double
                                switch hkId {
                                case .bodyMass: value = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                                case .height: value = sample.quantity.doubleValue(for: .meter())
                                case .bodyFatPercentage: value = sample.quantity.doubleValue(for: .percent())
                                case .bodyMassIndex: value = sample.quantity.doubleValue(for: .count())
                                case .stepCount: value = sample.quantity.doubleValue(for: .count())
                                case .heartRate: value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                                case .activeEnergyBurned, .basalEnergyBurned: value = sample.quantity.doubleValue(for: .kilocalorie())
                                default: value = sample.quantity.doubleValue(for: .count())
                                }
                                entry.value = value
                                
                                if self.measurementsByDate[day] != nil {
                                    self.measurementsByDate[day]?.append((color, entry))
                                } else {
                                    self.measurementsByDate[day] = [(color, entry)]
                                }
                            }
                        }
                    }
                }
            }
        }
        group.notify(queue: .main) { [weak self] in
            self?.calendar.reloadData()
        }
    }
    
    private func updateSelectedMeasurements(for date: Date) {
        let day = dateFormatter.date(from: dateFormatter.string(from: date))!
        var entries = measurementsByDate[day]?.map { $0.1 } ?? []
        // Compute formula results for this day
        var formulaResults: [FormulaResult] = []
        for type in allMeasurementTypes where type.isFormula {
            guard let dependencies = type.dependencies?.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }),
                  let formula = type.formula else { continue }
            
            // Gather all entries for dependencies
            var depEntries: [String: [MeasurementEntry]] = [:]
            for depName in dependencies {
                if let depType = allMeasurementTypes.first(where: { $0.name == depName }),
                   let entries = depType.entries as? Set<MeasurementEntry> {
                    depEntries[depName] = entries.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
                }
            }
            
            // Find the most recent values for each dependency up to this day
            var values: [String: Double] = [:]
            for (depName, entries) in depEntries {
                if let mostRecentEntry = entries.last(where: { 
                    if let entryDate = $0.timestamp {
                        return Calendar.current.startOfDay(for: entryDate) <= day
                    }
                    return false
                }) {
                    values[depName] = mostRecentEntry.value
                }
            }
            
            if values.count == dependencies.count {
                // All dependencies present
                let expr = NSExpression(format: formula)
                let result = expr.expressionValue(with: values, context: nil) as? Double ?? 0.0
                formulaResults.append(FormulaResult(type: type, value: result, date: day))
            }
        }
        // Sort: formula results first, then entries, both by type name
        selectedMeasurements = formulaResults.sorted { ($0.type.name ?? "") < ($1.type.name ?? "") } + entries.sorted { ($0.type?.name ?? "") < ($1.type?.name ?? "") }
        tableView.reloadData()
    }
    
    // MARK: - FSCalendarDataSource/Delegate
    func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
        let day = dateFormatter.date(from: dateFormatter.string(from: date))!
        return measurementsByDate[day]?.count ?? 0
    }
    
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, eventDefaultColorsFor date: Date) -> [UIColor]? {
        let day = dateFormatter.date(from: dateFormatter.string(from: date))!
        return measurementsByDate[day]?.map { $0.0 }
    }
    
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        updateSelectedMeasurements(for: date)
    }
    
    // MARK: - UITableViewDataSource/Delegate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return selectedMeasurements.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        var content = cell.defaultContentConfiguration()
        let item = selectedMeasurements[indexPath.row]
        if let formula = item as? FormulaResult {
            content.text = formula.type.name ?? ""
            content.secondaryText = "\(formula.value.clean) \(formula.type.unit ?? "")"
            if let colorHex = formula.type.color {
                content.textProperties.color = UIColor(hex: colorHex)
            }
            cell.selectionStyle = .none
        } else if let entry = item as? MeasurementEntry, let type = entry.type {
            if type.unit == "Picture", let imageData = entry.image, let image = UIImage(data: imageData) {
                let thumbnailSize = CGSize(width: 44, height: 44)
                let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
                let thumbnail = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
                }
                content.image = thumbnail
                content.imageProperties.cornerRadius = 8
                content.imageProperties.maximumSize = thumbnailSize
                content.text = type.name
                content.secondaryText = formatter.string(from: entry.timestamp ?? Date())
                cell.selectionStyle = .default
            } else {
                // Find previous entry for this type before this entry's timestamp
                let request: NSFetchRequest<MeasurementEntry> = MeasurementEntry.fetchRequest()
                request.predicate = NSPredicate(format: "type == %@ AND timestamp < %@", type, entry.timestamp! as NSDate)
                request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
                request.fetchLimit = 1
                var triangle = ""
                if let prev = try? context.fetch(request).first {
                    if entry.value > prev.value {
                        triangle = "▲ "
                    } else if entry.value < prev.value {
                        triangle = "▼ "
                    }
                }
                content.text = type.name
                content.secondaryText = "\(triangle)\(entry.value) \(type.unit ?? "")"
                if let colorHex = type.color {
                    content.textProperties.color = UIColor(hex: colorHex)
                }
                cell.selectionStyle = .none
            }
        }
        cell.contentConfiguration = content
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = selectedMeasurements[indexPath.row]
        if let entry = item as? MeasurementEntry, let type = entry.type, type.unit == "Picture", let imageData = entry.image, let image = UIImage(data: imageData) {
            let previewVC = ImagePreviewViewController(image: image)
            present(previewVC, animated: true)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
} 