import SwiftUI

/// Disposition simple en « flux » : place les éléments de gauche à droite et
/// passe à la ligne suivante quand la largeur est dépassée (pour les puces).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]
        var currentRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentRowWidth = 0
            }
            rows[rows.count - 1].append(size)
            currentRowWidth += size.width + spacing
        }

        let height = rows.reduce(0) { partial, row in
            partial + (row.map(\.height).max() ?? 0) + spacing
        } - (rows.isEmpty ? 0 : spacing)

        return CGSize(width: maxWidth == .infinity ? currentRowWidth : maxWidth,
                      height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
