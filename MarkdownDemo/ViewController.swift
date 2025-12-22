//
//  ViewController.swift
//  MarkdownDemo
//
//  Created by Yiming XIA on 2025/12/21.
//

import UIKit

class ViewController: UIViewController, UITableViewDataSource {

    let tableView = UITableView()
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
    3. Item 3
        1. Item 3a
        2. Item 3b
        3. > dsadsadsad dsadksadskadakdsa `dsadsad` dsadsdsadsadsadsad
            1. 2232131
            2. dsadsad
    
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
    """

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        
        tableView.frame = view.bounds
        tableView.dataSource = self
        tableView.register(ChatBubbleCell.self, forCellReuseIdentifier: "Cell")
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 200
        view.addSubview(tableView)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5 // Show 5 bubbles to test performance
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ChatBubbleCell
        cell.configure(with: markdownContent)
        return cell
    }
}

