import SwiftUI
import Charts
import CoreData
import DGCharts
import HealthKit

struct GraphTabView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var measurementTypes: [MeasurementType] = []
    @State private var selectedType: MeasurementType?
    
    private func fetchMeasurementTypes() {
        let request: NSFetchRequest<MeasurementType> = MeasurementType.fetchRequest()
        request.predicate = NSPredicate(format: "isVisible == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MeasurementType.name, ascending: true)]
        do {
            measurementTypes = try context.fetch(request)
        } catch {
            print("Error fetching measurement types: \(error)")
        }
    }
    
    private func latestDisplayValue(for type: MeasurementType) -> String {
        if type.unit == "Picture" {
            return ""
        } else if type.isFormula {
            guard let dependencies = type.dependencies?.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }),
                  let formula = type.formula,
                  let context = type.managedObjectContext else {
                return type.unit ?? ""
            }
            
            // Gather all entries for dependencies
            var depEntries: [String: [MeasurementEntry]] = [:]
            for depName in dependencies {
                let fetch: NSFetchRequest<MeasurementType> = MeasurementType.fetchRequest()
                fetch.predicate = NSPredicate(format: "name == %@", depName)
                if let depType = try? context.fetch(fetch).first, let entries = depType.entries as? Set<MeasurementEntry> {
                    depEntries[depName] = entries.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
                }
            }
            
            // Find the most recent values for each dependency up to today
            var values: [String: Double] = [:]
            let today = Calendar.current.startOfDay(for: Date())
            for (depName, entries) in depEntries {
                if let mostRecentEntry = entries.last(where: { 
                    if let entryDate = $0.timestamp {
                        return Calendar.current.startOfDay(for: entryDate) <= today
                    }
                    return false
                }) {
                    values[depName] = mostRecentEntry.value
                }
            }
            
            if values.count == dependencies.count {
                let expr = NSExpression(format: formula)
                let result = expr.expressionValue(with: values, context: nil) as? Double ?? 0.0
                return "\(result.formatted) \(type.unit ?? "")"
            } else {
                return type.unit ?? ""
            }
        } else {
            if let entries = type.entries as? Set<MeasurementEntry>,
               let latest = entries.sorted(by: { ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast) }).first {
                return "\(latest.value.formatted) \(type.unit ?? "")"
            } else {
                return type.unit ?? ""
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Show all HealthKit-linked categories, even if no entries
                let allTypes: [MeasurementType] = measurementTypes
                if let type = selectedType ?? allTypes.first {
                    if type.unit == "Picture" {
                        PictureGalleryView(type: type)
                            .frame(height: 220)
                    } else {
                        DGLineChartViewRepresentable(type: type)
                            .frame(height: 220)
                    }
                } else {
                    Text("No categories available.")
                        .frame(height: 220)
                }
                Divider()
                List(selection: $selectedType) {
                    ForEach(allTypes, id: \.self) { type in
                        HStack {
                            if let colorHex = type.color {
                                Circle()
                                    .fill(Color(UIColor(hex: colorHex)))
                                    .frame(width: 16, height: 16)
                            }
                            Text(type.name ?? "")
                            Spacer()
                            if type.unit == "Picture" {
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            }
                            Text(latestDisplayValue(for: type))
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedType = type }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Graph")
            .onAppear(perform: fetchMeasurementTypes)
        }
    }
}

struct DGLineChartViewRepresentable: UIViewRepresentable {
    let type: MeasurementType
    @Environment(\.managedObjectContext) private var context
    
    class Coordinator {
        var healthKitSamples: [HKQuantitySample] = []
        var dates: [Date] = []
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> LineChartView {
        let chartView = LineChartView()
        chartView.rightAxis.enabled = false
        chartView.xAxis.labelPosition = .bottom
        chartView.xAxis.labelRotationAngle = -45
        
        // Create and configure the date formatter
        let dateFormatter = DateAxisValueFormatter()
        dateFormatter.chartView = chartView
        chartView.xAxis.valueFormatter = dateFormatter
        
        chartView.legend.enabled = false
        chartView.setScaleEnabled(true)
        chartView.pinchZoomEnabled = true
        chartView.doubleTapToZoomEnabled = true
        chartView.highlightPerTapEnabled = true
        chartView.dragEnabled = true
        chartView.animate(xAxisDuration: 0.5)
        chartView.scaleYEnabled = false
        
        // Configure marker
        let marker = BalloonMarker(color: .systemBlue,
                                  font: .systemFont(ofSize: 12),
                                  textColor: .white,
                                  insets: UIEdgeInsets(top: 8, left: 8, bottom: 20, right: 8),
                                  context: self.context)
        marker.chartView = chartView
        marker.minimumSize = CGSize(width: 80, height: 40)
        chartView.marker = marker
        
        return chartView
    }
    
