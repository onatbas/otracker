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
                return "\(result.clean) \(type.unit ?? "")"
            } else {
                return type.unit ?? ""
            }
        } else {
            if let entries = type.entries as? Set<MeasurementEntry>,
               let latest = entries.sorted(by: { ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast) }).first {
                return "\(latest.value.clean) \(type.unit ?? "")"
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
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> LineChartView {
        let chartView = LineChartView()
        chartView.rightAxis.enabled = false
        chartView.xAxis.labelPosition = .bottom
        chartView.legend.enabled = false
        chartView.setScaleEnabled(true)
        chartView.pinchZoomEnabled = true
        chartView.doubleTapToZoomEnabled = true
        chartView.highlightPerTapEnabled = true
        chartView.dragEnabled = true
        chartView.animate(xAxisDuration: 0.5)
        chartView.scaleYEnabled = false
        return chartView
    }
    
    func updateUIView(_ uiView: LineChartView, context: Context) {
        if let hkIdStr = type.healthKitIdentifier {
            let hkId = HKQuantityTypeIdentifier(rawValue: hkIdStr)
            HealthKitManager.shared.fetchAllQuantitySamples(for: hkId) { samples in
                DispatchQueue.main.async {
                    context.coordinator.healthKitSamples = samples
                    let sorted = samples.sorted { $0.endDate < $1.endDate }
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
                        default: value = sample.quantity.doubleValue(for: .count())
                        }
                        return ChartDataEntry(x: Double(idx), y: value)
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
            let chartEntries: [ChartDataEntry] = sortedDays.enumerated().map { (idx, dayStr) in
                let values = validDays[dayStr]!
                let expr = NSExpression(format: formula)
                let result = expr.expressionValue(with: values, context: nil) as? Double ?? 0.0
                return ChartDataEntry(x: Double(idx), y: result)
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
            let chartEntries = sorted.enumerated().map { (idx, entry) -> ChartDataEntry in
                ChartDataEntry(x: Double(idx), y: entry.value)
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

struct PictureGalleryView: View {
    let type: MeasurementType
    @State private var entries: [MeasurementEntry] = []
    @Environment(\.managedObjectContext) private var context
    @State private var selectedImage: UIImage? = nil
    
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
                                .onTapGesture { selectedImage = uiImage }
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
        .onChange(of: type) { _ in fetchEntries() }
        .fullScreenCover(isPresented: Binding<Bool>(
            get: { selectedImage != nil },
            set: { if !$0 { selectedImage = nil } }
        )) {
            if let image = selectedImage {
                ImagePreviewView(image: image) {
                    selectedImage = nil
                }
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

struct ImagePreviewView: View, Identifiable {
    let id = UUID()
    let image: UIImage
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 36, height: 36)
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}

extension Double {
    var clean: String {
        return truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", self) : String(self)
    }
} 