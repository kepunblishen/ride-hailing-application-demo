import UIKit

/// Top-down vehicle glyphs for Google Maps `GMSMarker` icons.
///
/// Design notes (ride-hailing pattern — flat marker, nose = north):
/// - Prefer a plan-view silhouette over side-view SF Symbols so `rotation` reads as heading.
/// - White halo + dark body keeps contrast on both light and night map styles.
/// - Assigned driver uses brand amber; nearby fleet uses charcoal.
enum VehicleMapMarkerIcon {
    enum Role {
        case assigned
        case nearby
    }

    /// Brand amber used across Vuum map chrome / polylines.
    private static let brandAmber = UIColor(red: 245 / 255, green: 165 / 255, blue: 36 / 255, alpha: 1)
    private static let charcoal = UIColor(red: 0.18, green: 0.20, blue: 0.23, alpha: 1)
    private static let nearbyBody = UIColor(red: 0.28, green: 0.30, blue: 0.33, alpha: 1)
    private static let glass = UIColor(red: 0.78, green: 0.88, blue: 0.95, alpha: 0.95)
    private static let glassAssigned = UIColor(red: 0.20, green: 0.22, blue: 0.26, alpha: 0.55)

    static func image(
        vehicleClass: VehicleClass,
        role: Role,
        pointSize: CGFloat
    ) -> UIImage {
        let scale = UIScreen.main.scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let canvas = CGSize(width: pointSize, height: pointSize)
        let renderer = UIGraphicsImageRenderer(size: canvas, format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let inset = pointSize * 0.08
            let bounds = CGRect(origin: .zero, size: canvas).insetBy(dx: inset, dy: inset)

            drawSoftShadow(in: bounds, context: cg)

            switch vehicleClass {
            case .bike:
                drawBike(in: bounds, role: role)
            case .large:
                drawVan(in: bounds, role: role)
            case .standard:
                drawSedan(in: bounds, role: role)
            }
        }
    }

    // MARK: - Shared

    private static func bodyColor(for role: Role) -> UIColor {
        role == .assigned ? brandAmber : nearbyBody
    }

    private static func strokeColor(for role: Role) -> UIColor {
        role == .assigned ? charcoal : UIColor.white
    }

    private static func glassColor(for role: Role) -> UIColor {
        role == .assigned ? glassAssigned : glass
    }