    func updateUIView(_ uiView: LineChartView, context: Context) {
        if let hkIdStr = type.healthKitIdentifier {
            let hkId = HKQuantityTypeIdentifier(rawValue: hkIdStr)
            HealthKitManager.shared.fetchAllQuantitySamples(for: hkId) { samples in
                DispatchQueue.main.async {
                    context.coordinator.healthKitSamples = samples
                    let sorted = samples.sorted { $0.endDate < $1.endDate }
                    context.coordinator.dates = sorted.map { $0.endDate }
                    if let formatter = uiView.xAxis.valueFormatter as? DateAxisValueFormatter {
                        formatter.dates = context.coordinator.dates
                    }
                    let chartEntries = sorted.enumerated().map { (idx, sample) -> ChartDataEntry in
                        // Use kg for body mass, meters for height, etc.
                        let value: Double
                        switch hkId {
                        case .bodyMass: value = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                        case .height: value = sample.quantity.doubleValue(for: .meter())
                        case .bodyFatPercentage: value = sample.quantity.doubleValue(for: .percent())
                        case .bodyMassIndex: value = sample.quantity.doubleValue(for: .count())
                        case .stepCount: value = sample.quantity.doubleValue(for: .count())
                        case .heartRate: value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                        case .activeEnergyBurned, .basalEnergyBurned: value = sample.quantity.doubleValue(for: .kilocalorie())
                        case .waistCircumference: value = sample.quantity.doubleValue(for: .meterUnit(with: .centi))
                        default: value = sample.quantity.doubleValue(for: .count())
                        }
                        let chartEntry = ChartDataEntry(x: Double(idx), y: value)
                        return chartEntry
                    }
                    if chartEntries.isEmpty {
                        uiView.data = nil
                        uiView.noDataText = "No data"
                    } else {
                        let dataSet = LineChartDataSet(entries: chartEntries, label: type.name ?? "")
                        dataSet.colors = [NSUIColor.systemBlue]
                        dataSet.circleColors = [NSUIColor.systemBlue]
                        dataSet.circleRadius = 4
                        dataSet.drawValuesEnabled = false
                        dataSet.lineWidth = 2
                        dataSet.mode = LineChartDataSet.Mode.cubicBezier
                        let data = LineChartData(dataSet: dataSet)
                        uiView.data = data
                    }
                }
            }
        } else if type.isFormula, let dependencies = type.dependencies?.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }), let formula = type.formula, let moc = type.managedObjectContext {
            // Gather all entries for dependencies
            var depEntries: [String: [MeasurementEntry]] = [:]
            for depName in dependencies {
                let fetch: NSFetchRequest<MeasurementType> = MeasurementType.fetchRequest()
                fetch.predicate = NSPredicate(format: "name == %@", depName)
                if let depType = try? moc.fetch(fetch).first, let entries = depType.entries as? Set<MeasurementEntry> {
                    depEntries[depName] = entries.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
                }
            }
            
            // For each day where we have a measurement, find the most recent values for each dependency
            var dayToValues: [String: [String: Double]] = [:]
            var dayToDate: [String: Date] = [:]
            for (depName, entries) in depEntries {
                for entry in entries {
                    if let date = entry.timestamp {
                        let day = Calendar.current.startOfDay(for: date)
                        let dayStr = ISO8601DateFormatter().string(from: day)
                        // For each dependency, find the most recent value up to this day
                        for (otherDepName, otherEntries) in depEntries {
                            if otherDepName != depName {
                                if let mostRecentEntry = otherEntries.last(where: { 
                                    if let otherDate = $0.timestamp {
                                        return Calendar.current.startOfDay(for: otherDate) <= day
                                    }
                                    return false
                                }) {
                                    dayToValues[dayStr, default: [:]][otherDepName] = mostRecentEntry.value
                                }
                            }
                        }
                        // Add the current entry's value
                        dayToValues[dayStr, default: [:]][depName] = entry.value
                        dayToDate[dayStr] = day
                    }
                }
            }
            
            let validDays = dayToValues.filter { $0.value.keys.count == dependencies.count }
            let sortedDays = validDays.keys.sorted()
            context.coordinator.dates = sortedDays.compactMap { dayToDate[$0] }
            if let formatter = uiView.xAxis.valueFormatter as? DateAxisValueFormatter {
                formatter.dates = context.coordinator.dates
            }
            let chartEntries: [ChartDataEntry] = sortedDays.enumerated().map { (idx, dayStr) in
                let values = validDays[dayStr]!
                let expr = NSExpression(format: formula)
                let result = expr.expressionValue(with: values, context: nil) as? Double ?? 0.0
                let chartEntry = ChartDataEntry(x: Double(idx), y: result)
                return chartEntry
            }
            let dataSet = LineChartDataSet(entries: chartEntries, label: type.name ?? "")
            dataSet.colors = [NSUIColor.systemBlue]
            dataSet.circleColors = [NSUIColor.systemBlue]
            dataSet.circleRadius = 4
            dataSet.drawValuesEnabled = false
            dataSet.lineWidth = 2
            dataSet.mode = LineChartDataSet.Mode.cubicBezier
            let data = LineChartData(dataSet: dataSet)
            uiView.data = data
        } else {
            let request: NSFetchRequest<MeasurementEntry> = MeasurementEntry.fetchRequest()
            request.predicate = NSPredicate(format: "type == %@", type)
            let entries: [MeasurementEntry]
            do {
                entries = try self.context.fetch(request)
            } catch {
                uiView.data = nil
                return
            }
            let sorted = entries.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
            context.coordinator.dates = sorted.compactMap { $0.timestamp }
            if let formatter = uiView.xAxis.valueFormatter as? DateAxisValueFormatter {
                formatter.dates = context.coordinator.dates
            }
            let chartEntries = sorted.enumerated().map { (idx, entry) -> ChartDataEntry in
                let chartEntry = ChartDataEntry(x: Double(idx), y: entry.value)
                if let note = entry.note, !note.isEmpty {
                    chartEntry.data = note
                }
                return chartEntry
            }
            let dataSet = LineChartDataSet(entries: chartEntries, label: type.name ?? "")
            dataSet.colors = [NSUIColor.systemBlue]
            dataSet.circleColors = [NSUIColor.systemBlue]
            dataSet.circleRadius = 4
            dataSet.drawValuesEnabled = false
            dataSet.lineWidth = 2
            dataSet.mode = LineChartDataSet.Mode.cubicBezier
            let data = LineChartData(dataSet: dataSet)
            uiView.data = data
        }
    }
}

