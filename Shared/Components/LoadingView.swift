//
//  LoadingView.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/18/25.
//

// File: Shared/Components/LoadingView.swift
import SwiftUI

struct FloatingLogoView: View {
    @State private var float = false

    var body: some View {
        VStack {
            Spacer()

            Image("images/Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 200)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .zIndex(999)
            
            
            Spacer()
        }
        .background(Color.white) // Add this line temporarily
    }
}

#Preview {
    FloatingLogoView()
}
