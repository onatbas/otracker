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
                            .id(type.objectID)
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
    
    class Coordinator: NSObject, ChartViewDelegate {
        var chartView: LineChartView?
        var allEntries: [ChartDataEntry] = []
        private var updateTimer: Timer?
        
        func chartTranslated(_ chartView: ChartViewBase, dX: CGFloat, dY: CGFloat) {
            scheduleAxisUpdate()
        }
        
        func chartScaled(_ chartView: ChartViewBase, scaleX: CGFloat, scaleY: CGFloat) {
            scheduleAxisUpdate()
        }
        
        private func scheduleAxisUpdate() {
            // Cancel any existing timer
            updateTimer?.invalidate()
            
            // Create a new timer that will fire after 1 second
            updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                self?.updateAxisLimits()
            }
        }
        
        func updateAxisLimits() {
            guard let chartView = chartView else { return }
            
            // Store current viewport position
            let currentXMin = chartView.lowestVisibleX
            let currentXMax = chartView.highestVisibleX
            
            // Get visible entries
            let visibleEntries = allEntries.filter { entry in
                let xPos = chartView.getTransformer(forAxis: .left).pixelForValues(x: entry.x, y: entry.y).x
                return xPos >= 0 && xPos <= chartView.bounds.width
            }
            
            if !visibleEntries.isEmpty {
                let values = visibleEntries.map { $0.y }
                if let min = values.min(), let max = values.max() {
                    let padding = 10.0
                    chartView.leftAxis.axisMinimum = min - padding
                    chartView.leftAxis.axisMaximum = max + padding
                    
                    // Update data and force complete redraw
                    chartView.data?.notifyDataChanged()
                    chartView.notifyDataSetChanged()
                    chartView.setNeedsDisplay()
                    
                    // Move to current position
                    chartView.moveViewToX(currentXMin)
                }
            }
        }
        
        deinit {
            updateTimer?.invalidate()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> LineChartView {
        let chartView = LineChartView()
        chartView.rightAxis.enabled = false
        chartView.xAxis.labelPosition = .bottom
        chartView.xAxis.labelRotationAngle = -45
        
        // Enable adaptive vertical scaling with padding
        chartView.autoScaleMinMaxEnabled = false // Disable auto scaling to set our own min/max
        chartView.leftAxis.granularityEnabled = true // Enable granularity for cleaner labels
        
        // Configure x-axis to prevent duplicate labels
        chartView.xAxis.granularity = 24 * 3600 // One day in seconds
        chartView.xAxis.labelCount = 8
        chartView.xAxis.forceLabelsEnabled = false
        
        // Set zoom limit to 12x
        chartView.viewPortHandler.setMaximumScaleX(12.0)
        
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
        
        // Set up delegate
        chartView.delegate = context.coordinator
        context.coordinator.chartView = chartView
        
        return chartView
    }
    
    func updateUIView(_ uiView: LineChartView, context: Context) {
        // Always clear chart data before updating to prevent unit conversion issues
        uiView.data = nil
        uiView.notifyDataSetChanged()
        
        if let hkIdStr = type.healthKitIdentifier {
            let hkId = HKQuantityTypeIdentifier(rawValue: hkIdStr)
            
            // Fetch all data from the beginning
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .year, value: -10, to: endDate)! // Fetch up to 10 years of data
            
            HealthKitManager.shared.fetchQuantitySamples(for: hkId, startDate: startDate, endDate: endDate) { samples in
                DispatchQueue.main.async {
                    let sorted = samples.sorted { $0.endDate < $1.endDate }
                    let dates = sorted.map { $0.endDate }
                    
                    // Calculate zoom scale based on date range
                    if let firstDate = dates.first, let lastDate = dates.last {
                        let months = Calendar.current.dateComponents([.month], from: firstDate, to: lastDate).month ?? 0
                        let maxZoom = Double(max(1, months + 1)) * 3.0
                        uiView.viewPortHandler.setMaximumScaleX(maxZoom)
                    }
                    
                    if let formatter = uiView.xAxis.valueFormatter as? DateAxisValueFormatter {
                        formatter.dates = dates
                    }
                    
                    let chartEntries = sorted.map { sample -> ChartDataEntry in
                        // Use kg for body mass, meters for height, etc.
                        var value: Double
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
                        return ChartDataEntry(x: sample.endDate.timeIntervalSince1970, y: value)
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
                        
                        // Store all entries in coordinator and update initial axis limits
                        context.coordinator.allEntries = chartEntries
                        context.coordinator.updateAxisLimits()
                    }
                }
            }
        } else {
            // Fetch all data from the beginning
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .year, value: -10, to: endDate)! // Fetch up to 10 years of data
            
            let request: NSFetchRequest<MeasurementEntry> = MeasurementEntry.fetchRequest()
            request.predicate = NSPredicate(format: "type == %@ AND timestamp >= %@ AND timestamp <= %@", type, startDate as NSDate, endDate as NSDate)
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
            
            do {
                let entries = try self.context.fetch(request)
                let sorted = entries.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
                let dates = sorted.compactMap { $0.timestamp }
                
                // Calculate zoom scale based on date range
                if let firstDate = dates.first, let lastDate = dates.last {
                    let months = Calendar.current.dateComponents([.month], from: firstDate, to: lastDate).month ?? 0
                    let maxZoom = Double(max(1, months + 1)) * 3.0
                    uiView.viewPortHandler.setMaximumScaleX(maxZoom)
                }
                
                if let formatter = uiView.xAxis.valueFormatter as? DateAxisValueFormatter {
                    formatter.dates = dates
                }
                
                let chartEntries = sorted.map { entry -> ChartDataEntry in
                    let chartEntry = ChartDataEntry(x: (entry.timestamp ?? Date()).timeIntervalSince1970, y: entry.value)
                    if let note = entry.note, !note.isEmpty {
                        chartEntry.data = note
                    }
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
                    
                    // Store all entries in coordinator and update initial axis limits
                    context.coordinator.allEntries = chartEntries
                    context.coordinator.updateAxisLimits()
                }
            } catch {
                uiView.data = nil
                uiView.noDataText = "Error loading data"
            }
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
        let date = Date(timeIntervalSince1970: value)
        return dateFormatter.string(from: date)
    }
    
    // Add method to generate all dates in range
    func generateAllDates() -> [Date] {
        guard let firstDate = dates.first, let lastDate = dates.last else { return dates }
        
        var allDates: [Date] = []
        var currentDate = firstDate
        
        while currentDate <= lastDate {
            allDates.append(currentDate)
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return allDates
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
    @State private var isLoading: Bool = false
    @State private var hasMoreData: Bool = true
    @State private var currentPage: Int = 0
    private let pageSize: Int = 10
    @Environment(\.managedObjectContext) private var context
    @State private var selectedImage: UIImage? = nil
    @State private var selectedEntry: MeasurementEntry? = nil
    
    // Track visible entries to manage memory
    @State private var visibleEntryIds: Set<NSManagedObjectID> = []
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(entries.sorted(by: { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }), id: \.self) { entry in
                    PictureEntryView(
                        entry: entry,
                        isVisible: visibleEntryIds.contains(entry.objectID),
                        onAppear: {
                            visibleEntryIds.insert(entry.objectID)
                            // Load more data when we're near the end
                            if entry == entries.sorted(by: { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }).last {
                                loadMoreData()
                            }
                        },
                        onDisappear: {
                            visibleEntryIds.remove(entry.objectID)
                        },
                        onTap: {
                            selectedImage = entry.image.flatMap { UIImage(data: $0) }
                            selectedEntry = entry
                        }
                    )
                }
                
                if isLoading {
                    ProgressView()
                        .frame(width: 120, height: 120)
                }
            }
            .padding(.horizontal, 16)
        }
        .onAppear(perform: fetchInitialEntries)
        .onChange(of: type) { oldValue, newValue in
            resetAndFetch()
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
    
    private func resetAndFetch() {
        entries = []
        currentPage = 0
        hasMoreData = true
        visibleEntryIds.removeAll()
        fetchInitialEntries()
    }
    
    private func fetchInitialEntries() {
        guard entries.isEmpty else { return }
        loadMoreData()
    }
    
    private func loadMoreData() {
        guard !isLoading && hasMoreData else { return }
        isLoading = true
        
        let request: NSFetchRequest<MeasurementEntry> = MeasurementEntry.fetchRequest()
        request.predicate = NSPredicate(format: "type == %@", type)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchOffset = currentPage * pageSize
        request.fetchLimit = pageSize
        
        do {
            let newEntries = try context.fetch(request)
            if newEntries.isEmpty {
                hasMoreData = false
            } else {
                entries.append(contentsOf: newEntries)
                currentPage += 1
            }
        } catch {
            print("Error fetching entries: \(error)")
        }
        
        isLoading = false
    }
}

// Separate view for each picture entry to better manage memory
struct PictureEntryView: View {
    let entry: MeasurementEntry
    let isVisible: Bool
    let onAppear: () -> Void
    let onDisappear: () -> Void
    let onTap: () -> Void
    
    // Cache the image only when visible
    @State private var cachedImage: UIImage? = nil
    
    var body: some View {
        VStack {
            if isVisible {
                if let image = cachedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipped()
                        .cornerRadius(8)
                        .onTapGesture(perform: onTap)
                } else if let imageData = entry.image {
                    Image(uiImage: UIImage(data: imageData)!)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipped()
                        .cornerRadius(8)
                        .onTapGesture(perform: onTap)
                        .onAppear {
                            // Cache the image when it becomes visible
                            cachedImage = UIImage(data: imageData)
                        }
                }
            } else {
                // Placeholder when not visible
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .cornerRadius(8)
            }
            
            if let date = entry.timestamp {
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear(perform: onAppear)
        .onDisappear {
            onDisappear()
            // Clear cached image when view disappears
            cachedImage = nil
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