// Custom value formatter for x-axis dates
class DateAxisValueFormatter: NSObject, AxisValueFormatter {
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    weak var chartView: LineChartView?
    var dates: [Date] = []
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let index = Int(round(value))
        if index >= 0 && index < dates.count {
            return dateFormatter.string(from: dates[index])
        }
        return ""
    }
}

// Custom marker to show values when highlighting
class BalloonMarker: MarkerImage {
    private var color: UIColor
    private var font: UIFont
    private var textColor: UIColor
    private var insets: UIEdgeInsets
    var minimumSize = CGSize()
    weak var context: NSManagedObjectContext?
    
    private var label: String?
    private var _labelSize: CGSize = CGSize()
    private var _paragraphStyle: NSMutableParagraphStyle?
    private var _drawAttributes = [NSAttributedString.Key: Any]()
    
    init(color: UIColor, font: UIFont, textColor: UIColor, insets: UIEdgeInsets, context: NSManagedObjectContext) {
        self.color = color
        self.font = font
        self.textColor = textColor
        self.insets = insets
        self.context = context
        
        _paragraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle
        _paragraphStyle?.alignment = .center
        super.init()
    }
    
    public override func draw(context: CGContext, point: CGPoint) {
        guard let label = label else { return }
        
        let offset = self.offsetForDrawing(atPoint: point)
        let size = self.size
        
        var rect = CGRect(
            origin: CGPoint(
                x: point.x + offset.x,
                y: point.y + offset.y),
            size: size)
        rect.origin.x -= size.width / 2.0
        rect.origin.y -= size.height
        
        context.saveGState()
        
        context.setFillColor(color.cgColor)
        
        if offset.y > 0 {
            context.beginPath()
            context.move(to: CGPoint(
                x: rect.origin.x,
                y: rect.origin.y + rect.size.height))
            context.addLine(to: CGPoint(
                x: rect.origin.x + (rect.size.width - 8) / 2.0,
                y: rect.origin.y + rect.size.height + 8))
            context.addLine(to: CGPoint(
                x: point.x,
                y: point.y))
            context.addLine(to: CGPoint(
                x: rect.origin.x + (rect.size.width + 8) / 2.0,
                y: rect.origin.y + rect.size.height + 8))
            context.addLine(to: CGPoint(
                x: rect.origin.x + rect.size.width,
                y: rect.origin.y + rect.size.height))
            context.closePath()
            context.fillPath()
        } else {
            context.beginPath()
            context.move(to: CGPoint(
                x: rect.origin.x,
                y: rect.origin.y))
            context.addLine(to: CGPoint(
                x: rect.origin.x + rect.size.width,
                y: rect.origin.y))
            context.addLine(to: CGPoint(
                x: rect.origin.x + rect.size.width,
                y: rect.origin.y + rect.size.height))
            context.addLine(to: CGPoint(
                x: rect.origin.x + (rect.size.width + 8) / 2.0,
                y: rect.origin.y + rect.size.height + 8))
            context.addLine(to: CGPoint(
                x: point.x,
                y: point.y))
            context.addLine(to: CGPoint(
                x: rect.origin.x + (rect.size.width - 8) / 2.0,
                y: rect.origin.y + rect.size.height + 8))
            context.addLine(to: CGPoint(
                x: rect.origin.x,
                y: rect.origin.y + rect.size.height))
            context.closePath()
            context.fillPath()
        }
        
        rect.origin.y += self.insets.top
        rect.size.height -= self.insets.top + self.insets.bottom
        
        UIGraphicsPushContext(context)
        
        label.draw(in: rect, withAttributes: _drawAttributes)
        
        UIGraphicsPopContext()
        
        context.restoreGState()
    }
    
