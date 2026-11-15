// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(SpriteKit) && canImport(UIKit) && DEBUG
import GameCore
import SpriteKit
import UIKit

/// Hidden DEBUG-only panel to live-edit a subset of `Tuning` values.
public final class DebugTuningMenu: SKNode {
    public var tuning: Tuning
    public var onChange: ((Tuning) -> Void)?

    private let panel = SKShapeNode()
    private struct Row {
        var name: String
        var key: WritableKeyPath<Tuning, Double>
        var step: Double
        var label: SKLabelNode
    }
    private var rows: [Row] = []

    public init(tuning: Tuning) {
        self.tuning = tuning
        super.init()
        name = "debugTuning"
        isHidden = true
        zPosition = 900

        panel.path = CGPath(
            roundedRect: CGRect(x: -160, y: -220, width: 320, height: 440),
            cornerWidth: 12, cornerHeight: 12, transform: nil
        )
        panel.fillColor = SKColor(white: 0.05, alpha: 0.92)
        panel.strokeColor = ArtCatalog.neonCyan
        panel.lineWidth = 2
        addChild(panel)

        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = "TUNING (DEBUG)"
        title.fontSize = 14
        title.fontColor = ArtCatalog.neonCyan
        title.position = CGPoint(x: 0, y: 190)
        addChild(title)

        let specs: [(String, WritableKeyPath<Tuning, Double>, Double)] = [
            ("runSpeed", \.runSpeed, 0.2),
            ("jumpVelocity", \.jumpVelocity, 0.3),
            ("gravity", \.gravity, 2),
            ("coyoteSeconds", \.coyoteSeconds, 0.01),
            ("jumpBufferSeconds", \.jumpBufferSeconds, 0.01),
            ("wallSlideSpeed", \.wallSlideSpeed, 0.1),
            ("cameraLeadTiles", \.cameraLeadTiles, 0.1),
            ("cameraSmooth", \.cameraSmooth, 0.01),
        ]
        for (i, item) in specs.enumerated() {
            let y = 150 - CGFloat(i) * 36
            let lab = SKLabelNode(fontNamed: "Menlo-Bold")
            lab.fontSize = 11
            lab.fontColor = .white
            lab.horizontalAlignmentMode = .left
            lab.position = CGPoint(x: -140, y: y)
            addChild(lab)
            rows.append(Row(name: item.0, key: item.1, step: item.2, label: lab))

            addChild(makeChip("−", name: "minus-\(i)", at: CGPoint(x: 90, y: y + 6)))
            addChild(makeChip("+", name: "plus-\(i)", at: CGPoint(x: 130, y: y + 6)))
        }
        refresh()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func makeChip(_ text: String, name: String, at p: CGPoint) -> SKShapeNode {
        let n = SKShapeNode(circleOfRadius: 14)
        n.fillColor = ArtCatalog.neonPink.withAlphaComponent(0.5)
        n.strokeColor = ArtCatalog.neonPink
        n.position = p
        n.name = name
        let t = SKLabelNode(fontNamed: "AvenirNext-Bold")
        t.text = text
        t.fontSize = 16
        t.verticalAlignmentMode = .center
        t.name = name
        n.addChild(t)
        return n
    }

    public func refresh() {
        for row in rows {
            row.label.text = String(format: "%@: %.3f", row.name, tuning[keyPath: row.key])
        }
    }

    public func toggle() { isHidden.toggle() }

    public func handleTap(at pointInOverlay: CGPoint) -> Bool {
        guard !isHidden, let parent else { return false }
        let local = convert(pointInOverlay, from: parent)
        let hits = nodes(at: local)
        for n in hits {
            guard let name = n.name else { continue }
            if name.hasPrefix("minus-"), let i = Int(name.dropFirst(6)), rows.indices.contains(i) {
                tuning[keyPath: rows[i].key] = max(0.001, tuning[keyPath: rows[i].key] - rows[i].step)
                refresh(); onChange?(tuning); return true
            }
            if name.hasPrefix("plus-"), let i = Int(name.dropFirst(5)), rows.indices.contains(i) {
                tuning[keyPath: rows[i].key] += rows[i].step
                refresh(); onChange?(tuning); return true
            }
        }
        return panel.contains(local)
    }
}
#endif
