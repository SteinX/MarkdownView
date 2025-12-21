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
    # Hello Markdown
    
    This is a **bold** text and *italic* text.
    
    ## Code Block
    ```swift
    func hello() {
        print("Hello World")
    }
    ```
    
    ## Table
    | Header 1 | Header 2 | Header 3 |
    | :--- | :--- | :--- |
    | Row 1 Col 1 | Row 1 Col 2 | Row 1 Col 3 |
    | Row 2 Col 1 | Row 2 Col 2 | Row 2 Col 3 |
    
    ## Quote
    > This is a block quote.
    > It can span multiple lines.
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