    public override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        let value = entry.y
        if let note = entry.data as? String, !note.isEmpty {
            setLabel(String(format: "%.1f\n%@", value, note))
        } else {
            setLabel(String(format: "%.1f", value))
        }
    }
    
    public func setLabel(_ newLabel: String) {
        label = newLabel
        
        _drawAttributes.removeAll()
        _drawAttributes[.font] = self.font
        _drawAttributes[.paragraphStyle] = _paragraphStyle
        _drawAttributes[.foregroundColor] = self.textColor
        
        _labelSize = label?.size(withAttributes: _drawAttributes) ?? CGSize.zero
        
        var size = CGSize()
        size.width = _labelSize.width + self.insets.left + self.insets.right
        size.height = _labelSize.height + self.insets.top + self.insets.bottom
        size.width = max(minimumSize.width, size.width)
        size.height = max(minimumSize.height, size.height)
        self.size = size
    }
}

struct PictureGalleryView: View {
    let type: MeasurementType
    @State private var entries: [MeasurementEntry] = []
    @Environment(\.managedObjectContext) private var context
    @State private var selectedImage: UIImage? = nil
    @State private var selectedEntry: MeasurementEntry? = nil
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(entries.sorted(by: { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }), id: \.self) { entry in
                    if let imageData = entry.image, let uiImage = UIImage(data: imageData) {
                        VStack {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipped()
                                .cornerRadius(8)
                                .onTapGesture {
                                    selectedImage = uiImage
                                    selectedEntry = entry
                                }
                            if let date = entry.timestamp {
                                Text(date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .onAppear(perform: fetchEntries)
        .onChange(of: type) { oldValue, newValue in
            fetchEntries()
        }
        .sheet(isPresented: Binding<Bool>(
            get: { selectedImage != nil },
            set: { if !$0 { selectedImage = nil; selectedEntry = nil } }
        )) {
            if let image = selectedImage {
                ImagePreviewViewControllerRepresentable(image: image, measurementEntry: selectedEntry)
            }
        }
    }
    
    private func fetchEntries() {
        let request: NSFetchRequest<MeasurementEntry> = MeasurementEntry.fetchRequest()
        request.predicate = NSPredicate(format: "type == %@", type)
        do {
            entries = try context.fetch(request)
        } catch {
            entries = []
        }
    }
}

struct ImagePreviewViewControllerRepresentable: UIViewControllerRepresentable {
    let image: UIImage
    let measurementEntry: MeasurementEntry?
    
    func makeUIViewController(context: Context) -> ImagePreviewViewController {
        let vc = ImagePreviewViewController(image: image, measurementEntry: measurementEntry)
        vc.modalPresentationStyle = .fullScreen
        return vc
    }
    
    func updateUIViewController(_ uiViewController: ImagePreviewViewController, context: Context) {
        // No updates needed
    }
}

struct ImagePreviewView: View, Identifiable {
    let id = UUID()
    let image: UIImage
    let note: String?
    let onDismiss: () -> Void
    @State private var editedNote: String?
    @State private var showNoteEditor = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showNoteEditor = true
                    }) {
                        Image(systemName: "note.text")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                .padding(.top, 16)
                .padding(.trailing, 16)
                
                Spacer()
                
                if let note = editedNote ?? note, !note.isEmpty {
                    Text(note)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.7))
                }
            }
        }
        .sheet(isPresented: $showNoteEditor) {
            NoteEditorView(note: $editedNote, onSave: {
                showNoteEditor = false
            })
        }
    }
}

struct NoteEditorView: View {
    @Binding var note: String?
    let onSave: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: Binding(
                    get: { note ?? "" },
                    set: { note = $0 }
                ))
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding()
            }
            .navigationTitle("Add Note")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
} 
