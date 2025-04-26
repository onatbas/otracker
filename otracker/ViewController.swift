//
//  ViewController.swift
//  otracker
//
//  Created by Onat Bas on 2025-04-26.
//

import UIKit
import CoreData

class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewControllers()
    }
    
    private func setupViewControllers() {
        let categoriesVC = CategoriesViewController()
        categoriesVC.tabBarItem = UITabBarItem(title: "Categories", image: UIImage(systemName: "list.bullet"), tag: 0)
        
        let measurementsVC = MeasurementsViewController()
        measurementsVC.tabBarItem = UITabBarItem(title: "Measurements", image: UIImage(systemName: "ruler"), tag: 1)
        
        let calendarVC = CalendarViewController()
        calendarVC.tabBarItem = UITabBarItem(title: "Calendar", image: UIImage(systemName: "calendar"), tag: 2)
        
        viewControllers = [categoriesVC, measurementsVC, calendarVC]
    }
}

class AddCategoryViewController: UIViewController, UITextFieldDelegate {
    private let nameTextField = UITextField()
    private let unitTextField = UITextField()
    private let unitOptions = ["cm", "ft", "kg", "lb", "%", "in", "min", "#", "Picture", "Custom"]
    private var unitButtons: [UIButton] = []
    private var selectedUnit: String = "cm"
    private let saveButton = UIButton(type: .system)
    private let colorOptions: [UIColor] = [
        UIColor(red: 0.91, green: 0.30, blue: 0.32, alpha: 1.0), // red
        UIColor(red: 0.96, green: 0.47, blue: 0.23, alpha: 1.0), // orange
        UIColor(red: 0.48, green: 0.76, blue: 0.35, alpha: 1.0), // green
        UIColor(red: 0.27, green: 0.60, blue: 0.78, alpha: 1.0), // blue
        UIColor(red: 0.41, green: 0.35, blue: 0.80, alpha: 1.0), // purple
        UIColor(red: 0.99, green: 0.76, blue: 0.18, alpha: 1.0), // yellow
        UIColor(red: 0.20, green: 0.68, blue: 0.47, alpha: 1.0), // teal
        UIColor(red: 0.93, green: 0.51, blue: 0.47, alpha: 1.0), // coral
        UIColor(red: 0.60, green: 0.60, blue: 0.60, alpha: 1.0), // gray
        UIColor(red: 0.13, green: 0.59, blue: 0.95, alpha: 1.0)  // light blue
    ]
    private var colorButtons: [UIButton] = []
    private var selectedColor: UIColor
    private let completion: (String, String, UIColor) -> Void
    
