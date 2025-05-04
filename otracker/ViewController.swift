//
//  ViewController.swift
//  otracker
//
//  Created by Onat Bas on 2025-04-26.
//

import UIKit
import CoreData
import Charts
import SwiftUI
import HealthKit
import MathParser


class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()

        setupViewControllers()
    }
    
    private func setupViewControllers() {
        let categoriesVC = CategoriesViewController()
        categoriesVC.tabBarItem = UITabBarItem(title: "Categories", image: UIImage(systemName: "list.bullet"), tag: 0)
        let categoriesNav = UINavigationController(rootViewController: categoriesVC)
        
        let measurementsVC = MeasurementsViewController()
        measurementsVC.tabBarItem = UITabBarItem(title: "Measurements", image: UIImage(systemName: "ruler"), tag: 1)
        let measurementsNav = UINavigationController(rootViewController: measurementsVC)
        
        let calendarVC = CalendarViewController()
        calendarVC.tabBarItem = UITabBarItem(title: "Calendar", image: UIImage(systemName: "calendar"), tag: 2)
        let calendarNav = UINavigationController(rootViewController: calendarVC)
        
        // Add SwiftUI GraphTabView as the fourth tab
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let graphVC = UIHostingController(rootView: GraphTabView().environment(\.managedObjectContext, context))
        graphVC.tabBarItem = UITabBarItem(title: "Graph", image: UIImage(systemName: "chart.xyaxis.line"), tag: 3)
        let graphNav = UINavigationController(rootViewController: graphVC)
        
        // Add Settings tab
        let settingsVC = SettingsViewController()
        settingsVC.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gear"), tag: 4)
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        
        // Configure navigation bar appearance for all navigation controllers
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = .systemBackground
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        let navigationControllers = [categoriesNav, measurementsNav, calendarNav, graphNav, settingsNav]
        for navController in navigationControllers {
            navController.navigationBar.standardAppearance = navAppearance
            navController.navigationBar.scrollEdgeAppearance = navAppearance
            navController.navigationBar.compactAppearance = navAppearance
            navController.navigationBar.tintColor = .label
        }
        
        // Configure tab bar appearance
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = .systemBackground
        tabBar.standardAppearance = tabAppearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = tabAppearance
        }
        tabBar.tintColor = .systemBlue
        tabBar.unselectedItemTintColor = .secondaryLabel
        
        viewControllers = navigationControllers
    }
}

class AddCategoryViewController: UIViewController, UITextFieldDelegate, UIPickerViewDataSource, UIPickerViewDelegate {
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
    private let healthKitTypes: [(name: String, identifier: String?)] = [
        ("None", nil),
        ("Weight (kg)", "HKQuantityTypeIdentifierBodyMass"),
        ("Height (m)", "HKQuantityTypeIdentifierHeight"),
        ("Body Fat %", "HKQuantityTypeIdentifierBodyFatPercentage"),
        ("BMI", "HKQuantityTypeIdentifierBodyMassIndex"),
        ("Steps", "HKQuantityTypeIdentifierStepCount"),
        ("Heart Rate", "HKQuantityTypeIdentifierHeartRate"),
        ("Active Energy (kcal)", "HKQuantityTypeIdentifierActiveEnergyBurned"),
        ("Resting Energy (kcal)", "HKQuantityTypeIdentifierBasalEnergyBurned"),
        ("Waist Circumference (cm)", "HKQuantityTypeIdentifierWaistCircumference")
    ]
    private var selectedHealthKitTypeIndex: Int = 0
    private let healthKitPicker = UIPickerView()
    private let healthKitLabel = UILabel()
    private let linkHealthButton = UIButton(type: .system)
    private var healthKitPickerVisible = false
    private let completion: (String, String, UIColor, Bool, String?, String?, String?) -> Void
    private let formulaSwitch = UISwitch()
    private let formulaLabel = UILabel()
    private let formulaTextField = UITextField()
    private let dependenciesTextField = UITextField()
    private var isFormula: Bool = false
    private var formula: String? = nil
    private var dependencies: String? = nil

