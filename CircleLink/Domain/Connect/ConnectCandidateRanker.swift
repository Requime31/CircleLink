import Foundation

/// Pure ranking helper: more shared interests first, then display name.
enum ConnectCandidateRanker {
    static func ranked(_ candidates: [User], matching myInterests: [String]) -> [User] {
        let mine = Set(myInterests.map { $0.lowercased() })
        guard !mine.isEmpty else {
            return candidates.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        }

        return candidates.sorted { lhs, rhs in
            let leftScore = sharedCount(lhs.interests, with: mine)
            let rightScore = sharedCount(rhs.interests, with: mine)
            if leftScore != rightScore {
                return leftScore > rightScore
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private static func sharedCount(_ interests: [String], with mine: Set<String>) -> Int {
        Set(interests.map { $0.lowercased() }).intersection(mine).count
    }
}
