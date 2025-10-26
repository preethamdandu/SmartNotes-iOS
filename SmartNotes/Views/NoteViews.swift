import UIKit

// MARK: - Note Cell

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
        
        // Pin indicator
        pinImageView.image = UIImage(systemName: "pin.fill")
        pinImageView.tintColor = .systemRed
        pinImageView.contentMode = .scaleAspectFit
        pinImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pinImageView)
        
        // Title label
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Content label
        contentLabel.font = UIFont.preferredFont(forTextStyle: .body)
        contentLabel.textColor = .secondaryLabel
        contentLabel.numberOfLines = 3
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(contentLabel)
        
        // Date label
        dateLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        dateLabel.textColor = .tertiaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dateLabel)
        
        // Tags stack view
        tagsStackView.axis = .horizontal
        tagsStackView.spacing = 4
        tagsStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tagsStackView)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Color view
            colorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            colorView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            colorView.widthAnchor.constraint(equalToConstant: 8),
            colorView.heightAnchor.constraint(equalToConstant: 8),
            
            // Pin image view
            pinImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            pinImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            pinImageView.widthAnchor.constraint(equalToConstant: 16),
            pinImageView.heightAnchor.constraint(equalToConstant: 16),
            
            // Title label
            titleLabel.leadingAnchor.constraint(equalTo: colorView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: pinImageView.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            
            // Content label
            contentLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            contentLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            
            // Tags stack view
            tagsStackView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            tagsStackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -12),
            tagsStackView.topAnchor.constraint(equalTo: contentLabel.bottomAnchor, constant: 8),
            
            // Date label
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            dateLabel.topAnchor.constraint(equalTo: tagsStackView.bottomAnchor, constant: 8),
            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with note: Note) {
        titleLabel.text = note.title
        contentLabel.text = note.content
        dateLabel.text = formatDate(note.updatedAt)
        colorView.backgroundColor = note.color.uiColor
        pinImageView.isHidden = !note.isPinned
        
        // Configure tags
        tagsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for tag in note.tags.prefix(3) { // Show max 3 tags
            let tagLabel = createTagLabel(text: tag)
            tagsStackView.addArrangedSubview(tagLabel)
        }
    }
    
    private func createTagLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.preferredFont(forTextStyle: .caption2)
        label.textColor = .systemBlue
        label.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.textAlignment = .center
        label.padding = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        return label
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Note Header View

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
        backgroundColor = .clear
        
        titleLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        titleLabel.font = UIFont.boldSystemFont(ofSize: titleLabel.font.pointSize)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        
        countLabel.font = UIFont.preferredFont(forTextStyle: .body)
        countLabel.textColor = .secondaryLabel
        countLabel.translatesAutoresizingMaskIntoConstraints = false
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

// MARK: - Add Note View Controller

class AddNoteViewController: UIViewController {
    weak var delegate: AddNoteDelegate?
    
    private let titleTextField = UITextField()
    private let contentTextView = UITextView()
    private let tagsTextField = UITextField()
    private let colorSegmentedControl = UISegmentedControl(items: NoteColor.allCases.map { $0.rawValue.capitalized })
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        title = "New Note"
        view.backgroundColor = .systemGroupedBackground
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveTapped)
        )
        
        // Title text field
        titleTextField.placeholder = "Note title"
        titleTextField.borderStyle = .roundedRect
        titleTextField.font = UIFont.preferredFont(forTextStyle: .title2)
        titleTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleTextField)
        
        // Content text view
        contentTextView.font = UIFont.preferredFont(forTextStyle: .body)
        contentTextView.layer.borderColor = UIColor.systemGray4.cgColor
        contentTextView.layer.borderWidth = 1
        contentTextView.layer.cornerRadius = 8
        contentTextView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentTextView)
        
        // Tags text field
        tagsTextField.placeholder = "Tags (comma separated)"
        tagsTextField.borderStyle = .roundedRect
        tagsTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tagsTextField)
        
        // Color segmented control
        colorSegmentedControl.selectedSegmentIndex = 0
        colorSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(colorSegmentedControl)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            titleTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            contentTextView.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 16),
            contentTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            contentTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            contentTextView.heightAnchor.constraint(equalToConstant: 200),
            
            tagsTextField.topAnchor.constraint(equalTo: contentTextView.bottomAnchor, constant: 16),
            tagsTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tagsTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            colorSegmentedControl.topAnchor.constraint(equalTo: tagsTextField.bottomAnchor, constant: 16),
            colorSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            colorSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveTapped() {
        guard let title = titleTextField.text, !title.isEmpty,
              let content = contentTextView.text, !content.isEmpty else {
            showAlert(title: "Error", message: "Please fill in both title and content")
            return
        }
        
        let tags = tagsTextField.text?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } ?? []
        let selectedColor = NoteColor.allCases[colorSegmentedControl.selectedSegmentIndex]
        
        let note = Note(title: title, content: content, tags: tags, color: selectedColor)
        delegate?.didAddNote(note)
        dismiss(animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Note Detail View Controller

class NoteDetailViewController: UIViewController {
    private var note: Note
    weak var delegate: NoteDetailDelegate?
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let contentTextView = UITextView()
    private let dateLabel = UILabel()
    private let tagsStackView = UIStackView()
    
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
        configureWithNote()
    }
    
    private func setupUI() {
        title = "Note Details"
        view.backgroundColor = .systemGroupedBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .edit,
            target: self,
            action: #selector(editTapped)
        )
        
        // Scroll view setup
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Title label
        titleLabel.font = UIFont.preferredFont(forTextStyle: .title1)
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Content text view
        contentTextView.font = UIFont.preferredFont(forTextStyle: .body)
        contentTextView.isEditable = false
        contentTextView.backgroundColor = .clear
        contentTextView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(contentTextView)
        
        // Date label
        dateLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        dateLabel.textColor = .secondaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dateLabel)
        
        // Tags stack view
        tagsStackView.axis = .horizontal
        tagsStackView.spacing = 8
        tagsStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tagsStackView)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            contentTextView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            contentTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contentTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            contentTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
            
            tagsStackView.topAnchor.constraint(equalTo: contentTextView.bottomAnchor, constant: 16),
            tagsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tagsStackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
            
            dateLabel.topAnchor.constraint(equalTo: tagsStackView.bottomAnchor, constant: 16),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    private func configureWithNote() {
        titleLabel.text = note.title
        contentTextView.text = note.content
        dateLabel.text = "Updated: \(formatDate(note.updatedAt))"
        
        // Configure tags
        tagsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for tag in note.tags {
            let tagLabel = createTagLabel(text: tag)
            tagsStackView.addArrangedSubview(tagLabel)
        }
        
        // Set background color based on note color
        view.backgroundColor = note.color.uiColor
    }
    
    private func createTagLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.textColor = .systemBlue
        label.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        label.textAlignment = .center
        label.padding = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        return label
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    @objc private func editTapped() {
        let editVC = EditNoteViewController(note: note)
        editVC.delegate = self
        let navController = UINavigationController(rootViewController: editVC)
        present(navController, animated: true)
    }
}