    init(completion: @escaping (String, String, UIColor, Bool, String?, String?, String?) -> Void) {
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
        unitTextField.delegate = self
        formulaTextField.delegate = self
        dependenciesTextField.delegate = self
        healthKitPicker.dataSource = self
        healthKitPicker.delegate = self
        // Add Done button to navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(saveButtonTapped))
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
        
        // HealthKit link button
        linkHealthButton.setTitle("Link with Health Data", for: .normal)
        linkHealthButton.setTitleColor(.systemBlue, for: .normal)
        linkHealthButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        linkHealthButton.translatesAutoresizingMaskIntoConstraints = false
        linkHealthButton.addTarget(self, action: #selector(linkHealthTapped), for: .touchUpInside)
        
        // HealthKit picker and label (hidden by default)
        healthKitLabel.text = "Apple Health Data Type (optional)"
        healthKitLabel.font = .systemFont(ofSize: 16, weight: .medium)
        healthKitLabel.translatesAutoresizingMaskIntoConstraints = false
        healthKitLabel.isHidden = true
        healthKitPicker.translatesAutoresizingMaskIntoConstraints = false
        healthKitPicker.isHidden = true
        
        formulaLabel.text = "Formula"
        formulaLabel.font = .systemFont(ofSize: 18, weight: .medium)
        formulaLabel.translatesAutoresizingMaskIntoConstraints = false
        formulaSwitch.translatesAutoresizingMaskIntoConstraints = false
        formulaSwitch.addTarget(self, action: #selector(formulaSwitchChanged), for: .valueChanged)
        formulaTextField.placeholder = "Formula (e.g. DIAMETER*3.14*2)"
        formulaTextField.borderStyle = .roundedRect
        formulaTextField.translatesAutoresizingMaskIntoConstraints = false
        formulaTextField.isHidden = true
        dependenciesTextField.placeholder = "Dependencies (comma-separated, e.g. DIAMETER)"
        dependenciesTextField.borderStyle = .roundedRect
        dependenciesTextField.translatesAutoresizingMaskIntoConstraints = false
        dependenciesTextField.isHidden = true
        
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
        view.addSubview(linkHealthButton)
        view.addSubview(healthKitLabel)
        view.addSubview(healthKitPicker)
        view.addSubview(formulaLabel)
        view.addSubview(formulaSwitch)
        view.addSubview(formulaTextField)
        view.addSubview(dependenciesTextField)
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
            
            linkHealthButton.topAnchor.constraint(equalTo: colorGridStack.bottomAnchor, constant: 24),
            linkHealthButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            healthKitLabel.topAnchor.constraint(equalTo: linkHealthButton.bottomAnchor, constant: 12),
            healthKitLabel.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            healthKitPicker.topAnchor.constraint(equalTo: healthKitLabel.bottomAnchor, constant: 8),
            healthKitPicker.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            healthKitPicker.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            healthKitPicker.heightAnchor.constraint(equalToConstant: 100),
            
            formulaLabel.topAnchor.constraint(equalTo: healthKitPicker.bottomAnchor, constant: 24),
            formulaLabel.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            formulaSwitch.centerYAnchor.constraint(equalTo: formulaLabel.centerYAnchor),
            formulaSwitch.leadingAnchor.constraint(equalTo: formulaLabel.trailingAnchor, constant: 12),
            formulaTextField.topAnchor.constraint(equalTo: formulaLabel.bottomAnchor, constant: 12),
            formulaTextField.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            formulaTextField.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            formulaTextField.heightAnchor.constraint(equalToConstant: 44),
            dependenciesTextField.topAnchor.constraint(equalTo: formulaTextField.bottomAnchor, constant: 8),
            dependenciesTextField.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            dependenciesTextField.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            dependenciesTextField.heightAnchor.constraint(equalToConstant: 44),
            
            saveButton.topAnchor.constraint(equalTo: dependenciesTextField.bottomAnchor, constant: 32),
            saveButton.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            saveButton.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            saveButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func linkHealthTapped() {
        healthKitPickerVisible.toggle()
        healthKitLabel.isHidden = !healthKitPickerVisible
        healthKitPicker.isHidden = !healthKitPickerVisible
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
    
    @objc private func formulaSwitchChanged() {
        isFormula = formulaSwitch.isOn
        formulaTextField.isHidden = !isFormula
        dependenciesTextField.isHidden = !isFormula
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
        let isFormulaType = formulaSwitch.isOn
        let formulaStr = isFormulaType ? formulaTextField.text : nil
        let dependenciesStr = isFormulaType ? dependenciesTextField.text : nil
        let healthKitIdentifier = healthKitPickerVisible ? healthKitTypes[selectedHealthKitTypeIndex].identifier : nil
        completion(name, unit, selectedColor, isFormulaType, formulaStr, dependenciesStr, healthKitIdentifier)
        dismiss(animated: true)
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false;
    }
    
    // MARK: - UIPickerViewDataSource
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return healthKitTypes.count
    }
    
    // MARK: - UIPickerViewDelegate
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return healthKitTypes[row].name
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedHealthKitTypeIndex = row
    }
}

class EditCategoryViewController: UIViewController, UITextFieldDelegate, UIPickerViewDataSource, UIPickerViewDelegate {
    private let nameTextField = UITextField()
    private let unitTextField = UITextField()
    private let unitOptions = ["cm", "ft", "kg", "lb", "%", "in", "min", "#", "Picture", "Custom"]
    private var unitButtons: [UIButton] = []
    private var selectedUnit: String
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
    private let healthKitTypes: [(name: String, identifier: String?)] = [
        ("None", nil),
        ("Weight (kg)", "HKQuantityTypeIdentifierBodyMass"),
        ("Height (m)", "HKQuantityTypeIdentifierHeight"),
        ("Body Fat %", "HKQuantityTypeIdentifierBodyFatPercentage"),
        ("BMI", "HKQuantityTypeIdentifierBodyMassIndex"),
        ("Steps", "HKQuantityTypeIdentifierStepCount"),
        ("Heart Rate", "HKQuantityTypeIdentifierHeartRate"),
        ("Active Energy (kcal)", "HKQuantityTypeIdentifierActiveEnergyBurned"),
        ("Resting Energy (kcal)", "HKQuantityTypeIdentifierBasalEnergyBurned"),
        ("Waist Circumference (cm)", "HKQuantityTypeIdentifierWaistCircumference")
    ]
    private var selectedHealthKitTypeIndex: Int = 0
    private let healthKitPicker = UIPickerView()
    private let healthKitLabel = UILabel()
    private let linkHealthButton = UIButton(type: .system)
    private var healthKitPickerVisible = false
    private let completion: (MeasurementType) -> Void
    private let formulaSwitch = UISwitch()
    private let formulaLabel = UILabel()
    private let formulaTextField = UITextField()
    private let dependenciesTextField = UITextField()
    private var isFormula: Bool
    private var formula: String?
    private var dependencies: String?
    private let measurementType: MeasurementType

    init(measurementType: MeasurementType, completion: @escaping (MeasurementType) -> Void) {
        self.measurementType = measurementType
        self.completion = completion
        self.selectedUnit = measurementType.unit ?? "cm"
        self.selectedColor = UIColor(hex: measurementType.color ?? "#E84D52") ?? UIColor(red: 0.91, green: 0.30, blue: 0.32, alpha: 1.0)
        self.isFormula = measurementType.isFormula
        self.formula = measurementType.formula
        self.dependencies = measurementType.dependencies
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        nameTextField.delegate = self
        unitTextField.delegate = self
        formulaTextField.delegate = self
        dependenciesTextField.delegate = self
        healthKitPicker.dataSource = self
        healthKitPicker.delegate = self
        
        // Set initial values
        nameTextField.text = measurementType.name
        if measurementType.unit == "Custom" {
            unitTextField.text = measurementType.unit
            unitTextField.isHidden = false
        }
        formulaSwitch.isOn = measurementType.isFormula
        formulaTextField.text = measurementType.formula
        dependenciesTextField.text = measurementType.dependencies
        formulaTextField.isHidden = !measurementType.isFormula
        dependenciesTextField.isHidden = !measurementType.isFormula
        
        // Set HealthKit picker initial value
        if let hkId = measurementType.healthKitIdentifier {
            selectedHealthKitTypeIndex = healthKitTypes.firstIndex { $0.identifier == hkId } ?? 0
        }
        healthKitPicker.selectRow(selectedHealthKitTypeIndex, inComponent: 0, animated: false)
        
        // Add Done button to navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(saveButtonTapped))
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Edit Category"
        
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
        unitTextField.isHidden = selectedUnit != "Custom"
        
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
        
        // HealthKit link button
        linkHealthButton.setTitle("Link with Health Data", for: .normal)
        linkHealthButton.setTitleColor(.systemBlue, for: .normal)
        linkHealthButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        linkHealthButton.translatesAutoresizingMaskIntoConstraints = false
        linkHealthButton.addTarget(self, action: #selector(linkHealthTapped), for: .touchUpInside)
        
        // HealthKit picker and label (hidden by default)
        healthKitLabel.text = "Apple Health Data Type (optional)"
        healthKitLabel.font = .systemFont(ofSize: 16, weight: .medium)
        healthKitLabel.translatesAutoresizingMaskIntoConstraints = false
        healthKitLabel.isHidden = true
        healthKitPicker.translatesAutoresizingMaskIntoConstraints = false
        healthKitPicker.isHidden = true
        
        formulaLabel.text = "Formula"
        formulaLabel.font = .systemFont(ofSize: 18, weight: .medium)
        formulaLabel.translatesAutoresizingMaskIntoConstraints = false
        formulaSwitch.translatesAutoresizingMaskIntoConstraints = false
        formulaSwitch.addTarget(self, action: #selector(formulaSwitchChanged), for: .valueChanged)
        formulaTextField.placeholder = "Formula (e.g. DIAMETER*3.14*2)"
        formulaTextField.borderStyle = .roundedRect
        formulaTextField.translatesAutoresizingMaskIntoConstraints = false
        formulaTextField.isHidden = !isFormula
        dependenciesTextField.placeholder = "Dependencies (comma-separated, e.g. DIAMETER)"
        dependenciesTextField.borderStyle = .roundedRect
        dependenciesTextField.translatesAutoresizingMaskIntoConstraints = false
        dependenciesTextField.isHidden = !isFormula
        
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
        view.addSubview(linkHealthButton)
        view.addSubview(healthKitLabel)
        view.addSubview(healthKitPicker)
        view.addSubview(formulaLabel)
        view.addSubview(formulaSwitch)
        view.addSubview(formulaTextField)
        view.addSubview(dependenciesTextField)
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
            
            linkHealthButton.topAnchor.constraint(equalTo: colorGridStack.bottomAnchor, constant: 24),
            linkHealthButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            healthKitLabel.topAnchor.constraint(equalTo: linkHealthButton.bottomAnchor, constant: 12),
            healthKitLabel.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            healthKitPicker.topAnchor.constraint(equalTo: healthKitLabel.bottomAnchor, constant: 8),
            healthKitPicker.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            healthKitPicker.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            healthKitPicker.heightAnchor.constraint(equalToConstant: 100),
            
            formulaLabel.topAnchor.constraint(equalTo: healthKitPicker.bottomAnchor, constant: 24),
            formulaLabel.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            formulaSwitch.centerYAnchor.constraint(equalTo: formulaLabel.centerYAnchor),
            formulaSwitch.leadingAnchor.constraint(equalTo: formulaLabel.trailingAnchor, constant: 12),
            formulaTextField.topAnchor.constraint(equalTo: formulaLabel.bottomAnchor, constant: 12),
            formulaTextField.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            formulaTextField.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            formulaTextField.heightAnchor.constraint(equalToConstant: 44),
            dependenciesTextField.topAnchor.constraint(equalTo: formulaTextField.bottomAnchor, constant: 8),
            dependenciesTextField.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            dependenciesTextField.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            dependenciesTextField.heightAnchor.constraint(equalToConstant: 44),
            
            saveButton.topAnchor.constraint(equalTo: dependenciesTextField.bottomAnchor, constant: 32),
            saveButton.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            saveButton.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            saveButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func linkHealthTapped() {
        healthKitPickerVisible.toggle()
        healthKitLabel.isHidden = !healthKitPickerVisible
        healthKitPicker.isHidden = !healthKitPickerVisible
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
    
    @objc private func formulaSwitchChanged() {
        isFormula = formulaSwitch.isOn
        formulaTextField.isHidden = !isFormula
        dependenciesTextField.isHidden = !isFormula
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
        
        // Update the measurement type
        measurementType.name = name
        measurementType.unit = unit
        measurementType.color = selectedColor.toHex()
        measurementType.isFormula = isFormula
        measurementType.formula = isFormula ? formulaTextField.text : nil
        measurementType.dependencies = isFormula ? dependenciesTextField.text : nil
        measurementType.healthKitIdentifier = healthKitPickerVisible ? healthKitTypes[selectedHealthKitTypeIndex].identifier : nil
        
        completion(measurementType)
        dismiss(animated: true)
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false;
    }
    
    // MARK: - UIPickerViewDataSource
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return healthKitTypes.count
    }
    
    // MARK: - UIPickerViewDelegate
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return healthKitTypes[row].name
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedHealthKitTypeIndex = row
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
        // First fetch all types for formula calculations
        let allTypesRequest: NSFetchRequest<MeasurementType> = MeasurementType.fetchRequest()
        var allTypes: [MeasurementType] = []
        do {
            allTypes = try context.fetch(allTypesRequest)
        } catch {
            return
        }

        // For Categories view, show all types regardless of visibility
        measurementTypes = allTypes
        tableView.reloadData()
    }
    
    @objc private func addCategory() {
        let addCategoryVC = AddCategoryViewController { [weak self] name, unit, color, isFormula, formula, dependencies, healthKitIdentifier in
            let measurementType = MeasurementType(context: self!.context)
            measurementType.name = name
            measurementType.unit = unit
            measurementType.color = color.toHex()
            measurementType.isFormula = isFormula
            measurementType.formula = formula
            measurementType.dependencies = dependencies
            measurementType.healthKitIdentifier = healthKitIdentifier
            measurementType.isVisible = true  // Set initial visibility to true
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
        if measurementType.isFormula {
            content.text = "\(measurementType.name ?? "") (fx)"
     //       content.secondaryText = "Formula: \(measurementType.formula ?? "")\nUnit: \(measurementType.unit ?? "")"
    //        content.image = UIImage(systemName: "function")
        }
        cell.contentConfiguration = content
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let measurementType = measurementTypes[indexPath.row]
        
        // Edit action
        let editAction = UIContextualAction(style: .normal, title: nil) { [weak self] (_, _, completion) in
            guard let self = self else { return }
            let editVC = EditCategoryViewController(measurementType: measurementType) { [weak self] updatedType in
                guard let self = self else { return }
                try? self.context.save()
                self.tableView.reloadData()
            }
            let navController = UINavigationController(rootViewController: editVC)
            self.present(navController, animated: true)
            completion(true)
        }
        editAction.image = UIImage(systemName: "pencil")
        editAction.backgroundColor = .systemBlue
        
        // Visibility toggle action
        let visibilityAction = UIContextualAction(style: .normal, title: nil) { [weak self] (_, _, completion) in
            guard let self = self else { return }
            measurementType.isVisible = !measurementType.isVisible
            print("\n=== Toggling Visibility ===")
            print("Type: \(measurementType.name ?? "Unknown")")
            print("New visibility: \(measurementType.isVisible)")
            do {
                try self.context.save()
                self.tableView.reloadData()
            } catch {
                print("Error toggling visibility: \(error)")
            }
            completion(true)
        }
        visibilityAction.image = UIImage(systemName: measurementType.isVisible ? "eye.slash" : "eye")
        visibilityAction.backgroundColor = .systemGray
        
        return UISwipeActionsConfiguration(actions: [editAction, visibilityAction])
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] (_, _, completion) in
            guard let self = self else { return }
            let measurementType = self.measurementTypes[indexPath.row]
            
            // Delete all associated measurements first
            if let entries = measurementType.entries?.allObjects as? [MeasurementEntry] {
                for entry in entries {
                    self.context.delete(entry)
                }
            }
            
            // Then delete the measurement type
            self.context.delete(measurementType)
            
            do {
                try self.context.save()
                self.measurementTypes.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
            } catch {
                print("Error deleting measurement type: \(error)")
            }
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash")
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

class MeasurementsViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let tableView = UITableView()
    private var measurementTypes: [MeasurementType] = []
    private let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    private var expandedSections: Set<Int> = []
    private var imagePickerCompletion: ((UIImage) -> Void)?
    // HealthKit cache: section index -> [HKQuantitySample]
    private var healthKitSamplesBySection: [Int: [HKQuantitySample]] = [:]
    private var healthKitAuthRequested = false
    private let healthKitManager = HealthKitManager.shared
    private var formulaValuesBySection: [Int: [Date: [String: Double]]] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadMeasurementTypes()
        preloadHealthKitData()
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
        // First fetch all types for formula calculations
        let allTypesRequest: NSFetchRequest<MeasurementType> = MeasurementType.fetchRequest()
        var allTypes: [MeasurementType] = []
        do {
            allTypes = try context.fetch(allTypesRequest)
        } catch {
            return
        }

        // For Measurements view, only show visible types
        measurementTypes = allTypes.filter { $0.isVisible }
        tableView.reloadData()
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
                
                if let hkIdStr = type.healthKitIdentifier {
                    // Save to HealthKit only
                    let hkId = HKQuantityTypeIdentifier(rawValue: hkIdStr)
                    // Determine the correct HKUnit for the type
                    let unit: HKUnit
                    switch hkId {
                    case .bodyMass: unit = .gramUnit(with: .kilo)
                    case .height: unit = .meter()
                    case .bodyFatPercentage: unit = .percent()
                    case .bodyMassIndex: unit = .count()
                    case .stepCount: unit = .count()
                    case .heartRate: unit = HKUnit(from: "count/min")
                    case .activeEnergyBurned, .basalEnergyBurned: unit = .kilocalorie()
                    case .waistCircumference: unit = .meterUnit(with: .centi)
                    default: unit = .count()
                    }
                    HealthKitManager.shared.saveQuantitySample(identifier: hkId, value: value, unit: unit, date: date)
                    self.tableView.reloadData()
                    NotificationCenter.default.post(name: .measurementAdded, object: nil)
                } else {
                    // Save to Core Data only
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
            tableView.reloadSections(IndexSet(integer: section), with: .automatic)
        } else {
            expandedSections.insert(section)
            let type = measurementTypes[section]
            
            // If this is a formula type, fetch HealthKit data for all dependencies first
            if type.isFormula, let dependencies = type.dependencies?.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) {
                var remainingDependencies = dependencies.count
                let group = DispatchGroup()
                
                for depName in dependencies {
                    if let depType = measurementTypes.first(where: { $0.name == depName }),
                       let hkIdStr = depType.healthKitIdentifier,
                       let depSection = measurementTypes.firstIndex(where: { $0.name == depName }) {
                        let hkId = HKQuantityTypeIdentifier(rawValue: hkIdStr)
                        group.enter()
                        requestHealthKitAndFetch(for: hkId, section: depSection) { [weak self] in
                            remainingDependencies -= 1
                            if remainingDependencies == 0 {
                                self?.calculateFormulaValues(for: type, section: section, dependencies: dependencies)
                            }
                            group.leave()
                        }
                    } else {
                        remainingDependencies -= 1
                        if remainingDependencies == 0 {
                            calculateFormulaValues(for: type, section: section, dependencies: dependencies)
                        }
                    }
                }
            } else if let hkIdStr = type.healthKitIdentifier {
                let hkId = HKQuantityTypeIdentifier(rawValue: hkIdStr)
                requestHealthKitAndFetch(for: hkId, section: section)
            }
            
            tableView.reloadSections(IndexSet(integer: section), with: .automatic)
        }
    }
    
    private func calculateFormulaValues(for type: MeasurementType, section: Int, dependencies: [String]) {
        guard let formula = type.formula else { return }
        
        // Fetch all types again to get dependencies regardless of visibility
        let request: NSFetchRequest<MeasurementType> = MeasurementType.fetchRequest()
        var allTypes: [MeasurementType] = []
        do {
            allTypes = try context.fetch(request)
        } catch {
            return
        }
        
        // Gather all entries for dependencies
        var depEntries: [String: [MeasurementEntry]] = [:]
        var depHealthKitSamples: [String: [HKQuantitySample]] = [:]
        
        for depName in dependencies {
            if let depType = allTypes.first(where: { $0.name == depName }) {
                // Get Core Data entries
                if let entries = depType.entries?.allObjects as? [MeasurementEntry] {
                    depEntries[depName] = entries.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
                }
                
                // Get HealthKit samples if applicable
                if let hkIdStr = depType.healthKitIdentifier {
                    let hkId = HKQuantityTypeIdentifier(rawValue: hkIdStr)
                    let samples = healthKitSamplesBySection[section] ?? []
                    depHealthKitSamples[depName] = samples
                }
            }
        }
        
        // For each day where we have a measurement, find the most recent values for each dependency
        var dayToValues: [Date: [String: Double]] = [:]
        
        // Process Core Data entries
        for (depName, entries) in depEntries {
            for entry in entries {
                if let date = entry.timestamp {
                    let day = Calendar.current.startOfDay(for: date)
                    dayToValues[day, default: [:]][depName] = entry.value
                }
            }
        }
        
        // Process HealthKit samples
        for (depName, samples) in depHealthKitSamples {
            for sample in samples {
                let day = Calendar.current.startOfDay(for: sample.endDate)
                // Determine the correct HKUnit for the type
                let unit: HKUnit
                if let depType = measurementTypes.first(where: { $0.name == depName }),
                   let hkIdStr = depType.healthKitIdentifier {
                    let hkId = HKQuantityTypeIdentifier(rawValue: hkIdStr)
                    switch hkId {
                    case .bodyMass: unit = .gramUnit(with: .kilo)
                    case .height: unit = .meter()
                    case .bodyFatPercentage: unit = .percent()
                    case .bodyMassIndex: unit = .count()
                    case .stepCount: unit = .count()
                    case .heartRate: unit = HKUnit(from: "count/min")
                    case .activeEnergyBurned, .basalEnergyBurned: unit = .kilocalorie()
                    case .waistCircumference: unit = .meterUnit(with: .centi)
                    default: unit = .count()
                    }
                    let value = sample.quantity.doubleValue(for: unit)
                    dayToValues[day, default: [:]][depName] = value
                }
            }
        }
        
        // For each day, find the most recent value for each missing dependency
        let sortedDays = dayToValues.keys.sorted(by: >)
        var validDays: [Date: [String: Double]] = [:]
        
        for day in sortedDays {
            var values = dayToValues[day] ?? [:]
            var hasAllValues = true
            
            // For each missing dependency, find the most recent value
            for depName in dependencies {
                if values[depName] == nil {
                    // Find the most recent value for this dependency
                    var foundValue: Double?
                    var foundDate: Date?
                    
                    // Check Core Data entries
                    if let entries = depEntries[depName] {
                        for entry in entries {
                            if let date = entry.timestamp, date <= day {
                                foundValue = entry.value
                                foundDate = date
                                break
                            }
                        }
                    }
                    
                    // Check HealthKit samples
                    if foundValue == nil, let samples = depHealthKitSamples[depName] {
                        for sample in samples {
                            if sample.endDate <= day {
                                if let depType = measurementTypes.first(where: { $0.name == depName }),
                                   let hkIdStr = depType.healthKitIdentifier {
                                    let hkId = HKQuantityTypeIdentifier(rawValue: hkIdStr)
                                    let unit: HKUnit
                                    switch hkId {
                                    case .bodyMass: unit = .gramUnit(with: .kilo)
                                    case .height: unit = .meter()
                                    case .bodyFatPercentage: unit = .percent()
                                    case .bodyMassIndex: unit = .count()
                                    case .stepCount: unit = .count()
                                    case .heartRate: unit = HKUnit(from: "count/min")
                                    case .activeEnergyBurned, .basalEnergyBurned: unit = .kilocalorie()
                                    case .waistCircumference: unit = .meterUnit(with: .centi)
                                    default: unit = .count()
                                    }
                                    foundValue = sample.quantity.doubleValue(for: unit)
                                    foundDate = sample.endDate
                                    break
                                }
                            }
                        }
                    }
                    
                    if let value = foundValue {
                        values[depName] = value
                    } else {
                        hasAllValues = false
                        break
                    }
                }
            }
            
            if hasAllValues {
                validDays[day] = values
            }
        }
        
        formulaValuesBySection[section] = validDays
        
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadSections(IndexSet(integer: section), with: .automatic)
        }
    }
    
    private func requestHealthKitAndFetch(for identifier: HKQuantityTypeIdentifier, section: Int, completion: (() -> Void)? = nil) {
        let typesToRead: Set<HKObjectType> = [HKObjectType.quantityType(forIdentifier: identifier)!]
        if !healthKitAuthRequested {
            let typesToShare: Set<HKSampleType> = [HKObjectType.quantityType(forIdentifier: identifier)!]
            HealthKitManager.shared.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
                DispatchQueue.main.async {
                    self?.healthKitAuthRequested = true
                    if success {
                        self?.fetchHealthKitSamples(for: identifier, section: section, completion: completion)
                    } else {
                        completion?()
                    }
                }
            }
        } else {
            fetchHealthKitSamples(for: identifier, section: section, completion: completion)
        }
    }
    
    private func fetchHealthKitSamples(for identifier: HKQuantityTypeIdentifier, section: Int, completion: (() -> Void)? = nil) {
        HealthKitManager.shared.fetchAllQuantitySamples(for: identifier) { [weak self] samples in
            DispatchQueue.main.async {
                self?.healthKitSamplesBySection[section] = samples
                completion?()
            }
        }
    }
    
    private func evaluateFormula(_ formula: String, values: [String: Double]) -> Double {
        // Replace variable names with their values
        var evaluatedFormula = formula
        for (name, value) in values {
            evaluatedFormula = evaluatedFormula.replacingOccurrences(of: name, with: "\(value)")
        }
        
        do {
            let expression = try MathParser.Expression(string: evaluatedFormula)
            let evaluator = MathParser.Evaluator()
            let result = try evaluator.evaluate(expression)
            return result
        } catch {
            return 0.0
        }
    }
    
    private func evaluateFormula(_ formula: String, with values: [String: Double]) throws -> Double {
        return evaluateFormula(formula, values: values)
    }
    
    private func identifyAndCleanDuplicates() {
        let request: NSFetchRequest<MeasurementEntry> = MeasurementEntry.fetchRequest()
        do {
            let entries = try context.fetch(request)
            
            // Group entries by type and date
            var entriesByTypeAndDate: [String: [String: [MeasurementEntry]]] = [:]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            for entry in entries {
                guard let type = entry.type,
                      let typeName = type.name,
                      let timestamp = entry.timestamp else { continue }
                
                let dateString = dateFormatter.string(from: timestamp)
                if entriesByTypeAndDate[typeName] == nil {
                    entriesByTypeAndDate[typeName] = [:]
                }
                if entriesByTypeAndDate[typeName]![dateString] == nil {
                    entriesByTypeAndDate[typeName]![dateString] = []
                }
                entriesByTypeAndDate[typeName]![dateString]!.append(entry)
            }
            
            // Identify duplicates
            var duplicatesFound = false
            for (typeName, dates) in entriesByTypeAndDate {
                for (date, entries) in dates {
                    if entries.count > 1 {
                        duplicatesFound = true
                        print("\nFound \(entries.count) entries for \(typeName) on \(date):")
                        for entry in entries {
                            print("- Value: \(entry.value), Timestamp: \(entry.timestamp?.description ?? "nil")")
                        }
                    }
                }
            }
            
            if !duplicatesFound {
                print("No duplicate entries found.")
            }
            
        } catch {
            print("Error fetching entries: \(error)")
        }
    }
    
    private func cleanupDuplicates() {
        let request: NSFetchRequest<MeasurementEntry> = MeasurementEntry.fetchRequest()
        do {
            let entries = try context.fetch(request)
            
            // Group entries by type and date
            var entriesByTypeAndDate: [String: [String: [MeasurementEntry]]] = [:]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            for entry in entries {
                guard let type = entry.type,
                      let typeName = type.name,
                      let timestamp = entry.timestamp else { continue }
                
                let dateString = dateFormatter.string(from: timestamp)
                if entriesByTypeAndDate[typeName] == nil {
                    entriesByTypeAndDate[typeName] = [:]
                }
                if entriesByTypeAndDate[typeName]![dateString] == nil {
                    entriesByTypeAndDate[typeName]![dateString] = []
                }
                entriesByTypeAndDate[typeName]![dateString]!.append(entry)
            }
            
            // Clean up duplicates by keeping only the most recent entry for each type and date
            var entriesDeleted = 0
            for (_, dates) in entriesByTypeAndDate {
                for (_, entries) in dates {
                    if entries.count > 1 {
                        // Sort by timestamp, most recent first
                        let sortedEntries = entries.sorted { ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast) }
                        // Keep the most recent entry, delete others
                        for entry in sortedEntries.dropFirst() {
                            context.delete(entry)
                            entriesDeleted += 1
                        }
                    }
                }
            }
            
            if entriesDeleted > 0 {
                try context.save()
                print("Successfully deleted \(entriesDeleted) duplicate entries.")
                tableView.reloadData()
            } else {
                print("No duplicate entries found to clean up.")
            }
            
        } catch {
            print("Error cleaning up duplicates: \(error)")
        }
    }
    
