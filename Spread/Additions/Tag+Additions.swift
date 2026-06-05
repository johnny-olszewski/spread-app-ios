//
//  File.swift
//  Spread
//
//  Created by Johnny O on 6/5/26.
//

import SwiftUI
import JohnnyOFoundationUI

extension DataModel.Tag: LabelChipRepresentable {
    
    var title: String { self.name }
    
    var fillColor: Color { self.chipColor }
    
    var strokeColor: Color? { nil }
    
    
}
