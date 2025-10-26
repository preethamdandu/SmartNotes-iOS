import UIKit
import Combine

// MARK: - Note Models

struct Note: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String
    var tags: [String]
    var color: NoteColor
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(title: String, content: String, tags: [String] = [], color: NoteColor = .default, isPinned: Bool = false) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.tags = tags
        self.color = color
        self.isPinned = isPinned
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum NoteColor: String, CaseIterable, Codable {
    case `default` = "default"
    case red = "red"
    case blue = "blue"
    case green = "green"
    case yellow = "yellow"
    case purple = "purple"
    case orange = "orange"
    
    var uiColor: UIColor {
        switch self {
        case .default: return .systemBackground
        case .red: return .systemRed
        case .blue: return .systemBlue
        case .green: return .systemGreen
        case .yellow: return .systemYellow
        case .purple: return .systemPurple
        case .orange: return .systemOrange
        }
    }
}

// MARK: - View Models

@MainActor
class NotesViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var filteredNotes: [Note] = []
    @Published var searchText: String = ""
    @Published var selectedTags: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isAuthenticated: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
        loadSampleNotes()
    }
    
    private func setupBindings() {
        Publishers.CombineLatest($notes, $searchText)
            .map { notes, searchText in
                // Sort notes: pinned first, then by updated date (newest first)
                let sortedNotes = notes.sorted { first, second in
                    if first.isPinned != second.isPinned {
                        return first.isPinned && !second.isPinned
                    }
                    return first.updatedAt > second.updatedAt
                }
                
                if searchText.isEmpty {
                    return sortedNotes
                } else {
                    return sortedNotes.filter { note in
                        note.title.localizedCaseInsensitiveContains(searchText) ||
                        note.content.localizedCaseInsensitiveContains(searchText) ||
                        note.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
                    }
                }
            }
            .assign(to: &$filteredNotes)
    }
    
    private func loadSampleNotes() {
        notes = [
            Note(title: "Welcome to Smart Notes", content: "This is your first note. Start organizing your thoughts!", tags: ["welcome", "getting-started"], color: .blue, isPinned: true),
            Note(title: "Meeting Notes", content: "Discuss project timeline and deliverables for Q1.", tags: ["work", "meeting"], color: .green),
            Note(title: "Shopping List", content: "Milk, eggs, bread, apples", tags: ["personal", "shopping"], color: .yellow),
            Note(title: "Ideas", content: "New app feature ideas and improvements", tags: ["ideas", "development"], color: .purple),
            Note(title: "Class tomorrow", content: "Remember to bring laptop and charger for iOS development class", tags: ["education", "reminder"], color: .orange),
            Note(title: "Project Deadline", content: "Submit final project by Friday. Need to complete testing and documentation.", tags: ["work", "deadline"], color: .red),
            Note(title: "Grocery Store", content: "Buy ingredients for dinner: pasta, tomatoes, cheese, herbs", tags: ["personal", "cooking"], color: .green),
            Note(title: "Book Recommendations", content: "Clean Code by Robert Martin, Design Patterns by Gang of Four", tags: ["reading", "programming"], color: .blue),
            Note(title: "Weekend Plans", content: "Visit the museum, have dinner with friends, relax at home", tags: ["personal", "weekend"], color: .purple),
            Note(title: "Learning Goals", content: "Master SwiftUI, learn about Core Data, practice algorithms", tags: ["learning", "goals"], color: .yellow)
        ]
    }
    
    func loadNotes() async throws {
        // Simulate loading
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    func saveNote(_ note: Note) async throws {
        // Add new note at the beginning of the array
        notes.insert(note, at: 0)
    }
    
    func updateNote(_ note: Note) async throws {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        }
    }
    
    func deleteNote(_ note: Note) async throws {
        notes.removeAll { $0.id == note.id }
    }
    
    func syncNotes() async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate sync
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
}

// MARK: - UI Components

class NoteCell: UICollectionViewCell {
    static let identifier = "NoteCell"
    
    private let titleLabel = UILabel()
    private let contentLabel = UILabel()
    private let dateLabel = UILabel()
    private let pinImageView = UIImageView()
    private let colorView = UIView()
    private let tagsStackView = UIStackView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.1
        
        // Color indicator
        colorView.layer.cornerRadius = 4
        colorView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(colorView)
        
        // Title label
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2 // Allow up to 2 lines for titles
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Content label
        contentLabel.font = .preferredFont(forTextStyle: .body)
        contentLabel.textColor = .secondaryLabel
        contentLabel.numberOfLines = 0 // Allow unlimited lines
        contentLabel.lineBreakMode = .byWordWrapping
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Date label
        dateLabel.font = .preferredFont(forTextStyle: .caption1)
        dateLabel.textColor = .tertiaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Pin image
        pinImageView.image = UIImage(systemName: "pin.fill")
        pinImageView.tintColor = .systemOrange
        pinImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Tags stack view
        tagsStackView.axis = .horizontal
        tagsStackView.spacing = 4
        tagsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews
        contentView.addSubview(titleLabel)
        contentView.addSubview(contentLabel)
        contentView.addSubview(dateLabel)
        contentView.addSubview(pinImageView)
        contentView.addSubview(tagsStackView)
        