    private func reloadData() {
        // Reload measurement types
        let fetchRequest: NSFetchRequest<MeasurementType> = MeasurementType.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            measurementTypes = try context.fetch(fetchRequest)
            expandedSections = Set(0..<measurementTypes.count)
            
            // Clear existing formula values
            formulaValuesBySection.removeAll()
            
            // Pre-calculate formula values for all formula types
            for (index, type) in measurementTypes.enumerated() {
                if type.isFormula {
                    guard let formula = type.formula,
                          let dependencies = type.dependencies else { continue }
                    
                    // Get all entries for dependencies
                    var dependencyEntries: [String: [MeasurementEntry]] = [:]
                    for dependency in dependencies {
                        if let depType = measurementTypes.first(where: { $0.name == String(dependency) }) {
                            let entries = depType.entries?.allObjects as? [MeasurementEntry] ?? []
                            dependencyEntries[String(dependency)] = entries
                        }
                    }
                    
                    // Group entries by day
                    var entriesByDay: [Date: [String: Double]] = [:]
                    for (depName, entries) in dependencyEntries {
                        for entry in entries {
                            guard let timestamp = entry.timestamp else { continue }
                            let day = Calendar.current.startOfDay(for: timestamp)
                            if entriesByDay[day] == nil {
                                entriesByDay[day] = [:]
                            }
                            entriesByDay[day]?[depName] = entry.value
                        }
                    }
                    
                    // Calculate formula values for each day
                    var formulaValues: [Date: Double] = [:]
                    for (day, values) in entriesByDay {
                        // Check if we have all dependencies for this day
                        let hasAllDependencies = dependencies.allSatisfy { values[String($0)] != nil }
                        if hasAllDependencies {
                            do {
                                let result = try evaluateFormula(formula, with: values)
                                formulaValues[day] = result
                            } catch {
                                print("Error evaluating formula for day \(day): \(error)")
                            }
                        }
                    }
                    
                    // Store the formula values
                    formulaValuesBySection[index] = [:]
                    for (date, value) in formulaValues {
                        formulaValuesBySection[index]?[date] = ["formula": value]
                    }
                }
            }
            
            tableView.reloadData()
        } catch {
            print("Error fetching measurement types: \(error)")
        }
    }

    private func preloadHealthKitData() {
        for (index, type) in measurementTypes.enumerated() {
            if let hkIdStr = type.healthKitIdentifier {
                let hkId = HKQuantityTypeIdentifier(rawValue: hkIdStr)
                HealthKitManager.shared.fetchAllQuantitySamples(for: hkId) { [weak self] samples in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        self.healthKitSamplesBySection[index] = samples
                        if self.expandedSections.contains(index) {
                            self.tableView.reloadSections(IndexSet(integer: index), with: .automatic)
                        }
                    }
                }
            }
        }
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
        addButton.isHidden = measurementTypes[section].isFormula // Hide + for formula
        
        let chevronButton = UIButton(type: .system)
        chevronButton.setImage(UIImage(systemName: expandedSections.contains(section) ? "chevron.down" : "chevron.right"), for: .normal)
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
        let type = measurementTypes[section]
        if type.isFormula {
            // Count unique days where all dependencies are present
            let dependencyNames = (type.dependencies ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard !dependencyNames.isEmpty, let _ = type.formula else { return 0 }
            // Get the valid days from formulaValuesBySection
            let validDays = formulaValuesBySection[section] ?? [:]
            return expandedSections.contains(section) ? validDays.count : 0
        } else if let _ = type.healthKitIdentifier {
            // For HealthKit linked types, only show HealthKit samples
            let samples = healthKitSamplesBySection[section] ?? []
            return expandedSections.contains(section) ? samples.count : 0
        } else {
            // For non-HealthKit types, show Core Data entries
            return expandedSections.contains(section) ? (type.entries?.count ?? 0) : 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let type = measurementTypes[indexPath.section]
        var content = cell.defaultContentConfiguration()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        if type.isFormula {
            let dependencyNames = (type.dependencies ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let dayToValues = formulaValuesBySection[indexPath.section] ?? [:]
            let validDays = dayToValues.filter { $0.value.keys.count == dependencyNames.count }
            let sortedDays = validDays.keys.sorted(by: >)
            
            // Check if we have enough days and the index is valid
            guard indexPath.row < sortedDays.count else {
                content.text = "No data available"
                cell.contentConfiguration = content
                return cell
            }
            
            let day = sortedDays[indexPath.row]
            let values = dayToValues[day] ?? [:]
            
            let formula = type.formula ?? ""
            let result = evaluateFormula(formula, values: values)
            content.text = "\(result.formatted) \(type.unit ?? "")"
            content.secondaryText = formatter.string(from: day)
            if let colorHex = type.color {
                content.textProperties.color = UIColor(hex: colorHex)
            }
        } else if let hkIdStr = type.healthKitIdentifier {
            // For HealthKit linked types, only show HealthKit samples
            let hkId = HKQuantityTypeIdentifier(rawValue: hkIdStr)
            let hkSamples = (healthKitSamplesBySection[indexPath.section] ?? []).sorted { $0.endDate > $1.endDate }
            
            // Check if we have enough samples and the index is valid
            guard indexPath.row < hkSamples.count else {
                content.text = "No data available"
                cell.contentConfiguration = content
                return cell
            }
            
            let sample = hkSamples[indexPath.row]
            
            // Determine the correct HKUnit for the type
            let unit: HKUnit
            switch hkId {
            case .bodyMass: unit = .gramUnit(with: .kilo)
            case .height: unit = .meter()
            case .bodyFatPercentage: unit = .percent()
            case .bodyMassIndex: unit = .count()
            case .stepCount: unit = .count()
            case .heartRate: unit = HKUnit(from: "count/min")
            case .activeEnergyBurned, .basalEnergyBurned: unit = .kilocalorie()
            case .waistCircumference: unit = .meterUnit(with: .centi)
            default: unit = .count()
            }
            
            let value = sample.quantity.doubleValue(for: unit)
            content.text = "\(value.formatted) \(type.unit ?? "")"
            content.secondaryText = formatter.string(from: sample.endDate)
            if let colorHex = type.color {
                content.textProperties.color = UIColor(hex: colorHex)
            }
        } else {
            // For non-HealthKit types, show Core Data entries
            if let entries = type.entries?.allObjects as? [MeasurementEntry] {
                let sortedEntries = entries.sorted { ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast) }
                
                // Check if we have enough entries and the index is valid
                guard indexPath.row < sortedEntries.count else {
                    content.text = "No data available"
                    cell.contentConfiguration = content
                    return cell
                }
                
                let entry = sortedEntries[indexPath.row]
                
                if type.unit == "Picture" {
                    if let imageData = entry.image, let image = UIImage(data: imageData) {
                        content.image = image
                        content.imageProperties.maximumSize = CGSize(width: 40, height: 40)
                        content.imageProperties.cornerRadius = 4
                    }
                    content.text = formatter.string(from: entry.timestamp ?? Date())
                } else {
                    content.text = "\(entry.value.formatted) \(type.unit ?? "")"
                    content.secondaryText = formatter.string(from: entry.timestamp ?? Date())
                }
                
                if let colorHex = type.color {
                    content.textProperties.color = UIColor(hex: colorHex)
                }
            }
        }
        
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let type = measurementTypes[indexPath.section]
        
        if type.isFormula {
            return
        }
        
        if editingStyle == .delete {
            // For HealthKit-linked types, use HealthKit samples directly
            if let healthKitIdentifier = type.healthKitIdentifier {
                let samples = healthKitSamplesBySection[indexPath.section] ?? []
                let sortedSamples = samples.sorted { $0.endDate > $1.endDate }
                
                guard indexPath.row < sortedSamples.count else {
                    return
                }
                
                let sample = sortedSamples[indexPath.row]
                
                let hkId = HKQuantityTypeIdentifier(rawValue: healthKitIdentifier)
                healthKitManager.deleteQuantitySample(identifier: hkId, date: sample.endDate) { [weak self] (success: Bool, error: Error?) in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        
                        if success {
                            self.tableView.reloadData()
                        }
                    }
                }
            } else {
                // For non-HealthKit types, use Core Data entries
                if let entries = type.entries?.allObjects as? [MeasurementEntry] {
                    let sortedEntries = entries.sorted { ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast) }
                    let entry = sortedEntries[indexPath.row]
                    
                    context.delete(entry)
                    do {
                        try context.save()
                        loadMeasurementTypes()
                        tableView.reloadData()
                    } catch {
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let type = measurementTypes[indexPath.section]
        return !type.isFormula
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let type = measurementTypes[indexPath.section]
        if type.isFormula {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        if type.unit == "Picture",
           let entries = type.entries?.allObjects as? [MeasurementEntry] {
            let sortedEntries = entries.sorted { ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast) }
            let entry = sortedEntries[indexPath.row]
            if let imageData = entry.image,
               let image = UIImage(data: imageData) {
                print("\n=== Creating ImagePreviewViewController ===")
                print("MeasurementEntry: \(entry.description)")
                print("Note: \(entry.note ?? "nil")")
                let previewVC = ImagePreviewViewController(image: image, measurementEntry: entry)
                present(previewVC, animated: true)
            }
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
    private let imageView = UIImageView()
    private let scrollView = UIScrollView()
    private let noteButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    private let noteLabel = UILabel()
    private let noteContainer = UIView()
    private var measurementEntry: MeasurementEntry?
    
    init(image: UIImage, measurementEntry: MeasurementEntry? = nil) {
        super.init(nibName: nil, bundle: nil)
        self.imageView.image = image
        self.measurementEntry = measurementEntry
        print("\n=== ImagePreviewViewController Init ===")
        print("MeasurementEntry: \(measurementEntry?.description ?? "nil")")
        print("Note: \(measurementEntry?.note ?? "nil")")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Setup scroll view
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Setup image view
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        // Setup note button
        noteButton.setImage(UIImage(systemName: "note.text"), for: .normal)
        noteButton.tintColor = .white
        noteButton.addTarget(self, action: #selector(noteButtonTapped), for: .touchUpInside)
        view.addSubview(noteButton)
        noteButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            noteButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            noteButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        
        // Setup share button
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        shareButton.tintColor = .white
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        view.addSubview(shareButton)
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            shareButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            shareButton.trailingAnchor.constraint(equalTo: noteButton.leadingAnchor, constant: -16)
        ])
        
        // Setup note container
        noteContainer.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view.addSubview(noteContainer)
        noteContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            noteContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            noteContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            noteContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            noteContainer.heightAnchor.constraint(equalToConstant: 100)
        ])
        
        // Setup note label
        noteLabel.textColor = .white
        noteLabel.numberOfLines = 0
        noteLabel.textAlignment = .center
        noteLabel.font = .systemFont(ofSize: 16)
        noteContainer.addSubview(noteLabel)
        noteLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            noteLabel.topAnchor.constraint(equalTo: noteContainer.topAnchor, constant: 8),
            noteLabel.leadingAnchor.constraint(equalTo: noteContainer.leadingAnchor, constant: 16),
            noteLabel.trailingAnchor.constraint(equalTo: noteContainer.trailingAnchor, constant: -16),
            noteLabel.bottomAnchor.constraint(equalTo: noteContainer.bottomAnchor, constant: -8)
        ])
        
        // Update note display if there's an existing note
        print("\n=== Setting up Note Display ===")
        print("MeasurementEntry: \(measurementEntry?.description ?? "nil")")
        print("Note: \(measurementEntry?.note ?? "nil")")
        if let note = measurementEntry?.note, !note.isEmpty {
            print("Displaying note: \(note)")
            noteLabel.text = note
            noteContainer.isHidden = false
        } else {
            print("No note to display")
            noteContainer.isHidden = true
        }
    }
    
    @objc private func noteButtonTapped() {
        print("\n=== Note Button Tapped ===")
        print("Current note: \(measurementEntry?.note ?? "nil")")
        
        let alert = UIAlertController(title: "Add Note", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Enter your note here"
            textField.text = self.measurementEntry?.note
            print("Text field initialized with: \(textField.text ?? "nil")")
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            print("Note editing cancelled")
        })
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self,
                  let entry = self.measurementEntry else {
                print("Error: No measurement entry available")
                return
            }
            
            let note = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            print("Saving note: \(note ?? "nil")")
            
            entry.note = note
            
            do {
                print("Attempting to save to Core Data...")
                try entry.managedObjectContext?.save()
                print("Successfully saved note to Core Data")
                self.noteLabel.text = note
                self.noteContainer.isHidden = note?.isEmpty ?? true
                print("Note container visibility: \(!self.noteContainer.isHidden)")
            } catch {
                print("Error saving note: \(error)")
            }
        })
        
        present(alert, animated: true)
    }
    
    @objc private func shareButtonTapped() {
        guard let image = imageView.image else { return }
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
            popover.permittedArrowDirections = .any
        }
        present(activityVC, animated: true)
    }
}

