import UIKit
import FSCalendar
import CoreData

class CalendarViewController: UIViewController, FSCalendarDataSource, FSCalendarDelegate, FSCalendarDelegateAppearance, UITableViewDataSource, UITableViewDelegate {
    private var calendar: FSCalendar!
    private var tableView: UITableView!
    private var measurementsByDate: [Date: [(UIColor, MeasurementEntry)]] = [:]
    private var selectedMeasurements: [MeasurementEntry] = []
    private let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
    
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
        let request: NSFetchRequest<MeasurementEntry> = MeasurementEntry.fetchRequest()
        do {
            let entries = try context.fetch(request)
            measurementsByDate = [:]
            for entry in entries {
                guard let timestamp = entry.timestamp, let type = entry.type, let colorHex = type.color else { continue }
                let day = dateFormatter.date(from: dateFormatter.string(from: timestamp))!
                let color = UIColor(hex: colorHex)
                if measurementsByDate[day] != nil {
                    measurementsByDate[day]?.append((color, entry))
                } else {
                    measurementsByDate[day] = [(color, entry)]
                }
            }
            calendar.reloadData()
        } catch {
            print("Error fetching measurements: \(error)")
        }
    }
    
    private func updateSelectedMeasurements(for date: Date) {
        let day = dateFormatter.date(from: dateFormatter.string(from: date))!
        selectedMeasurements = measurementsByDate[day]?.map { $0.1 } ?? []
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
        let entry = selectedMeasurements[indexPath.row]
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        if let type = entry.type {
            var content = cell.defaultContentConfiguration()
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
            cell.contentConfiguration = content
        }
        return cell
    }
} 