        // Constraints
        NSLayoutConstraint.activate([
            colorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            colorView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            colorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            colorView.widthAnchor.constraint(equalToConstant: 4),
            
            titleLabel.leadingAnchor.constraint(equalTo: colorView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: pinImageView.leadingAnchor, constant: -8),
            
            pinImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            pinImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            pinImageView.widthAnchor.constraint(equalToConstant: 16),
            pinImageView.heightAnchor.constraint(equalToConstant: 16),
            
            contentLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            contentLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            
            tagsStackView.leadingAnchor.constraint(equalTo: contentLabel.leadingAnchor),
            tagsStackView.topAnchor.constraint(equalTo: contentLabel.bottomAnchor, constant: 8),
            tagsStackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -12),
            
            dateLabel.leadingAnchor.constraint(equalTo: tagsStackView.leadingAnchor),
            dateLabel.topAnchor.constraint(equalTo: tagsStackView.bottomAnchor, constant: 4),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with note: Note) {
        titleLabel.text = note.title
        contentLabel.text = note.content
        dateLabel.text = formatDate(note.updatedAt)
        colorView.backgroundColor = note.color.uiColor
        pinImageView.isHidden = !note.isPinned
        
        // Clear existing tags
        tagsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add tags
        for tag in note.tags.prefix(3) {
            let tagLabel = createTagLabel(text: tag)
            tagsStackView.addArrangedSubview(tagLabel)
        }
        
        // Ensure proper layout
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let targetSize = CGSize(width: layoutAttributes.frame.width, height: 0)
        let size = contentView.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        layoutAttributes.frame.size.height = ceil(size.height)
        return layoutAttributes
    }
    
    private func createTagLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .caption2)
        label.textColor = .systemBlue
        label.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.textAlignment = .center
        label.padding = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        return label
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

class NoteHeaderView: UICollectionReusableView {
    static let identifier = "NoteHeaderView"
    
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        countLabel.font = .preferredFont(forTextStyle: .subheadline)
        countLabel.textColor = .secondaryLabel
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(titleLabel)
        addSubview(countLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    func configure(title: String, count: Int) {
        titleLabel.text = title
        countLabel.text = "\(count) notes"
    }
}

// MARK: - Additional View Controllers

class AddNoteViewController: UIViewController {
    weak var delegate: AddNoteDelegate?
    
    private let titleTextField = UITextField()
    private let contentTextView = UITextView()
    private let saveButton = UIBarButtonItem()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        title = "New Note"
        view.backgroundColor = .systemBackground
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped))
        
        // Title field
        titleTextField.placeholder = "Note title"
        titleTextField.borderStyle = .roundedRect
        titleTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Content text view
        contentTextView.font = .preferredFont(forTextStyle: .body)
        contentTextView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(titleTextField)
        view.addSubview(contentTextView)
        
        NSLayoutConstraint.activate([
            titleTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            contentTextView.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 16),
            contentTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            contentTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            contentTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveTapped() {
        let title = titleTextField.text ?? ""
        let content = contentTextView.text ?? ""
        
        if !title.isEmpty && !content.isEmpty {
            let note = Note(title: title, content: content)
            delegate?.didAddNote(note)
            dismiss(animated: true)
        }
    }
}

class NoteDetailViewController: UIViewController {
    weak var delegate: NoteDetailDelegate?
    private var note: Note
    
    private let titleTextField = UITextField()
    private let contentTextView = UITextView()
    private let saveButton = UIBarButtonItem()
    
    init(note: Note) {
        self.note = note
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
        title = "Note Details"
        view.backgroundColor = .systemBackground
        
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped)),
            UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deleteTapped))
        ]
        
        // Title field
        titleTextField.text = note.title
        titleTextField.borderStyle = .roundedRect
        titleTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Content text view
        contentTextView.text = note.content
        contentTextView.font = .preferredFont(forTextStyle: .body)
        contentTextView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(titleTextField)
        view.addSubview(contentTextView)
        
        NSLayoutConstraint.activate([
            titleTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            contentTextView.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 16),
            contentTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            contentTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            contentTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
    
    @objc private func saveTapped() {
        note.title = titleTextField.text ?? ""
        note.content = contentTextView.text ?? ""
        note.updatedAt = Date()
        delegate?.didUpdateNote(note)
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func deleteTapped() {
        let alert = UIAlertController(title: "Delete Note", message: "Are you sure you want to delete this note?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.delegate?.didDeleteNote(self.note)
            self.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
}

// MARK: - Protocols

protocol AddNoteDelegate: AnyObject {
    func didAddNote(_ note: Note)
}

protocol NoteDetailDelegate: AnyObject {
    func didUpdateNote(_ note: Note)
    func didDeleteNote(_ note: Note)
}

// MARK: - Extensions

extension UILabel {
    var padding: UIEdgeInsets {
        get { return UIEdgeInsets.zero }
        set {
            let insets = newValue
            let rect = bounds.inset(by: insets)
            frame = rect
        }
    }
}