extension ImagePreviewViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}

// Add ImageEditorViewController
class ImageEditorViewController: UIViewController, UIScrollViewDelegate {
    private let imageView = UIImageView()
    private let scrollView = UIScrollView()
    private let cancelButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)
    private let filtersButton = UIButton(type: .system)
    private let cropButton = UIButton(type: .system)
    
    weak var delegate: ImageEditorViewControllerDelegate?
    private var originalImage: UIImage
    
    init(image: UIImage) {
        self.originalImage = image
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
        view.backgroundColor = .black
        
        // Setup scroll view
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Setup image view
        imageView.image = originalImage
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        // Setup cancel button
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.tintColor = .white
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        view.addSubview(cancelButton)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
        ])
        
        // Setup done button
        doneButton.setTitle("Done", for: .normal)
        doneButton.tintColor = .white
        doneButton.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        view.addSubview(doneButton)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            doneButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        
        // Setup filters button
        filtersButton.setImage(UIImage(systemName: "camera.filters"), for: .normal)
        filtersButton.tintColor = .white
        filtersButton.addTarget(self, action: #selector(filtersButtonTapped), for: .touchUpInside)
        view.addSubview(filtersButton)
        filtersButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            filtersButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            filtersButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
        ])
        
        // Setup crop button
        cropButton.setImage(UIImage(systemName: "crop"), for: .normal)
        cropButton.tintColor = .white
        cropButton.addTarget(self, action: #selector(cropButtonTapped), for: .touchUpInside)
        view.addSubview(cropButton)
        cropButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cropButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            cropButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    @objc private func cancelButtonTapped() {
        delegate?.imageEditorDidCancel(self)
    }
    
    @objc private func doneButtonTapped() {
        delegate?.imageEditor(self, didFinishEditing: imageView.image ?? originalImage)
    }
    
    @objc private func filtersButtonTapped() {
        // TODO: Implement filters
    }
    
    @objc private func cropButtonTapped() {
        // TODO: Implement cropping
    }
    
    // Add UIScrollViewDelegate conformance
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}

protocol ImageEditorViewControllerDelegate: AnyObject {
    func imageEditor(_ editor: ImageEditorViewController, didFinishEditing image: UIImage)
    func imageEditorDidCancel(_ editor: ImageEditorViewController)
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

// Add this extension at the end of the file, before the last closing brace
extension Double {
    var formatted: String {
        return String(format: "%.2f", self)
    }
}


