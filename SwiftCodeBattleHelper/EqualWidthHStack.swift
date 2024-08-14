import SwiftUI

struct EqualWidthHStack: Layout {
    let spacing: CGFloat
    init(spacing: CGFloat = 5) {
        self.spacing = spacing
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 10, height: proposal.height ?? 10)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let subviewWidth = bounds.width / CGFloat(subviews.count) - spacing
        var xPosition = bounds.minX

        for subview in subviews {
            let subviewSize = CGSize(width: subviewWidth, height: bounds.height)
            subview.place(at: CGPoint(x: xPosition, y: bounds.minY), proposal: ProposedViewSize(subviewSize))
            xPosition += spacing + subviewWidth
        }
    }
}
