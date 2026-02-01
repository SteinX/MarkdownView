import UIKit
import STXMarkdownView

final class StreamingDemoViewController: UIViewController {

    private let markdownView = MarkdownView()
    private let toggleButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Start Stream", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 14
        button.titleLabel?.font = .boldSystemFont(ofSize: 14)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Idle"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var streamingSimulator: StreamingSimulator?
    private var isStreaming = false

    private let markdownContent = """
    # Streaming Demo

    This tab renders the same Markdown repeatedly while streaming.

    ## Code
    ```swift
    func demo() {
        print(\"streaming\")
    }
    ```

    ## Table
    | Col A | Col B | Col C |
    | :--- | :--- | :--- |
    | 1 | 2 | 3 |
    | 4 | 5 | 6 |

    ## Quote
    > Streaming updates should reuse views.

    ## Image
    ![Inline](https://images.ctfassets.net/8aevphvgewt8/36rqLbFzJsdRRFHNM4TXIU/afdb59a69ee38661aed3e66f73970ce2/github-copilot-agent-mode.png?w=1440&fm=webp&q=90)
    """

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemGroupedBackground
        MarkdownView.logLevel = .verbose

        markdownView.translatesAutoresizingMaskIntoConstraints = false
        markdownView.isScrollEnabled = false
        markdownView.backgroundColor = .clear
        markdownView.isStreaming = false

        view.addSubview(markdownView)
        view.addSubview(toggleButton)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            markdownView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            markdownView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            markdownView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),

            toggleButton.topAnchor.constraint(equalTo: markdownView.bottomAnchor, constant: 16),
            toggleButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            toggleButton.widthAnchor.constraint(equalToConstant: 140),
            toggleButton.heightAnchor.constraint(equalToConstant: 36),

            statusLabel.centerYAnchor.constraint(equalTo: toggleButton.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: toggleButton.trailingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])

        toggleButton.addTarget(self, action: #selector(toggleStreaming), for: .touchUpInside)

        markdownView.markdown = markdownContent
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let availableWidth = view.bounds.width - 32
        if availableWidth > 0 && markdownView.preferredMaxLayoutWidth != availableWidth {
            markdownView.preferredMaxLayoutWidth = availableWidth
        }
    }

    @objc private func toggleStreaming() {
        if isStreaming {
            stopStreaming()
        } else {
            startStreaming()
        }
    }

    private func startStreaming() {
        isStreaming = true
        statusLabel.text = "Streaming"
        toggleButton.setTitle("Stop", for: .normal)
        toggleButton.backgroundColor = .systemRed

        markdownView.isStreaming = true
        streamingSimulator = StreamingSimulator(text: markdownContent)
        streamingSimulator?.start(onUpdate: { [weak self] currentText in
            self?.markdownView.markdown = currentText
        }, onComplete: { [weak self] in
            self?.stopStreaming()
        })
    }

    private func stopStreaming() {
        isStreaming = false
        statusLabel.text = "Idle"
        toggleButton.setTitle("Start Stream", for: .normal)
        toggleButton.backgroundColor = .systemBlue

        markdownView.isStreaming = false
        streamingSimulator?.stop()
        streamingSimulator = nil
    }
}