// MARK: - Edit Note View Controller

class EditNoteViewController: UIViewController {
    private var note: Note
    weak var delegate: NoteDetailDelegate?
    
    private let titleTextField = UITextField()
    private let contentTextView = UITextView()
    private let tagsTextField = UITextField()
    
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
        populateFields()
    }
    
    private func setupUI() {
        title = "Edit Note"
        view.backgroundColor = .systemGroupedBackground
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveTapped)
        )
        
        // Title text field
        titleTextField.borderStyle = .roundedRect
        titleTextField.font = UIFont.preferredFont(forTextStyle: .title2)
        titleTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleTextField)
        
        // Content text view
        contentTextView.font = UIFont.preferredFont(forTextStyle: .body)
        contentTextView.layer.borderColor = UIColor.systemGray4.cgColor
        contentTextView.layer.borderWidth = 1
        contentTextView.layer.cornerRadius = 8
        contentTextView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentTextView)
        
        // Tags text field
        tagsTextField.borderStyle = .roundedRect
        tagsTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tagsTextField)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            titleTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            contentTextView.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 16),
            contentTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            contentTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            contentTextView.heightAnchor.constraint(equalToConstant: 300),
            
            tagsTextField.topAnchor.constraint(equalTo: contentTextView.bottomAnchor, constant: 16),
            tagsTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tagsTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    private func populateFields() {
        titleTextField.text = note.title
        contentTextView.text = note.content
        tagsTextField.text = note.tags.joined(separator: ", ")
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveTapped() {
        guard let title = titleTextField.text, !title.isEmpty,
              let content = contentTextView.text, !content.isEmpty else {
            showAlert(title: "Error", message: "Please fill in both title and content")
            return
        }
        
        let tags = tagsTextField.text?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } ?? []
        
        note.title = title
        note.content = content
        note.tags = tags
        note.updatedAt = Date()
        
        delegate?.didUpdateNote(note)
        dismiss(animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Extensions

extension UILabel {
    var padding: UIEdgeInsets {
        get { return UIEdgeInsets.zero }
        set {
            let insets = newValue
            let topInset = insets.top
            let leftInset = insets.left
            let bottomInset = insets.bottom
            let rightInset = insets.right
            
            let topConstraint = constraints.first { $0.firstAttribute == .top }
            let leftConstraint = constraints.first { $0.firstAttribute == .leading }
            let bottomConstraint = constraints.first { $0.firstAttribute == .bottom }
            let rightConstraint = constraints.first { $0.firstAttribute == .trailing }
            
            topConstraint?.constant = topInset
            leftConstraint?.constant = leftInset
            bottomConstraint?.constant = bottomInset
            rightConstraint?.constant = rightInset
        }
    }
}

// MARK: - Delegates

protocol AddNoteDelegate: AnyObject {
    func didAddNote(_ note: Note)
}

protocol NoteDetailDelegate: AnyObject {
    func didUpdateNote(_ note: Note)
    func didDeleteNote(_ note: Note)
}

extension NoteDetailViewController: NoteDetailDelegate {
    func didUpdateNote(_ note: Note) {
        self.note = note
        configureWithNote()
        delegate?.didUpdateNote(note)
    }
    
    func didDeleteNote(_ note: Note) {
        delegate?.didDeleteNote(note)
        navigationController?.popViewController(animated: true)
    }
}
