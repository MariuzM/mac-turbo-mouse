import SwiftUI

struct CurveView: View {
    let acceleration: Double
    let isActive: Bool

    var body: some View {
        Canvas { ctx, size in
            let inset: CGFloat = 10
            let plot = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)

            var grid = Path()
            for i in 1...3 {
                let x = plot.minX + plot.width * CGFloat(i) / 4
                let y = plot.minY + plot.height * CGFloat(i) / 4
                grid.move(to: CGPoint(x: x, y: plot.minY))
                grid.addLine(to: CGPoint(x: x, y: plot.maxY))
                grid.move(to: CGPoint(x: plot.minX, y: y))
                grid.addLine(to: CGPoint(x: plot.maxX, y: y))
            }
            ctx.stroke(grid, with: .color(.primary.opacity(0.06)), lineWidth: 1)

            let frame = Path(roundedRect: plot, cornerRadius: 0)
            ctx.stroke(frame, with: .color(.primary.opacity(0.1)), lineWidth: 1)

            if acceleration > 0.001 {
                var identity = Path()
                identity.move(to: CGPoint(x: plot.minX, y: plot.maxY))
                identity.addLine(to: CGPoint(x: plot.maxX, y: plot.minY))
                ctx.stroke(
                    identity,
                    with: .color(.secondary.opacity(0.35)),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
            }

            var curve = Path()
            let steps = 60
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let point = CGPoint(
                    x: plot.minX + plot.width * CGFloat(t),
                    y: plot.maxY - plot.height * CGFloat(output(t))
                )
                if i == 0 { curve.move(to: point) } else { curve.addLine(to: point) }
            }

            var area = curve
            area.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
            area.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
            area.closeSubpath()

            let colors: [Color] = isActive ? [accentBlue, accentBlue] : [.gray, .gray]
            ctx.fill(
                area,
                with: .linearGradient(
                    Gradient(colors: colors.map { $0.opacity(0.12) }),
                    startPoint: CGPoint(x: plot.minX, y: plot.minY),
                    endPoint: CGPoint(x: plot.maxX, y: plot.maxY)
                )
            )
            ctx.stroke(
                curve,
                with: .linearGradient(
                    Gradient(colors: colors),
                    startPoint: CGPoint(x: plot.minX, y: plot.maxY),
                    endPoint: CGPoint(x: plot.maxX, y: plot.minY)
                ),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
        }
        .animation(.easeOut(duration: 0.15), value: acceleration)
    }

    private func output(_ x: Double) -> Double {
        guard acceleration > 0.001 else { return x }
        return x * (1 + acceleration * pow(x, 1.5)) / (1 + acceleration)
    }
}
