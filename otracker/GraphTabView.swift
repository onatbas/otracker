import SwiftUI
import Charts
import CoreData
import DGCharts

struct GraphTabView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        entity: MeasurementType.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \MeasurementType.name, ascending: true)]
    ) private var measurementTypes: FetchedResults<MeasurementType>
    
    @State private var selectedType: MeasurementType?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let type = selectedType ?? measurementTypes.first {
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
                    ForEach(measurementTypes, id: \.self) { type in
                        HStack {
                            if let colorHex = type.color {
                                Circle()
                                    .fill(Color(UIColor(hex: colorHex)))
                                    .frame(width: 16, height: 16)
                            }
                            Text(type.name ?? "")
                            Spacer()
                            Text(type.unit ?? "")
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedType = type }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Graph")
        }
    }
}

struct DGLineChartViewRepresentable: UIViewRepresentable {
    let type: MeasurementType
    @Environment(\.managedObjectContext) private var context
    
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
        return chartView
    }
    
    func updateUIView(_ uiView: LineChartView, context: Context) {
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
        uiView.xAxis.valueFormatter = IndexAxisValueFormatter(values: sorted.compactMap { entry in
            if let date = entry.timestamp {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                return formatter.string(from: date)
            }
            return ""
        })
        uiView.xAxis.granularity = 1
        uiView.notifyDataSetChanged()
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