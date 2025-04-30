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