    private static func drawSoftShadow(in bounds: CGRect, context: CGContext) {
        let shadow = bounds.insetBy(dx: bounds.width * 0.12, dy: bounds.height * 0.18)
            .offsetBy(dx: 0, dy: bounds.height * 0.06)
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: bounds.height * 0.04),
            blur: bounds.width * 0.12,
            color: UIColor.black.withAlphaComponent(0.35).cgColor
        )
        UIColor.black.withAlphaComponent(0.18).setFill()
        UIBezierPath(ovalIn: shadow).fill()
        context.restoreGState()
    }

    private static func strokeHalo(_ path: UIBezierPath, role: Role, lineWidth: CGFloat) {
        // Outer halo for dark map tiles.
        path.lineWidth = lineWidth + 2.2
        UIColor.white.setStroke()
        path.stroke()
        // Inner edge for light map tiles / brand body.
        path.lineWidth = lineWidth
        strokeColor(for: role).setStroke()
        path.stroke()
    }

    // MARK: - Sedan (top-down, nose at top)

    private static func drawSedan(in bounds: CGRect, role: Role) {
        let w = bounds.width
        let h = bounds.height
        let cx = bounds.midX

        let body = UIBezierPath()
        body.move(to: CGPoint(x: cx, y: bounds.minY + h * 0.06))
        body.addQuadCurve(
            to: CGPoint(x: bounds.minX + w * 0.22, y: bounds.minY + h * 0.22),
            controlPoint: CGPoint(x: bounds.minX + w * 0.28, y: bounds.minY + h * 0.06)
        )
        body.addLine(to: CGPoint(x: bounds.minX + w * 0.18, y: bounds.minY + h * 0.72))
        body.addQuadCurve(
            to: CGPoint(x: bounds.minX + w * 0.30, y: bounds.maxY - h * 0.06),
            controlPoint: CGPoint(x: bounds.minX + w * 0.16, y: bounds.maxY - h * 0.10)
        )
        body.addLine(to: CGPoint(x: bounds.maxX - w * 0.30, y: bounds.maxY - h * 0.06))
        body.addQuadCurve(
            to: CGPoint(x: bounds.maxX - w * 0.18, y: bounds.minY + h * 0.72),
            controlPoint: CGPoint(x: bounds.maxX - w * 0.16, y: bounds.maxY - h * 0.10)
        )
        body.addLine(to: CGPoint(x: bounds.maxX - w * 0.22, y: bounds.minY + h * 0.22))
        body.addQuadCurve(
            to: CGPoint(x: cx, y: bounds.minY + h * 0.06),
            controlPoint: CGPoint(x: bounds.maxX - w * 0.28, y: bounds.minY + h * 0.06)
        )
        body.close()

        bodyColor(for: role).setFill()
        body.fill()
        strokeHalo(body, role: role, lineWidth: max(1.2, w * 0.045))

        // Cabin / windshield (nose-forward).
        let windshield = UIBezierPath(
            roundedRect: CGRect(
                x: bounds.minX + w * 0.30,
                y: bounds.minY + h * 0.24,
                width: w * 0.40,
                height: h * 0.16
            ),
            cornerRadius: w * 0.06
        )
        glassColor(for: role).setFill()
        windshield.fill()

        let rearGlass = UIBezierPath(
            roundedRect: CGRect(
                x: bounds.minX + w * 0.32,
                y: bounds.minY + h * 0.58,
                width: w * 0.36,
                height: h * 0.12
            ),
            cornerRadius: w * 0.05
        )
        glassColor(for: role).withAlphaComponent(0.75).setFill()
        rearGlass.fill()

        drawWheels(
            frontY: bounds.minY + h * 0.30,
            rearY: bounds.minY + h * 0.68,
            leftX: bounds.minX + w * 0.10,
            rightX: bounds.maxX - w * 0.10,
            radius: w * 0.07,
            role: role
        )

        // Direction cue: small nose highlight.
        let nose = UIBezierPath(
            ovalIn: CGRect(
                x: cx - w * 0.05,
                y: bounds.minY + h * 0.10,
                width: w * 0.10,
                height: h * 0.05
            )
        )
        UIColor.white.withAlphaComponent(role == .assigned ? 0.55 : 0.35).setFill()
        nose.fill()
    }

    // MARK: - Van / XL

    private static func drawVan(in bounds: CGRect, role: Role) {
        let w = bounds.width
        let h = bounds.height
        let bodyRect = CGRect(
            x: bounds.minX + w * 0.18,
            y: bounds.minY + h * 0.08,
            width: w * 0.64,
            height: h * 0.84
        )
        let body = UIBezierPath(roundedRect: bodyRect, cornerRadius: w * 0.14)
        bodyColor(for: role).setFill()
        body.fill()
        strokeHalo(body, role: role, lineWidth: max(1.2, w * 0.045))

        let windshield = UIBezierPath(
            roundedRect: CGRect(
                x: bodyRect.minX + bodyRect.width * 0.12,
                y: bodyRect.minY + bodyRect.height * 0.10,
                width: bodyRect.width * 0.76,
                height: bodyRect.height * 0.16
            ),
            cornerRadius: w * 0.05
        )
        glassColor(for: role).setFill()
        windshield.fill()

        // Side window strip.
        let side = UIBezierPath(
            roundedRect: CGRect(
                x: bodyRect.minX + bodyRect.width * 0.14,
                y: bodyRect.minY + bodyRect.height * 0.36,
                width: bodyRect.width * 0.72,
                height: bodyRect.height * 0.28
            ),
            cornerRadius: w * 0.04
        )
        glassColor(for: role).withAlphaComponent(0.65).setFill()
        side.fill()

        drawWheels(
            frontY: bounds.minY + h * 0.28,
            rearY: bounds.minY + h * 0.72,
            leftX: bounds.minX + w * 0.12,
            rightX: bounds.maxX - w * 0.12,
            radius: w * 0.075,
            role: role
        )
    }

    // MARK: - Bike / moto

    private static func drawBike(in bounds: CGRect, role: Role) {
        let w = bounds.width
        let h = bounds.height
        let cx = bounds.midX

        let deck = UIBezierPath(
            roundedRect: CGRect(
                x: cx - w * 0.14,
                y: bounds.minY + h * 0.18,
                width: w * 0.28,
                height: h * 0.56
            ),
            cornerRadius: w * 0.10
        )
        bodyColor(for: role).setFill()
        deck.fill()
        strokeHalo(deck, role: role, lineWidth: max(1.1, w * 0.04))

        // Handlebars.
        let bars = UIBezierPath()
        bars.move(to: CGPoint(x: cx - w * 0.28, y: bounds.minY + h * 0.22))
        bars.addLine(to: CGPoint(x: cx + w * 0.28, y: bounds.minY + h * 0.22))
        bars.lineWidth = max(2, w * 0.07)
        bars.lineCapStyle = .round
        strokeColor(for: role).setStroke()
        bars.stroke()
        bars.lineWidth = max(1.2, w * 0.045)
        UIColor.white.setStroke()
        bars.stroke()

        let wheelR = w * 0.14
        let front = CGPoint(x: cx, y: bounds.minY + h * 0.14)
        let rear = CGPoint(x: cx, y: bounds.maxY - h * 0.14)
        drawWheel(at: front, radius: wheelR, role: role)
        drawWheel(at: rear, radius: wheelR, role: role)

        let seat = UIBezierPath(
            ovalIn: CGRect(
                x: cx - w * 0.10,
                y: bounds.minY + h * 0.42,
                width: w * 0.20,
                height: h * 0.12
            )
        )
        charcoal.withAlphaComponent(0.55).setFill()
        seat.fill()
    }

    // MARK: - Wheels

    private static func drawWheels(
        frontY: CGFloat,
        rearY: CGFloat,
        leftX: CGFloat,
        rightX: CGFloat,
        radius: CGFloat,
        role: Role
    ) {
        for y in [frontY, rearY] {
            drawWheel(at: CGPoint(x: leftX, y: y), radius: radius, role: role)
            drawWheel(at: CGPoint(x: rightX, y: y), radius: radius, role: role)
        }
    }

    private static func drawWheel(at center: CGPoint, radius: CGFloat, role: Role) {
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        let path = UIBezierPath(ovalIn: rect)
        UIColor.black.withAlphaComponent(0.85).setFill()
        path.fill()
        UIColor.white.setStroke()
        path.lineWidth = max(1, radius * 0.35)
        path.stroke()
        if role == .assigned {
            charcoal.setStroke()
            path.lineWidth = max(0.8, radius * 0.22)
            path.stroke()
        }
    }
}
