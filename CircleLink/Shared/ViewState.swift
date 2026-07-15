import Foundation

enum ViewState<T: Equatable>: Equatable {
    case idle
    case loading
    case loaded(T)
    case empty
    case error(String)
}