    init(completion: @escaping (String, String, UIColor) -> Void) {
        self.completion = completion
        self.selectedColor = UIColor(red: 0.91, green: 0.30, blue: 0.32, alpha: 1.0) // default to first color
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        nameTextField.delegate = self
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Add Category"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
        
        nameTextField.placeholder = "Name (e.g., Neck)"
        nameTextField.borderStyle = .roundedRect
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Unit grid
        let unitGridStack = UIStackView()
        unitGridStack.axis = .vertical
        unitGridStack.spacing = 12
        unitGridStack.translatesAutoresizingMaskIntoConstraints = false
        let unitsPerRow = 4
        unitButtons = []
        for row in 0..<(unitOptions.count / unitsPerRow + (unitOptions.count % unitsPerRow == 0 ? 0 : 1)) {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 12
            rowStack.distribution = .equalSpacing
            for col in 0..<unitsPerRow {
                let idx = row * unitsPerRow + col
                if idx < unitOptions.count {
                    let unit = unitOptions[idx]
                    let button = UIButton(type: .system)
                    if unit == "Picture" {
                        let cameraImage = UIImage(systemName: "camera")
                        button.setImage(cameraImage, for: .normal)
                        button.tintColor = .label
                        button.setTitle(nil, for: .normal)
                    } else {
                        button.setTitle(unit, for: .normal)
                        button.setTitleColor(.label, for: .normal)
                    }
                    button.backgroundColor = .systemGray6
                    button.layer.cornerRadius = 8
                    button.layer.borderWidth = (unit == selectedUnit) ? 2 : 0
                    button.layer.borderColor = (unit == selectedUnit) ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
                    button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
                    button.translatesAutoresizingMaskIntoConstraints = false
                    button.widthAnchor.constraint(equalToConstant: 60).isActive = true
                    button.heightAnchor.constraint(equalToConstant: 36).isActive = true
                    button.tag = idx
                    button.addTarget(self, action: #selector(unitSelected(_:)), for: .touchUpInside)
                    unitButtons.append(button)
                    rowStack.addArrangedSubview(button)
                }
            }
            unitGridStack.addArrangedSubview(rowStack)
        }
        // Custom unit text field
        unitTextField.placeholder = "Custom unit"
        unitTextField.borderStyle = .roundedRect
        unitTextField.translatesAutoresizingMaskIntoConstraints = false
        unitTextField.isHidden = true
        
        // Color grid
        let colorGridStack = UIStackView()
        colorGridStack.axis = .vertical
        colorGridStack.spacing = 16
        colorGridStack.translatesAutoresizingMaskIntoConstraints = false
        
        let colorsPerRow = 5
        colorButtons = []
        for row in 0..<(colorOptions.count / colorsPerRow + (colorOptions.count % colorsPerRow == 0 ? 0 : 1)) {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 24
            rowStack.distribution = .equalSpacing
            for col in 0..<colorsPerRow {
                let idx = row * colorsPerRow + col
                if idx < colorOptions.count {
                    let color = colorOptions[idx]
                    let button = UIButton(type: .system)
                    button.backgroundColor = color
                    button.layer.cornerRadius = 24
                    button.layer.masksToBounds = true
                    button.translatesAutoresizingMaskIntoConstraints = false
                    button.widthAnchor.constraint(equalToConstant: 48).isActive = true
                    button.heightAnchor.constraint(equalToConstant: 48).isActive = true
                    button.tag = idx
                    button.addTarget(self, action: #selector(colorSelected(_:)), for: .touchUpInside)
                    if color == selectedColor {
                        button.layer.borderWidth = 4
                        button.layer.borderColor = UIColor.systemBlue.cgColor
                    } else {
                        button.layer.borderWidth = 0
                    }
                    colorButtons.append(button)
                    rowStack.addArrangedSubview(button)
                }
            }
            colorGridStack.addArrangedSubview(rowStack)
        }
        
        saveButton.setTitle("Save", for: .normal)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 8
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(nameTextField)
        view.addSubview(unitGridStack)
        view.addSubview(unitTextField)
        view.addSubview(colorGridStack)
        view.addSubview(saveButton)
        
        NSLayoutConstraint.activate([
            nameTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            nameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            nameTextField.heightAnchor.constraint(equalToConstant: 44),
            
            unitGridStack.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 20),
            unitGridStack.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            unitGridStack.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            unitTextField.topAnchor.constraint(equalTo: unitGridStack.bottomAnchor, constant: 8),
            unitTextField.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            unitTextField.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            unitTextField.heightAnchor.constraint(equalToConstant: 44),
            
            colorGridStack.topAnchor.constraint(equalTo: unitTextField.bottomAnchor, constant: 24),
            colorGridStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            saveButton.topAnchor.constraint(equalTo: colorGridStack.bottomAnchor, constant: 32),
            saveButton.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            saveButton.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            saveButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func unitSelected(_ sender: UIButton) {
        let idx = sender.tag
        selectedUnit = unitOptions[idx]
        for (i, button) in unitButtons.enumerated() {
            if i == idx {
                button.layer.borderWidth = 2
                button.layer.borderColor = UIColor.systemBlue.cgColor
            } else {
                button.layer.borderWidth = 0
            }
        }
        if selectedUnit == "Custom" {
            unitTextField.isHidden = false
        } else {
            unitTextField.isHidden = true
        }
    }
    
    @objc private func colorSelected(_ sender: UIButton) {
        let idx = sender.tag
        selectedColor = colorOptions[idx]
        for (i, button) in colorButtons.enumerated() {
            if i == idx {
                button.layer.borderWidth = 4
                button.layer.borderColor = UIColor.systemBlue.cgColor
            } else {
                button.layer.borderWidth = 0
            }
        }
    }
    
    @objc private func saveButtonTapped() {
        guard let name = nameTextField.text, !name.isEmpty else {
            return
        }
        let unit: String
        if selectedUnit == "Custom" {
            guard let customUnit = unitTextField.text, !customUnit.isEmpty else { return }
            unit = customUnit
        } else {
            unit = selectedUnit
        }
        completion(name, unit, selectedColor)
        dismiss(animated: true)
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == nameTextField {
            saveButtonTapped()
            return false
        }
        return true
    }
}

class CategoriesViewController: UIViewController {
    private let tableView = UITableView()
    private let addButton = UIButton(type: .system)
    private var measurementTypes: [MeasurementType] = []
    private let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadMeasurementTypes()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Categories"
        
        // Configure table view
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)
        
        // Configure add button
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.setTitle("Add Category", for: .normal)
        addButton.addTarget(self, action: #selector(addCategory), for: .touchUpInside)
        view.addSubview(addButton)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: addButton.topAnchor),
            
            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            addButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func loadMeasurementTypes() {
        let request: NSFetchRequest<MeasurementType> = MeasurementType.fetchRequest()
        do {
            measurementTypes = try context.fetch(request)
            tableView.reloadData()
        } catch {
            print("Error loading measurement types: \(error)")
        }
    }
    
    @objc private func addCategory() {
        let addCategoryVC = AddCategoryViewController { [weak self] name, unit, color in
            let measurementType = MeasurementType(context: self!.context)
            measurementType.name = name
            measurementType.unit = unit
            measurementType.color = color.toHex()
            
            do {
                try self?.context.save()
                self?.loadMeasurementTypes()
            } catch {
                print("Error saving measurement type: \(error)")
            }
        }
        
        let nav = UINavigationController(rootViewController: addCategoryVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }
}

extension CategoriesViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return measurementTypes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let measurementType = measurementTypes[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = measurementType.name
        content.secondaryText = "Unit: \(measurementType.unit ?? "")"
        if let colorHex = measurementType.color {
            let color = UIColor(hex: colorHex)
            content.image = UIImage(systemName: "circle.fill")?.withTintColor(color, renderingMode: .alwaysOriginal)
        }
        cell.contentConfiguration = content
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let measurementType = measurementTypes[indexPath.row]
            
            // Delete all associated measurements first
            if let entries = measurementType.entries?.allObjects as? [MeasurementEntry] {
                for entry in entries {
                    context.delete(entry)
                }
            }
            
            // Then delete the measurement type
            context.delete(measurementType)
            
            do {
                try context.save()
                measurementTypes.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
            } catch {
                print("Error deleting measurement type: \(error)")
            }
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
}

class MeasurementsViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let tableView = UITableView()
    private var measurementTypes: [MeasurementType] = []
    private let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    private var expandedSections: Set<Int> = []
    private var imagePickerCompletion: ((UIImage) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadMeasurementTypes()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadMeasurementTypes()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Measurements"
        
        // Configure table view
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func loadMeasurementTypes() {
        let request: NSFetchRequest<MeasurementType> = MeasurementType.fetchRequest()
        do {
            measurementTypes = try context.fetch(request)
            tableView.reloadData()
        } catch {
            print("Error loading measurement types: \(error)")
        }
    }
    
    private func addMeasurement(for type: MeasurementType) {
        if type.unit == "Picture" {
            let actionSheet = UIAlertController(title: "Add Picture", message: nil, preferredStyle: .actionSheet)
            actionSheet.addAction(UIAlertAction(title: "Take Photo", style: .default, handler: { [weak self] _ in
                self?.presentImagePicker(sourceType: .camera) { image in
                    self?.savePictureEntry(image: image, type: type)
                }
            }))
            actionSheet.addAction(UIAlertAction(title: "Choose from Library", style: .default, handler: { [weak self] _ in
                self?.presentImagePicker(sourceType: .photoLibrary) { image in
                    self?.savePictureEntry(image: image, type: type)
                }
            }))
            actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            if let popover = actionSheet.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            present(actionSheet, animated: true)
        } else {
            let addVC = AddMeasurementViewController(type: type) { [weak self] value, date in
                guard let self = self else { return }
                let entry = MeasurementEntry(context: self.context)
                entry.value = value
                entry.timestamp = date
                entry.type = type
                do {
                    try self.context.save()
                    self.tableView.reloadData()
                    NotificationCenter.default.post(name: .measurementAdded, object: nil)
                } catch {
                    print("Error saving measurement entry: \(error)")
                }
            }
            let nav = UINavigationController(rootViewController: addVC)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }
    
    private func presentImagePicker(sourceType: UIImagePickerController.SourceType = .photoLibrary, completion: @escaping (UIImage) -> Void) {
        imagePickerCompletion = completion
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        present(picker, animated: true)
    }
    
    private func savePictureEntry(image: UIImage, type: MeasurementType) {
        let entry = MeasurementEntry(context: self.context)
        entry.timestamp = Date()
        entry.type = type
        entry.value = 0 // Not used for picture
        entry.image = image.jpegData(compressionQuality: 0.8)
        do {
            try self.context.save()
            self.tableView.reloadData()
            NotificationCenter.default.post(name: .measurementAdded, object: nil)
        } catch {
            print("Error saving picture measurement entry: \(error)")
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage {
            imagePickerCompletion?(image)
        }
        imagePickerCompletion = nil
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        imagePickerCompletion = nil
    }
    
    private func toggleSection(_ section: Int) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
        tableView.reloadSections(IndexSet(integer: section), with: .automatic)
    }
}

extension MeasurementsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return measurementTypes.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return measurementTypes[section].name
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = .systemBackground
        headerView.tag = section
        
        let titleLabel = UILabel()
        titleLabel.text = measurementTypes[section].name
        titleLabel.font = .boldSystemFont(ofSize: 16)
        if let colorHex = measurementTypes[section].color {
            titleLabel.textColor = UIColor(hex: colorHex)
        }
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let addButton = UIButton(type: .system)
        addButton.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        if let colorHex = measurementTypes[section].color {
            addButton.tintColor = UIColor(hex: colorHex)
        }
        addButton.tag = section
        addButton.addTarget(self, action: #selector(addButtonTapped(_:)), for: .touchUpInside)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        
        let chevronImage = UIImage(systemName: expandedSections.contains(section) ? "chevron.down" : "chevron.right")
        let chevronButton = UIButton(type: .system)
        chevronButton.setImage(chevronImage, for: .normal)
        chevronButton.tintColor = .systemGray
        chevronButton.tag = section
        chevronButton.addTarget(self, action: #selector(headerTapped(_:)), for: .touchUpInside)
        chevronButton.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(addButton)
        headerView.addSubview(chevronButton)
        
        NSLayoutConstraint.activate([
            chevronButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            chevronButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            chevronButton.widthAnchor.constraint(equalToConstant: 24),
            chevronButton.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: chevronButton.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            addButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            addButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            headerView.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Make the entire header tappable
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(headerTapped(_:)))
        headerView.addGestureRecognizer(tapGesture)
        
        return headerView
    }
    
    @objc private func addButtonTapped(_ sender: UIButton) {
        let measurementType = measurementTypes[sender.tag]
        addMeasurement(for: measurementType)
    }
    
    @objc private func headerTapped(_ sender: Any) {
        let section: Int
        if let button = sender as? UIButton {
            section = button.tag
        } else if let gesture = sender as? UITapGestureRecognizer,
                  let headerView = gesture.view {
            section = headerView.tag
        } else {
            return
        }
        toggleSection(section)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return expandedSections.contains(section) ? (measurementTypes[section].entries?.count ?? 0) : 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let measurementType = measurementTypes[indexPath.section]
        if let entry = measurementType.entries?.allObjects[indexPath.row] as? MeasurementEntry {
            var content = cell.defaultContentConfiguration()
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            if measurementType.unit == "Picture", let imageData = entry.image, let image = UIImage(data: imageData) {
                // Resize image to thumbnail (44x44)
                let thumbnailSize = CGSize(width: 44, height: 44)
                let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
                let thumbnail = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
                }
                content.image = thumbnail
                content.imageProperties.cornerRadius = 8
                content.imageProperties.maximumSize = thumbnailSize
                content.text = nil
                content.secondaryText = formatter.string(from: entry.timestamp ?? Date())
                cell.contentConfiguration = content
                cell.selectionStyle = .default
            } else {
                content.text = "\(entry.value) \(measurementType.unit ?? "")"
                content.secondaryText = formatter.string(from: entry.timestamp ?? Date())
                if let colorHex = measurementType.color {
                    content.textProperties.color = UIColor(hex: colorHex)
                }
                cell.contentConfiguration = content
                cell.selectionStyle = .none
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let measurementType = measurementTypes[indexPath.section]
            if let entry = measurementType.entries?.allObjects[indexPath.row] as? MeasurementEntry {
                context.delete(entry)
                do {
                    try context.save()
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                } catch {
                    print("Error deleting measurement entry: \(error)")
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let measurementType = measurementTypes[indexPath.section]
        if measurementType.unit == "Picture",
           let entry = measurementType.entries?.allObjects[indexPath.row] as? MeasurementEntry,
           let imageData = entry.image,
           let image = UIImage(data: imageData) {
            let previewVC = ImagePreviewViewController(image: image)
            present(previewVC, animated: true)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// Helper extensions
extension UIColor {
    func toHex() -> String? {
        guard let components = cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
    
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

// MARK: - Image Preview View Controller
class ImagePreviewViewController: UIViewController {
    private let image: UIImage
    
    init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        let shareButton = UIButton(type: .system)
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        shareButton.tintColor = .white
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        view.addSubview(shareButton)
        NSLayoutConstraint.activate([
            shareButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            shareButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            shareButton.widthAnchor.constraint(equalToConstant: 36),
            shareButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func shareTapped() {
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = self.view
        present(activityVC, animated: true)
    }
}

// MARK: - Add Measurement View Controller
class AddMeasurementViewController: UIViewController, UITextFieldDelegate {
    private let type: MeasurementType
    private let completion: (Double, Date) -> Void
    private let valueTextField = UITextField()
    private let saveButton = UIButton(type: .system)
    private let datePicker = UIDatePicker()
    
    init(type: MeasurementType, completion: @escaping (Double, Date) -> Void) {
        self.type = type
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Add Measurement"
        setupUI()
    }
    
    private func setupUI() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeTapped))
        
        let nameLabel = UILabel()
        nameLabel.text = type.name
        nameLabel.font = .systemFont(ofSize: 24, weight: .bold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nameLabel)
        
        valueTextField.placeholder = "Value in \(type.unit ?? "")"
        valueTextField.borderStyle = .roundedRect
        valueTextField.keyboardType = .decimalPad
        valueTextField.delegate = self
        valueTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(valueTextField)
        
        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .compact
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.maximumDate = Date().addingTimeInterval(60*60*24*365) // 1 year in future
        datePicker.minimumDate = Date().addingTimeInterval(-60*60*24*365*10) // 10 years in past
        datePicker.date = Date()
        view.addSubview(datePicker)
        
        saveButton.setTitle("Save", for: .normal)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 8
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(saveButton)
        
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            nameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            valueTextField.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 40),
            valueTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            valueTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            valueTextField.heightAnchor.constraint(equalToConstant: 44),
            
            datePicker.topAnchor.constraint(equalTo: valueTextField.bottomAnchor, constant: 24),
            datePicker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            saveButton.topAnchor.constraint(equalTo: datePicker.bottomAnchor, constant: 40),
            saveButton.leadingAnchor.constraint(equalTo: valueTextField.leadingAnchor),
            saveButton.trailingAnchor.constraint(equalTo: valueTextField.trailingAnchor),
            saveButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func saveButtonTapped() {
        guard let valueText = valueTextField.text, let value = Double(valueText) else { return }
        completion(value, datePicker.date)
        dismiss(animated: true)
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == valueTextField {
            saveButtonTapped()
            return false
        }
        return true
    }
}

extension Notification.Name {
    static let measurementAdded = Notification.Name("MeasurementAdded")
}

