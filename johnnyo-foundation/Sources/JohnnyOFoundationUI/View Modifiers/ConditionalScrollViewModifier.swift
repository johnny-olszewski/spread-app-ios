//
//  ConditionalScrollViewModifier.swift
//  Spread
//
//  Created by Johnny O on 6/5/26.
//

import SwiftUI

struct ConditionalScrollViewModifier: ViewModifier {
    
    func body(content: Content) -> some View {
        ViewThatFits(in: .vertical) {
            VStack {
                content
            }
            .frame(maxHeight: .infinity, alignment: .top)
            
            ScrollView {
                content
            }
        }
    }
}

public extension View {
    func conditionalScrollView() -> some View {
        modifier(ConditionalScrollViewModifier())
    }
}
