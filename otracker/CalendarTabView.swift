import SwiftUI
import CoreData

struct CalendarCell: View {
    let date: Date
    let measurementType: MeasurementType
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let entry = fetchEntry() {
                Text(String(format: "%.2f", entry.value))
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray6))
                        .cornerRadius(4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(4)
        .background(Color(.systemBackground))
    }
    
    private func fetchEntry() -> MeasurementEntry? {
        let request: NSFetchRequest<MeasurementEntry> = MeasurementEntry.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp == %@ AND measurementType == %@", date as NSDate, measurementType)
        return try? viewContext.fetch(request).first
    }
} 