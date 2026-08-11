import Foundation

/// A single problem in the math dismissal challenge (PRD.md §6.1) — the fallback for when
/// walking isn't possible (e.g. injury). Difficulty scales with `index` so the last problem
/// in a sequence takes more attention than the first, on the theory that a half-asleep reflex
/// answer shouldn't be enough to silence the alarm.
struct MathProblem: Equatable {
    enum Operator: String {
        case add = "+"
        case subtract = "\u{2212}"
        case multiply = "\u{00D7}"
    }

    let lhs: Int
    let rhs: Int
    let op: Operator
    let answer: Int

    var prompt: String { "\(lhs) \(op.rawValue) \(rhs)" }

    static func generate(index: Int) -> MathProblem {
        var generator = SystemRandomNumberGenerator()
        return generate(index: index, using: &generator)
    }

    static func generate<G: RandomNumberGenerator>(index: Int, using generator: inout G) -> MathProblem {
        let difficulty = min(max(index, 1), 6) // cap so later problems don't get absurd
        let magnitude = 5 * difficulty

        let op: Operator = difficulty >= 4 ? .multiply : (Bool.random(using: &generator) ? .add : .subtract)

        switch op {
        case .add:
            let lhs = Int.random(in: magnitude...(magnitude * 2), using: &generator)
            let rhs = Int.random(in: 2...magnitude, using: &generator)
            return MathProblem(lhs: lhs, rhs: rhs, op: .add, answer: lhs + rhs)

        case .subtract:
            let a = Int.random(in: magnitude...(magnitude * 2), using: &generator)
            let b = Int.random(in: 2...magnitude, using: &generator)
            let (bigger, smaller) = a >= b ? (a, b) : (b, a)
            return MathProblem(lhs: bigger, rhs: smaller, op: .subtract, answer: bigger - smaller)

        case .multiply:
            let lhs = Int.random(in: 2...12, using: &generator)
            let rhs = Int.random(in: 2...12, using: &generator)
            return MathProblem(lhs: lhs, rhs: rhs, op: .multiply, answer: lhs * rhs)
        }
    }
}
