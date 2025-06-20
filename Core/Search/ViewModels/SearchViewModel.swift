import Foundation
import SwiftUI

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    
    func performSearch() {
        print("Searching for: \(searchText)")
    }
}
