//
//  FileCell.swift
//  iCloud Example
//
//  Created by Oskari Rauta on 26/12/2018.
//  Copyright © 2018 Oskari Rauta. All rights reserved.
//

import UIKit

class FileCell: UITableViewCell {

    var title: String? {
        get { return self.titleLabel.text }
        set { self.titleLabel.text = newValue }
    }
    
    var detail: String? {
        get { return self.detailLabel.text }
        set { self.detailLabel.text = newValue }
    }
    
    var titleLabel: UILabel = {
        var _label: UILabel = UILabel()
        _label.translatesAutoresizingMaskIntoConstraints = false
        _label.font = UIFont.boldSystemFont(ofSize: 13.0)
        _label.textColor = UIColor.black
        _label.textAlignment = .left
        _label.allowsDefaultTighteningForTruncation = true
        _label.lineBreakMode = .byTruncatingTail
        _label.text = nil
        return _label
    }()

    var detailLabel: UILabel = {
        var _label: UILabel = UILabel()
        _label.translatesAutoresizingMaskIntoConstraints = false
        _label.font = UIFont.systemFont(ofSize: 11.0)
        _label.textColor = UIColor.black
        _label.textAlignment = .left
        _label.allowsDefaultTighteningForTruncation = true
        _label.lineBreakMode = .byTruncatingTail
        _label.numberOfLines = 2
        _label.text = nil
        return _label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.contentView.addSubview(self.titleLabel)
        self.contentView.addSubview(self.detailLabel)
        
        self.titleLabel.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 6.0).isActive = true
        self.titleLabel.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 6.0).isActive = true
        self.titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: self.contentView.trailingAnchor, constant: -4.0).isActive = true

        self.detailLabel.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor, constant: 2.0).isActive = true
        self.detailLabel.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 6.5).isActive = true
        self.detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: self.contentView.trailingAnchor, constant: -4.0).isActive = true
        self.detailLabel.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -4.0).isActive = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
