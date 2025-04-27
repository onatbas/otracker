import Foundation
import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()
    
    private init() {}
    
    // MARK: - Authorization
    func requestAuthorization(toShare shareTypes: Set<HKSampleType>, read readTypes: Set<HKObjectType>, completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Health data not available on this device."]))
            return
        }
        // Convert read types to share types for writing
        let typesToShare = readTypes.compactMap { $0 as? HKSampleType }
        healthStore.requestAuthorization(toShare: Set(typesToShare), read: readTypes, completion: completion)
    }
    
    // MARK: - Read Quantity Samples
    func fetchMostRecentQuantitySample(for identifier: HKQuantityTypeIdentifier, completion: @escaping (HKQuantitySample?) -> Void) {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            completion(nil)
            return
        }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: quantityType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            let sample = samples?.first as? HKQuantitySample
            completion(sample)
        }
        healthStore.execute(query)
    }
    
    // MARK: - Write Quantity Sample
    func saveQuantitySample(identifier: HKQuantityTypeIdentifier, value: Double, unit: HKUnit, date: Date = Date(), completion: ((Bool, Error?) -> Void)? = nil) {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            completion?(false, NSError(domain: "HealthKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid quantity type identifier."]))
            return
        }
        let quantity = HKQuantity(unit: unit, doubleValue: value)
        let sample = HKQuantitySample(type: quantityType, quantity: quantity, start: date, end: date)
        healthStore.save(sample, withCompletion: { success, error in
            completion?(success, error)
        })
    }
    
    // MARK: - Read All Quantity Samples
    func fetchAllQuantitySamples(for identifier: HKQuantityTypeIdentifier, completion: @escaping ([HKQuantitySample]) -> Void) {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            completion([])
            return
        }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        let query = HKSampleQuery(sampleType: quantityType, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            let quantitySamples = samples as? [HKQuantitySample] ?? []
            completion(quantitySamples)
        }
        healthStore.execute(query)
    }
    
    // MARK: - Delete Quantity Sample
    func deleteQuantitySample(identifier: HKQuantityTypeIdentifier, date: Date, completion: ((Bool, Error?) -> Void)? = nil) {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            completion?(false, NSError(domain: "HealthKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid quantity type identifier."]))
            return
        }
        
        // Create a predicate to find samples within a small time window around the target date
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .second, value: -1, to: date)!
        let endDate = calendar.date(byAdding: .second, value: 1, to: date)!
        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        // Query for samples within this time window
        let query = HKSampleQuery(sampleType: quantityType, predicate: datePredicate, limit: 10, sortDescriptors: nil) { [weak self] (query, samples, error) in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    completion?(false, error)
                }
                return
            }
            
            guard let samples = samples else {
                DispatchQueue.main.async {
                    completion?(false, NSError(domain: "HealthKit", code: 3, userInfo: [NSLocalizedDescriptionKey: "No samples found."]))
                }
                return
            }
            
            // Find the sample closest to our target date
            let targetSamples = samples.filter { abs($0.startDate.timeIntervalSince(date)) < 1.0 }
            
            guard !targetSamples.isEmpty else {
                DispatchQueue.main.async {
                    completion?(false, NSError(domain: "HealthKit", code: 3, userInfo: [NSLocalizedDescriptionKey: "No sample found for the specified date."]))
                }
                return
            }
            
            // Delete the found samples
            self.healthStore.delete(targetSamples) { (success, error) in
                DispatchQueue.main.async {
                    completion?(success, error)
                }
            }
        }
        
        healthStore.execute(query)
    }
} 