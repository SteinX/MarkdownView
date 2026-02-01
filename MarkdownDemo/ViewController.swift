//
//  ViewController.swift
//  MarkdownDemo
//
//  Created by Yiming XIA on 2025/12/21.
//

import UIKit
import STXMarkdownView

class ViewController: UIViewController, UITableViewDataSource {

    let tableView = UITableView()
    
    // Data Source
    var messages: [String] = []
    
    // Streaming
    private let streamButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Start Stream", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 20
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.translatesAutoresizingMaskIntoConstraints = false
        // Add shadow for better visibility
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 4
        return button
    }()
    
    private var streamingSimulator: StreamingSimulator?
    private var isStreaming = false

    let markdownContent = """
    # Markdown syntax guide

    ## Headers

    # This is a Heading h1
    ## This is a Heading h2
    ###### This is a Heading h6

    ## Emphasis

    *This text will be italic*  
    _This will also be italic_

    **This text will be bold**  
    __This will also be bold__

    _You **can** combine them_

    ## Lists

    ### Unordered

    * Item 1
    * Item 2
    * Item 2a
    * Item 2b
        * Item 3a
        * Item 3b

    ### Ordered

    1. Item 1
    2. Item 2
    3. Item 3 dsdjskdjlksajdlksajdlksjdkaljdksldjskajdlasjdklsjdkajdlasjdaldjsdjsdjalkadjslkajdlkjsladj
        1. Item 3a
        2. Item 3b
            > dsadsadsad dsadksadskadakdsa `dsadsad` dsadsdsadsadsadsad
        3. > dsadsadsad dsadksadskadakdsa `dsadsad` dsadsdsadsadsadsad
        4. text
            5. 2232131
            6. dsadsad
    
    ## Blockquotes
    
    > Markdown is a lightweight markup language with plain-text-formatting syntax, created in 2004 by John Gruber with Aaron Swartz.
    >
    >> Markdown is often used to format readme files, for writing messages in online discussion forums, and to create rich text using a plain text editor.

    ## Code Block
    ```swift
    func hello() {
        print("Hello World")
    }
    ```

    ## Long & Complex Code Block
    ```rust
    // A more complex example to test highlighting and wrapping
    #[derive(Debug)]
    struct Point {
        x: i32,
        y: i32,
    }

    fn main() {
        let p = Point { x: 10, y: 20 };
        println!("Point is: {:?}", p);
        
        let scores = vec![10, 20, 30, 40, 50];
        let sum: i32 = scores.iter().filter(|&&x| x > 20).sum();
        println!("Sum of scores > 20: {}", sum);
    }
    ```
    
    ## Large Table
    | ID | Name | Role | Department | Location | Status | Project | Date | Hours | Notes |
    | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
    | 001 | Alice Smith | Developer | Engineering | New York | Active | Alpha | 2023-01-01 | 8.0 | Started initial phase |
    | 002 | Bob Johnson | Designer | Design | London | Away | Beta | 2023-01-02 | 7.5 | Mockups review |
    | 003 | Charlie Brown | Manager | Product | San Francisco | Active | Gamma | 2023-01-03 | 9.0 | Q1 planning |
    | 004 | David Lee | QA | Engineering | Tokyo | Offline | Alpha | 2023-01-04 | 8.0 | Testing cycle 1 |
    | 005 | Eve Davis | Developer | Engineering | Berlin | Active | Beta | 2023-01-05 | 8.5 | Backend API setup |
    | 006 | Frank Miller | DevOps | Infra | Toronto | Active | Delta | 2023-01-06 | 8.0 | CI/CD pipeline |
    | 007 | Grace Wilson | HR | People | Sydney | Active | Omega | 2023-01-07 | 7.0 | Interviews |
    | 008 | Henry Moore | Analyst | Data | Paris | Vacation | Epsilon | 2023-01-08 | 0.0 | Out of office |
    | 009 | Ivy Taylor | Marketing | Growth | Singapore | Active | Zeta | 2023-01-09 | 8.0 | Campaign launch |
    | 010 | Jack Anderson | Sales | Sales | Chicago | Active | Eta | 2023-01-10 | 9.5 | Client meeting |
    | 011 | Kelly Thomas | Developer | Engineering | New York | Active | Alpha | 2023-01-11 | 8.0 | Feature A impl |
    | 012 | Liam Jackson | Designer | Design | London | Active | Beta | 2023-01-12 | 7.5 | Icon assets |
    | 013 | Mia White | PO | Product | San Francisco | Active | Gamma | 2023-01-13 | 8.5 | Backlog grooming |
    | 014 | Noah Harris | QA | Engineering | Tokyo | Active | Alpha | 2023-01-14 | 8.0 | Regression test |
    | 015 | Olivia Martin | Writer | Content | Berlin | Active | Zeta | 2023-01-15 | 6.0 | Blog post draft |
    
    ## Quote
    > This is a block quote.
    > It can span multiple lines.

    # Advanced Tables
    
    ## Small Table
    | # | Item | Price |
    | :--- | :--- | :--- |
    | 1 | Apple | $1.00 |
    | 2 | Banana | $0.50 |

    ## Long Content Table
    | Feature | Description | Status |
    | :--- | :--- | :--- |
    | Authentication | Secure login system aimed to support OAuth2, JWT, and biometric authentication (FaceID/TouchID) for mobile devices, ensuring user data privacy and security compliance with GDPR and CCPA. | In Progress |
    | Database | High-performance distributed SQL database setup with sharding and replication to handle petabytes of data with 99.999% availability SLA. | Pending |
    | UI/UX | Modern glassmorphism design language usage with adaptive dark mode support and micro-interactions. | Done |

    ## Rich Text Table
    | Formatting | Example | Result |
    | :--- | :--- | :--- |
    | Bold | Use `**text**` | This is **Bold** |
    | Italic | Use `*text*` | This is *Italic* |
    | Code | Use `` `code` `` | `print("Hello")` |
    | Mixed | Complicated | **Bold** and *Italic* inside |

    ## Complex Mixed Content

    > ### Quote with List
    > * **Bold Item** in a quote
    > * _Italic Item_ with `inline code`
    > * Nested list:
    >   1. Ordered item 1
    >   2. Ordered item 2 containing *mixed emphasis*
    > * Return to unordered list

    1. List item containing a quote:
        > This is a quote inside a list item.
        > It has multiple lines.
        > And some **bold text**.
    2. Another item with complex mixed content:
        * Sub-item 1
        * Sub-item 2 with `code`

    ## Blocks in List/Quote

    1. List with Code Block:
        ```swift
        let x = 10
        print(x)
        ```
    2. List with Table:
        | Col A | Col B |
        | --- | --- |
        | Val 1 | Val 2 |   

    > Quote with Table:
    > | Q-Col 1 | Q-Col 2 |
    > | --- | --- |
    > | Data A | Data B |
    
    ## New Inline Elements
    
    This is a [Link](https://apple.com) and this is ~strikethrough text~.
    
    ## Enhanced List Layout Investigations

    1.  **Level 1 Item (Ordered)**
        
        This item contains a paragraph of text mixed with blocks.
        
        ```swift
        // Code block at Level 1
        print("Level 1 Code")
        ```
        
        More text at Level 1 after the code block.

        *   **Level 2 Item (Unordered)**
            
            This nested item also has mixed content.
            
            > Blockquote at Level 2.
            > It spans multiple lines.
            
            And here is a table at Level 2:
            
            | L2 Header 1 | L2 Header 2 |
            | :--- | :--- |
            | Cell 1 | Cell 2 |
            
            1.  **Level 3 Item (Ordered)**
                
                Deeply nested item with a code block.
                
                ```python
                # Code block at Level 3
                def level_3():
                    pass
                ```
                
                Closing text for Level 3.

        *   **Another Level 2 Item**
            
            Just some plain text here to verify spacing.

    2.  **Level 1 Item (Cont)**
        
        Verifying multiple sibling items with complex content.

    ## New Elements Verification

    ### Thematic Break
    Prior to break
    
    ***
    
    After break

    ### Task Lists
    - [ ] Pending Item
    - [x] Completed Item
    - [ ] Item with **Bold**
    - [x] Item with `Code`

    ### Images
    
    #### Block Image
    ![Block Image](https://images.ctfassets.net/8aevphvgewt8/36rqLbFzJsdRRFHNM4TXIU/afdb59a69ee38661aed3e66f73970ce2/github-copilot-agent-mode.png?w=1440&fm=webp&q=90)

    #### Inline Image
    This is an inline image ![Inline](https://images.ctfassets.net/8aevphvgewt8/36rqLbFzJsdRRFHNM4TXIU/afdb59a69ee38661aed3e66f73970ce2/github-copilot-agent-mode.png?w=1440&fm=webp&q=90) in text.

    #### Nested Images
    
    > Quote with Image (Should be dimmed):
    > ![QuoteImg](https://images.ctfassets.net/8aevphvgewt8/36rqLbFzJsdRRFHNM4TXIU/afdb59a69ee38661aed3e66f73970ce2/github-copilot-agent-mode.png?w=1440&fm=webp&q=90)
    
    | Table | Image |
    | :--- | :--- |
    | Cell | ![TableImg](https://images.ctfassets.net/8aevphvgewt8/36rqLbFzJsdRRFHNM4TXIU/afdb59a69ee38661aed3e66f73970ce2/github-copilot-agent-mode.png?w=1440&fm=webp&q=90) |

    #### List with Images
    
    *   Item 1
    *   Item with inline Image: ![ListIcon](https://images.ctfassets.net/8aevphvgewt8/36rqLbFzJsdRRFHNM4TXIU/afdb59a69ee38661aed3e66f73970ce2/github-copilot-agent-mode.png?w=1440&fm=webp&q=90) inside content
    *   Item 3

    #### Block Images in Lists

    1.  First item with block image below:
        
        ![BlockInList](https://images.ctfassets.net/8aevphvgewt8/36rqLbFzJsdRRFHNM4TXIU/afdb59a69ee38661aed3e66f73970ce2/github-copilot-agent-mode.png?w=1440&fm=webp&q=90)
        
    2.  Second item (no image)
    
    #### Multi-level Lists with Block Images
    
    1.  Level 1 Item
        *   Level 2 with block image:
            
            ![L2Img](https://images.ctfassets.net/8aevphvgewt8/36rqLbFzJsdRRFHNM4TXIU/afdb59a69ee38661aed3e66f73970ce2/github-copilot-agent-mode.png?w=1440&fm=webp&q=90)
            
            1.  Level 3 Item
                
                ![L3Img](https://images.ctfassets.net/8aevphvgewt8/36rqLbFzJsdRRFHNM4TXIU/afdb59a69ee38661aed3e66f73970ce2/github-copilot-agent-mode.png?w=1440&fm=webp&q=90)
    
    ## JSON Content
    ```json
    {
      "name": "MarkdownDemo",
      "version": "1.0.0",
      "settings": {
        "theme": "dark",
        "notifications": true,
        "retry_count": 3
      },
      "features": [
        "syntax_highlighting",
        "tables",
        "images"
      ]
    }
    ```

    ## SQL Query
    ```sql
    SELECT 
        u.id, 
        u.username, 
        COUNT(o.id) as order_count 
    FROM users u
    LEFT JOIN orders o ON u.id = o.user_id
    WHERE u.active = true
      AND o.created_at >= '2023-01-01'
    GROUP BY u.id
    HAVING order_count > 5
    ORDER BY order_count DESC;
    ```
    """

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Chat"
        
        // Enable debug logging for development (with performance timing)
        // View logs in Console.app by filtering: subsystem:com.app.markdown
        MarkdownView.logLevel = .verbose
        
        // Other available log levels:
        // MarkdownView.logLevel = .info   // Info-level logging only
        // MarkdownView.logLevel = .error  // Error-level logging only
        // MarkdownView.logLevel = .off    // Disable all logging
        
        tableView.frame = view.bounds
        tableView.dataSource = self
        tableView.register(ChatBubbleCell.self, forCellReuseIdentifier: "Cell")
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 200
        tableView.allowsSelection = false
        tableView.delaysContentTouches = false
        view.addSubview(tableView)
        
        // Initial Data
        messages.append(markdownContent)
        
        setupStreamButton()
    }
    
    private func setupStreamButton() {
        view.addSubview(streamButton)
        NSLayoutConstraint.activate([
            streamButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            streamButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            streamButton.widthAnchor.constraint(equalToConstant: 140),
            streamButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        streamButton.addTarget(self, action: #selector(toggleStreaming), for: .touchUpInside)
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
        streamButton.setTitle("Stop", for: .normal)
        streamButton.backgroundColor = .systemRed
        
        // Add a new empty message for streaming
        messages.append("")
        let newIndexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.insertRows(at: [newIndexPath], with: .bottom)
        
        // Force layout immediately so cell becomes visible/accessible
        view.layoutIfNeeded()
        tableView.scrollToRow(at: newIndexPath, at: .bottom, animated: false)
        
        // Enable streaming mode for throttled rendering
        if let cell = self.tableView.cellForRow(at: newIndexPath) as? ChatBubbleCell {
            cell.setStreaming(true)
            // Optional: Customize throttle interval (default is 100ms)
            // cell.setThrottleInterval(0.15)
        }
        
        // Use the same content for demo, but streamed
        streamingSimulator = StreamingSimulator(text: markdownContent)
        
        streamingSimulator?.start(onUpdate: { [weak self] currentText in
            guard let self = self else { return }
            
            // Update data source
            self.messages[self.messages.count - 1] = currentText
            
            // Update cell if visible
            let lastIndexPath = IndexPath(row: self.messages.count - 1, section: 0)
            if let cell = self.tableView.cellForRow(at: lastIndexPath) as? ChatBubbleCell {
                // Check if we are near the bottom BEFORE updating the cell height
                // This determines if we should "stick" to the bottom after the update
                let threshold: CGFloat = 20.0
                let contentHeight = self.tableView.contentSize.height
                let boundsHeight = self.tableView.bounds.size.height
                let currentOffset = self.tableView.contentOffset.y
                let maxOffset = max(0, contentHeight - boundsHeight)
                let isNearBottom = (maxOffset - currentOffset) <= threshold
                
                cell.configure(with: currentText)
                
                // Animate height change smoothly
                UIView.setAnimationsEnabled(false)
                self.tableView.performBatchUpdates(nil)
                UIView.setAnimationsEnabled(true)
                
                // Only scroll to bottom if user is not manually scrolling AND was already near bottom
                if !self.tableView.isDragging && !self.tableView.isTracking && isNearBottom {
                     self.tableView.scrollToRow(at: lastIndexPath, at: .bottom, animated: false)
                }
            } else {
                 // Cell not visible, likely scrolled up. No need to force scroll.
            }
        }, onComplete: { [weak self] in
            self?.stopStreaming()
        })
    }
    
    private func stopStreaming() {
        isStreaming = false
        streamButton.setTitle("Start Stream", for: .normal)
        streamButton.backgroundColor = .systemBlue
        
        // Disable streaming mode to trigger final render
        let lastIndexPath = IndexPath(row: messages.count - 1, section: 0)
        if let cell = self.tableView.cellForRow(at: lastIndexPath) as? ChatBubbleCell {
            cell.setStreaming(false)
        }
        
        streamingSimulator?.stop()
        streamingSimulator = nil
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ChatBubbleCell
        cell.configure(with: messages[indexPath.row])
        return cell
    }
}
