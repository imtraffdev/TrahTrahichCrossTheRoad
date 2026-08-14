import SpriteKit

final class TTRCrossRoadScene: SKScene {
    var onScoreChanged: ((Int) -> Void)?
    var onCoinEarned: ((Int) -> Void)?
    var onRoadCoinCollected: ((Int) -> Void)?
    var onMoveCompleted: (() -> Void)?
    var onCrossingCompleted: (() -> Void)?
    var onRoadCrash: ((Int) -> Void)?
    var onMiniGameRequested: ((TTRMiniGameKind) -> Void)?

    private enum LaneKind: Equatable {
        case verge
        case sidewalk
        case road
    }

    private struct TTRCar {
        let column: Int
        let node: SKSpriteNode
        let speed: CGFloat
        let direction: CGFloat
    }

    private let world = SKNode()
    private var columnNodes: [Int: SKNode] = [:]
    private var cars: [TTRCar] = []
    private var pickups: [SKSpriteNode] = []
    private var player = TTRRiggedHeroNode()
    private var playerColumn = 1
    private var playerRow = 2
    private var lastCrossingColumn = 1
    private var laneWidth: CGFloat = 72
    private var scrollX: CGFloat = 0
    private var score = 0
    private var isMoving = false
    private var isRoadPaused = false
    private var isCrashing = false
    private var shieldHitsRemaining = 0
    private var barrierNodes: [SKNode] = []
    private var roadTheme = TTRRoadTheme.active
    private var lastSceneSize: CGSize = .zero
    private var safeLandingEvents = 0
    private var lastUpdateTime: TimeInterval = 0
    private var trafficFreezeUntil: TimeInterval = 0

    override init(size: CGSize = CGSize(width: 390, height: 844)) {
        super.init(size: size)
        anchorPoint = .zero
        backgroundColor = SKColor(red: 0.10, green: 0.48, blue: 0.18, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configureScene(size newSize: CGSize) {
        guard newSize.width > 10, newSize.height > 10 else { return }
        if lastSceneSize == newSize, player.parent != nil {
            return
        }
        size = newSize
        lastSceneSize = newSize
        rebuildRoad()
    }

    func stepForward() {
        guard !isMoving, !isRoadPaused, !isCrashing, player.parent != nil else { return }

        let nextColumn = playerColumn + 1
        renderColumns(around: nextColumn)

        isMoving = true
        playerColumn = nextColumn

        let targetX = laneCenter(for: playerColumn)
        let targetScroll = scrollOffset(for: playerColumn)
        let move = SKAction.moveTo(x: targetX, duration: 0.24)
        move.timingMode = .easeOut
        player.playWalkStep(duration: 0.24)

        score += 1
        onScoreChanged?(score)

        scrollX = targetScroll
        let scroll = SKAction.moveTo(x: -targetScroll, duration: 0.24)
        scroll.timingMode = .easeOut
        world.run(scroll, withKey: "ttrWorldScroll")

        player.run(move) { [weak self] in
            guard let self else { return }
            guard !self.isCrashing else { return }
            self.renderVisibleColumns()
            self.collectPickups()
            self.rewardSafeLandingIfNeeded()
            self.onMoveCompleted?()
            self.isMoving = false
            self.checkCollision()
        }
    }

    func moveVertically(_ delta: Int) {
        guard !isMoving, !isRoadPaused, !isCrashing, player.parent != nil else { return }
        let nextRow = max(0, min(trackCount - 1, playerRow + delta))
        guard nextRow != playerRow else { return }

        isMoving = true
        playerRow = nextRow
        player.playWalkStep(duration: 0.18)

        let move = SKAction.moveTo(y: rowY(for: playerRow), duration: 0.18)
        move.timingMode = .easeOut
        player.run(move) { [weak self] in
            guard let self else { return }
            guard !self.isCrashing else { return }
            self.collectPickups()
            self.onMoveCompleted?()
            self.isMoving = false
            self.checkCollision()
        }
    }

    func pauseRoad() {
        isRoadPaused = true
        isPaused = true
    }

    func resumeRoad() {
        isRoadPaused = false
        isPaused = false
    }

    func restartRoad() {
        score = 0
        isMoving = false
        isRoadPaused = false
        isCrashing = false
        shieldHitsRemaining = 0
        safeLandingEvents = 0
        trafficFreezeUntil = 0
        isPaused = false
        rebuildRoad()
    }

    func completeMiniGame(_ kind: TTRMiniGameKind, success: Bool) {
        if success {
            switch kind {
            case .signalHack:
                trafficFreezeUntil = lastUpdateTime + 3.2
                drawMiniGameRewardFlash(kind: kind)
                onCoinEarned?(10)
            case .pressureValve:
                clearTrafficAroundPlayer(xRange: laneWidth * 5.4, yRange: max(laneWidth * 3.3, size.height * 0.48))
                drawHydrantWave()
                onCoinEarned?(14)
            case .manholeShortcut:
                applyDrainShortcut()
                onCoinEarned?(12)
            }
        }

        if !(success && kind == .manholeShortcut) {
            isRoadPaused = false
        }
    }

    func activateBarrierShield() -> Bool {
        guard !isRoadPaused, !isCrashing, player.parent != nil, shieldHitsRemaining == 0 else { return false }
        shieldHitsRemaining = 2
        drawBarrierShield()
        return true
    }

    func activateHydrantFlush() -> Bool {
        guard !isRoadPaused, !isCrashing, player.parent != nil else { return false }

        var cleared = 0
        let xRange = laneWidth * 4.8
        let yRange = max(laneWidth * 2.8, size.height * 0.42)
        for car in cars where car.node.parent != nil && abs(car.node.position.x - player.position.x) <= xRange && abs(car.node.position.y - player.position.y) <= yRange {
            car.node.name = "ttrClearingCar"
            cleared += 1
            let bubble = SKShapeNode(circleOfRadius: max(car.node.size.width, car.node.size.height) * 0.38)
            bubble.position = car.node.position
            bubble.fillColor = SKColor(red: 0.12, green: 0.74, blue: 1.0, alpha: 0.22)
            bubble.strokeColor = SKColor(red: 0.68, green: 0.96, blue: 1.0, alpha: 0.90)
            bubble.lineWidth = 3
            bubble.zPosition = 44
            world.addChild(bubble)
            bubble.run(.sequence([
                .group([.scale(to: 1.7, duration: 0.22), .fadeOut(withDuration: 0.22)]),
                .removeFromParent()
            ]))
            let pushX = car.node.position.x >= player.position.x ? laneWidth * 0.38 : -laneWidth * 0.38
            let pushY = car.node.position.y >= player.position.y ? laneWidth * 0.46 : -laneWidth * 0.46
            car.node.run(.sequence([
                .group([.fadeOut(withDuration: 0.20), .moveBy(x: pushX, y: pushY, duration: 0.20)]),
                .removeFromParent()
            ]))
        }
        cars.removeAll { $0.node.name == "ttrClearingCar" || $0.node.parent == nil }

        drawHydrantWave()
        return cleared > 0
    }

    override func update(_ currentTime: TimeInterval) {
        lastUpdateTime = currentTime
        guard !isRoadPaused else { return }
        guard currentTime >= trafficFreezeUntil else {
            checkCollision()
            return
        }
        for car in cars {
            car.node.position.y += car.speed * car.direction
            if car.node.position.y > size.height + 130 {
                car.node.position.y = -130
            }
            if car.node.position.y < -130 {
                car.node.position.y = size.height + 130
            }
        }
        checkCollision()
    }

    private func rebuildRoad() {
        removeAllChildren()
        world.removeAllChildren()
        world.removeAllActions()
        world.position = .zero
        columnNodes.removeAll()
        cars.removeAll()
        pickups.removeAll()
        barrierNodes.removeAll()
        scrollX = 0
        playerColumn = startColumn()
        playerRow = startRow()
        lastCrossingColumn = playerColumn
        roadTheme = TTRRoadTheme.active
        laneWidth = makeLaneWidth()
        safeLandingEvents = 0
        trafficFreezeUntil = 0

        addChild(world)
        renderVisibleColumns()

        player = TTRRiggedHeroNode()
        let playerHeight = max(76, min(size.height * 0.15, laneWidth * 1.75))
        player.setDisplayHeight(playerHeight)
        player.position = CGPoint(x: laneCenter(for: playerColumn), y: rowY(for: playerRow))
        player.zPosition = 50
        player.xScale = abs(player.xScale)
        world.addChild(player)
    }

    private func makeLaneWidth() -> CGFloat {
        let visibleColumns: CGFloat = size.height > size.width ? 8.0 : 12.0
        return max(48, min(82, size.width / visibleColumns))
    }

    private var trackCount: Int {
        size.height > size.width ? 5 : 4
    }

    private var playfieldBottom: CGFloat {
        size.height > size.width ? max(218, size.height * 0.24) : max(118, size.height * 0.22)
    }

    private var playfieldTop: CGFloat {
        size.height > size.width ? size.height * 0.80 : size.height * 0.78
    }

    private func rowY(for row: Int) -> CGFloat {
        let count = max(trackCount - 1, 1)
        let progress = CGFloat(row) / CGFloat(count)
        return playfieldBottom + (playfieldTop - playfieldBottom) * progress
    }

    private func laneKind(for column: Int) -> LaneKind {
        if column <= 0 {
            return .verge
        }
        if column == 1 {
            return .sidewalk
        }

        let pattern: [LaneKind] = [
            .road, .road, .road, .road,
            .sidewalk, .verge,
            .road, .road, .road,
            .sidewalk,
            .road, .road, .road, .road,
            .verge, .sidewalk
        ]
        return pattern[(column - 2) % pattern.count]
    }

    private func renderVisibleColumns() {
        let firstColumn = Int(floor(scrollX / laneWidth)) - 2
        let lastColumn = Int(ceil((scrollX + size.width) / laneWidth)) + 3
        renderColumns(from: firstColumn, through: lastColumn)
    }

    private func renderColumns(around column: Int) {
        let preload = Int(ceil(size.width / laneWidth)) + 5
        renderColumns(from: column - 3, through: column + preload)
    }

    private func renderColumns(from firstColumn: Int, through lastColumn: Int) {
        guard firstColumn <= lastColumn else { return }

        for column in firstColumn...lastColumn where columnNodes[column] == nil {
            addColumn(column)
        }

        let keepFirst = firstColumn - 4
        let keepLast = lastColumn + 4
        for (column, node) in columnNodes where column < keepFirst || column > keepLast {
            node.removeFromParent()
            columnNodes.removeValue(forKey: column)
        }
        cars.removeAll { $0.node.parent == nil }
        pickups.removeAll { $0.parent == nil }
    }

    private func addColumn(_ column: Int) {
        let kind = laneKind(for: column)
        let node = SKNode()
        node.zPosition = 0
        world.addChild(node)
        columnNodes[column] = node

        drawLane(kind: kind, column: column, parent: node)

        if kind == .road {
            if laneKind(for: column - 1) == .road {
                addDashedRoadLine(x: CGFloat(column) * laneWidth, parent: node)
            }
            addRoadDetails(column: column, parent: node)
            addTraffic(column: column, parent: node)
            addPickupIfNeeded(column: column, parent: node)
        } else if kind == .sidewalk {
            addSidewalkDetails(column: column, parent: node)
        }
    }

    private func drawLane(kind: LaneKind, column: Int, parent: SKNode) {
        let center = CGPoint(x: laneCenter(for: column), y: size.height / 2)
        let lane = SKShapeNode(rectOf: CGSize(width: laneWidth + 2, height: size.height + 6))
        lane.position = center
        lane.strokeColor = .clear
        lane.zPosition = 0

        switch kind {
        case .road:
            lane.fillColor = roadColor
            parent.addChild(lane)
            addRoadGrain(column: column, parent: parent)
        case .sidewalk:
            lane.fillColor = sidewalkColor
            parent.addChild(lane)
            addSidewalkPanelLines(column: column, parent: parent)
        case .verge:
            lane.fillColor = grassColor
            parent.addChild(lane)
            addGrassDetails(column: column, parent: parent)
        }
    }

    private func addRoadGrain(column: Int, parent: SKNode) {
        for index in 0..<10 {
            let seed = seeded(column, index)
            let fleck = SKShapeNode(circleOfRadius: 0.8 + CGFloat(seed % 4) * 0.25)
            fleck.fillColor = roadFleckColor
            fleck.strokeColor = .clear
            fleck.position = CGPoint(
                x: laneCenter(for: column) + seededOffset(column, index, amplitude: laneWidth * 0.34),
                y: CGFloat((seed * 47) % Int(max(size.height, 1)))
            )
            fleck.zPosition = 1
            parent.addChild(fleck)
        }
    }

    private func addGrassDetails(column: Int, parent: SKNode) {
        for index in 0..<26 {
            let seed = seeded(column, index)
            let blade = SKShapeNode(rectOf: CGSize(width: 1.2, height: 5 + CGFloat(seed % 6)), cornerRadius: 0.6)
            blade.fillColor = grassBladeColor
            blade.strokeColor = .clear
            blade.zRotation = CGFloat((seed % 7) - 3) * 0.16
            blade.position = CGPoint(
                x: laneCenter(for: column) + seededOffset(column, index, amplitude: laneWidth * 0.42),
                y: CGFloat((seed * 71) % Int(max(size.height, 1)))
            )
            blade.zPosition = 1
            parent.addChild(blade)
        }

        for index in 0..<4 where (column + index).isMultiple(of: 2) {
            addBushCluster(
                x: laneCenter(for: column) + CGFloat(index.isMultiple(of: 2) ? -1 : 1) * laneWidth * 0.20,
                y: size.height * CGFloat([0.16, 0.36, 0.67, 0.88][index]),
                scale: laneWidth / 72,
                parent: parent
            )
        }
    }

    private func addBushCluster(x: CGFloat, y: CGFloat, scale: CGFloat, parent: SKNode) {
        let cluster = SKNode()
        cluster.position = CGPoint(x: x, y: y)
        cluster.zPosition = 3
        parent.addChild(cluster)

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 46 * scale, height: 18 * scale))
        shadow.fillColor = SKColor(red: 0.02, green: 0.18, blue: 0.10, alpha: 0.20)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2 * scale, y: -8 * scale)
        cluster.addChild(shadow)

        let leaves = bushPalette
        for leaf in leaves {
            let circle = SKShapeNode(circleOfRadius: leaf.2 * scale)
            circle.fillColor = leaf.3
            circle.strokeColor = SKColor(red: 0.0, green: 0.28, blue: 0.13, alpha: 0.38)
            circle.lineWidth = max(0.8, 1.5 * scale)
            circle.position = CGPoint(x: leaf.0 * scale, y: leaf.1 * scale)
            cluster.addChild(circle)
        }

        for dot in 0..<3 {
            let flower = SKShapeNode(circleOfRadius: 2.4 * scale)
            flower.fillColor = dot == 1 ? SKColor(red: 1.0, green: 0.82, blue: 0.18, alpha: 1) : SKColor(red: 1.0, green: 0.36, blue: 0.28, alpha: 1)
            flower.strokeColor = .clear
            flower.position = CGPoint(x: CGFloat(dot * 7 - 7) * scale, y: CGFloat(dot % 2 == 0 ? 5 : -2) * scale)
            cluster.addChild(flower)
        }
    }

    private func addSidewalkPanelLines(column: Int, parent: SKNode) {
        let x = laneCenter(for: column)
        let vertical = SKShapeNode(rectOf: CGSize(width: 1.4, height: size.height + 6))
        vertical.fillColor = sidewalkLineColor
        vertical.strokeColor = .clear
        vertical.position = CGPoint(x: x + laneWidth * 0.30, y: size.height / 2)
        vertical.zPosition = 1
        parent.addChild(vertical)

        var y = CGFloat((column * 31) % 70)
        while y < size.height + 30 {
            let line = SKShapeNode(rectOf: CGSize(width: laneWidth + 2, height: 1.4))
            line.fillColor = sidewalkLineColor
            line.strokeColor = .clear
            line.position = CGPoint(x: x, y: y)
            line.zPosition = 1
            parent.addChild(line)
            y += laneWidth * 1.22
        }
    }

    private func addDashedRoadLine(x: CGFloat, parent: SKNode) {
        let dashHeight = min(max(size.height * 0.048, 32), 58)
        let gap = dashHeight * 1.40
        let lineWidth = max(4.0, min(laneWidth * 0.075, 7.0))
        var y = -dashHeight

        while y < size.height + dashHeight {
            let dash = SKShapeNode(rectOf: CGSize(width: lineWidth, height: dashHeight), cornerRadius: lineWidth / 2)
            dash.fillColor = SKColor.white.withAlphaComponent(0.93)
            dash.strokeColor = .clear
            dash.position = CGPoint(x: x, y: y)
            dash.zPosition = 4
            parent.addChild(dash)
            y += dashHeight + gap
        }
    }

    private func addRoadDetails(column: Int, parent: SKNode) {
        if column > startColumn() + 4 {
            if column % 17 == 6 {
                addMiniGameRoadMarker(imageName: "ttrSignalConsole", column: column, yRatio: 0.20, parent: parent)
            } else if column % 19 == 8 {
                addMiniGameRoadMarker(imageName: "ttrPressureValve", column: column, yRatio: 0.82, parent: parent)
            } else if column % 23 == 11 {
                addMiniGameRoadMarker(imageName: "ttrPortalManhole", column: column, yRatio: 0.50, parent: parent)
            }
        }

        guard column % 5 == 0 else { return }
        let manhole = SKSpriteNode(imageNamed: "ttrBlueManhole")
        let side = min(laneWidth * 0.70, 78)
        manhole.size = CGSize(width: side, height: side)
        manhole.position = CGPoint(x: laneCenter(for: column), y: size.height * (column.isMultiple(of: 2) ? 0.30 : 0.72))
        manhole.zPosition = 5
        parent.addChild(manhole)
    }

    private func addMiniGameRoadMarker(imageName: String, column: Int, yRatio: CGFloat, parent: SKNode) {
        let marker = SKSpriteNode(imageNamed: imageName)
        let side = min(laneWidth * 0.58, 52)
        marker.size = CGSize(width: side, height: side)
        marker.position = CGPoint(x: laneCenter(for: column), y: size.height * yRatio)
        marker.zPosition = 6
        marker.alpha = 0.76
        parent.addChild(marker)
    }

    private func addSidewalkDetails(column: Int, parent: SKNode) {
        guard column > startColumn(), column % 6 == 1 else { return }
        let hydrant = SKSpriteNode(imageNamed: "ttrHydrantRed")
        hydrant.size = CGSize(width: min(laneWidth * 0.58, 54), height: min(laneWidth * 0.88, 82))
        hydrant.position = CGPoint(x: laneCenter(for: column), y: size.height * 0.24)
        hydrant.zPosition = 8
        parent.addChild(hydrant)
    }

    private func addTraffic(column: Int, parent: SKNode) {
        let choices = ["ttrGreenCar", "ttrTaxiCar", "ttrVioletCar"]
        let direction: CGFloat = column.isMultiple(of: 2) ? 1 : -1
        let speedBoost = min(CGFloat(max(playerColumn - 1, 0)) * 0.012, 1.35)
        let baseSpeed = CGFloat(2.35 + Double(column % 4) * 0.48) + speedBoost
        let carCount = size.height > size.width ? 1 : 2

        for offset in 0..<carCount {
            let textureName = choices[(column + offset) % choices.count]
            let car = SKSpriteNode(imageNamed: textureName)
            car.size = CGSize(width: min(laneWidth * 0.64, 64), height: min(laneWidth * 1.03, 98))
            let spacing = size.height / CGFloat(max(carCount, 1))
            car.position = CGPoint(
                x: laneCenter(for: column),
                y: CGFloat(offset) * spacing + CGFloat((column * 53 + offset * 97) % 180) - 60
            )
            car.zPosition = 20
            if direction < 0 {
                car.zRotation = .pi
            }
            parent.addChild(car)
            cars.append(TTRCar(column: column, node: car, speed: baseSpeed, direction: direction))
        }
    }

    private func addPickupIfNeeded(column: Int, parent: SKNode) {
        guard (column * 17 + 11) % 4 != 0 else { return }
        let coin = SKSpriteNode(imageNamed: "ttrRoadCoin")
        let side = min(laneWidth * 0.54, 44)
        let visibleRows = max(trackCount - 1, 1)
        let targetRow = seeded(column, 41) % visibleRows
        coin.size = CGSize(width: side, height: side)
        coin.position = CGPoint(
            x: laneCenter(for: column),
            y: rowY(for: targetRow)
        )
        coin.zPosition = 18
        coin.name = "ttrRoadCoin"
        parent.addChild(coin)

        let lift = SKAction.moveBy(x: 0, y: 4, duration: 0.62)
        let drop = SKAction.moveBy(x: 0, y: -4, duration: 0.62)
        let pulse = SKAction.sequence([.scale(to: 1.08, duration: 0.38), .scale(to: 1.0, duration: 0.38)])
        coin.run(.repeatForever(.sequence([lift, drop])), withKey: "ttrCoinFloat")
        coin.run(.repeatForever(pulse), withKey: "ttrCoinPulse")
        pickups.append(coin)
    }

    private func collectPickups() {
        let playerBox = playerHitBox()
        for coin in pickups where coin.parent != nil {
            let coinBox = centeredRect(
                at: coin.position,
                width: coin.size.width * 1.10,
                height: coin.size.height * 1.10
            )
            guard playerBox.intersects(coinBox) else { continue }
            coin.removeAllActions()
            coin.run(.sequence([
                .group([
                    .scale(to: 1.70, duration: 0.14),
                    .fadeOut(withDuration: 0.14),
                    .moveBy(x: 0, y: 18, duration: 0.14)
                ]),
                .removeFromParent()
            ]))
            onCoinEarned?(3)
            onRoadCoinCollected?(1)
        }
        pickups.removeAll { $0.parent == nil }
    }

    private func rewardSafeLandingIfNeeded() {
        guard laneKind(for: playerColumn) != .road, playerColumn > lastCrossingColumn else { return }
        lastCrossingColumn = playerColumn
        safeLandingEvents += 1
        score += 5
        onScoreChanged?(score)
        onCoinEarned?(8)
        onCrossingCompleted?()

        let flash = SKShapeNode(rectOf: CGSize(width: laneWidth * 1.1, height: size.height + 4))
        flash.fillColor = SKColor(red: 0.0, green: 0.68, blue: 1.0, alpha: 0.14)
        flash.strokeColor = .clear
        flash.position = CGPoint(x: laneCenter(for: playerColumn), y: size.height / 2)
        flash.zPosition = 12
        world.addChild(flash)
        flash.run(SKAction.sequence([.fadeOut(withDuration: 0.30), .removeFromParent()]))

        requestMiniGameAfterLandingIfNeeded()
    }

    private func requestMiniGameAfterLandingIfNeeded() {
        guard safeLandingEvents >= 2, safeLandingEvents.isMultiple(of: 2), !isCrashing else { return }
        let order: [TTRMiniGameKind] = [.signalHack, .pressureValve, .manholeShortcut]
        let kind = order[((safeLandingEvents / 2) - 1) % order.count]
        drawMiniGameMarker(kind: kind)
        isRoadPaused = true
        onMiniGameRequested?(kind)
    }

    private func drawMiniGameMarker(kind: TTRMiniGameKind) {
        let marker = SKSpriteNode(imageNamed: kind.imageName)
        marker.size = CGSize(width: min(laneWidth * 1.08, 82), height: min(laneWidth * 1.08, 82))
        marker.position = CGPoint(
            x: player.position.x + laneWidth * 0.18,
            y: min(size.height - marker.size.height * 0.70, player.position.y + player.displaySize.height * 1.05)
        )
        marker.zPosition = 65
        marker.setScale(0.25)
        marker.alpha = 0
        world.addChild(marker)
        marker.run(.sequence([
            .group([.fadeIn(withDuration: 0.10), .scale(to: 1.0, duration: 0.18)]),
            .wait(forDuration: 0.82),
            .group([.fadeOut(withDuration: 0.18), .scale(to: 0.72, duration: 0.18)]),
            .removeFromParent()
        ]))
    }

    private func checkCollision() {
        guard !isRoadPaused, !isCrashing, player.parent != nil else { return }
        let playerBox = playerHitBox()
        for car in cars where abs(car.node.position.x - player.position.x) < laneWidth * 0.58 {
            let carBox = centeredRect(
                at: car.node.position,
                width: car.node.size.width * 0.74,
                height: car.node.size.height * 0.78
            )
            if shieldHitsRemaining > 0, barrierHitBoxes().contains(where: { $0.intersects(carBox) }) {
                absorbCrash(with: car.node)
                return
            }
            if playerBox.intersects(carBox) {
                if shieldHitsRemaining > 0 {
                    absorbCrash(with: car.node)
                    return
                }
                startCrashSequence()
                return
            }
        }
    }

    private func startCrashSequence() {
        isCrashing = true
        isRoadPaused = true
        player.removeAllActions()

        let spark = SKShapeNode(circleOfRadius: max(player.displaySize.width, player.displaySize.height) * 0.42)
        spark.position = player.position
        spark.fillColor = SKColor(red: 0.0, green: 0.68, blue: 1.0, alpha: 0.20)
        spark.strokeColor = SKColor(red: 1.0, green: 0.83, blue: 0.12, alpha: 0.95)
        spark.lineWidth = 5
        spark.zPosition = 49
        world.addChild(spark)
        spark.run(.sequence([
            .group([.scale(to: 1.55, duration: 0.32), .fadeOut(withDuration: 0.32)]),
            .removeFromParent()
        ]))

        player.flashHit()
        player.playDeath(duration: 0.72) { [weak self] in
            guard let self else { return }
            self.onRoadCrash?(self.score)
        }
    }

    private func scrollOffset(for column: Int) -> CGFloat {
        let playerX = laneCenter(for: column)
        let anchor = size.width * (size.height > size.width ? 0.30 : 0.34)
        return max(0, playerX - anchor)
    }

    private func laneCenter(for column: Int) -> CGFloat {
        CGFloat(column) * laneWidth + laneWidth / 2
    }

    private func startColumn() -> Int {
        1
    }

    private func startRow() -> Int {
        trackCount / 2
    }

    private func playerHitBox() -> CGRect {
        centeredRect(
            at: CGPoint(
                x: player.position.x,
                y: player.position.y + player.displaySize.height * 0.38
            ),
            width: player.displaySize.width * 0.50,
            height: player.displaySize.height * 0.64
        )
    }

    private func centeredRect(at point: CGPoint, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(
            x: point.x - width / 2,
            y: point.y - height / 2,
            width: width,
            height: height
        )
    }

    private func drawBarrierShield() {
        barrierNodes.forEach { $0.removeFromParent() }
        barrierNodes.removeAll()

        for side in [-1.0, 1.0] {
            let barrier = makeRoadBarrierNode(width: player.displaySize.width * 1.30)
            barrier.position = CGPoint(
                x: 0,
                y: CGFloat(side > 0 ? player.displaySize.height * 1.18 : -player.displaySize.height * 0.18)
            )
            barrier.zPosition = 3
            player.addChild(barrier)
            barrier.run(.repeatForever(.sequence([
                .scaleX(to: 1.035, duration: 0.38),
                .scaleX(to: 1.0, duration: 0.38)
            ])))
            barrierNodes.append(barrier)
        }
    }

    private func clearTrafficAroundPlayer(xRange: CGFloat, yRange: CGFloat) {
        for car in cars where car.node.parent != nil && abs(car.node.position.x - player.position.x) <= xRange && abs(car.node.position.y - player.position.y) <= yRange {
            car.node.name = "ttrClearingCar"
            let bubble = SKShapeNode(circleOfRadius: max(car.node.size.width, car.node.size.height) * 0.38)
            bubble.position = car.node.position
            bubble.fillColor = SKColor(red: 0.12, green: 0.74, blue: 1.0, alpha: 0.22)
            bubble.strokeColor = SKColor(red: 0.68, green: 0.96, blue: 1.0, alpha: 0.90)
            bubble.lineWidth = 3
            bubble.zPosition = 44
            world.addChild(bubble)
            bubble.run(.sequence([
                .group([.scale(to: 1.7, duration: 0.22), .fadeOut(withDuration: 0.22)]),
                .removeFromParent()
            ]))

            let pushX = car.node.position.x >= player.position.x ? laneWidth * 0.42 : -laneWidth * 0.42
            let pushY = car.node.position.y >= player.position.y ? laneWidth * 0.52 : -laneWidth * 0.52
            car.node.run(.sequence([
                .group([.fadeOut(withDuration: 0.20), .moveBy(x: pushX, y: pushY, duration: 0.20)]),
                .removeFromParent()
            ]))
        }
        cars.removeAll { $0.node.name == "ttrClearingCar" || $0.node.parent == nil }
    }

    private func drawMiniGameRewardFlash(kind: TTRMiniGameKind) {
        let icon = SKSpriteNode(imageNamed: kind.imageName)
        icon.size = CGSize(width: min(laneWidth * 1.25, 94), height: min(laneWidth * 1.25, 94))
        icon.position = CGPoint(x: player.position.x, y: player.position.y + player.displaySize.height * 0.76)
        icon.zPosition = 64
        icon.setScale(0.35)
        icon.alpha = 0
        world.addChild(icon)
        icon.run(.sequence([
            .group([.fadeIn(withDuration: 0.10), .scale(to: 1.0, duration: 0.16)]),
            .wait(forDuration: 0.64),
            .group([.fadeOut(withDuration: 0.22), .moveBy(x: 0, y: laneWidth * 0.22, duration: 0.22)]),
            .removeFromParent()
        ]))

        let ring = SKShapeNode(circleOfRadius: laneWidth * 1.45)
        ring.position = player.position
        ring.strokeColor = SKColor(red: 0.10, green: 0.82, blue: 1.0, alpha: 0.90)
        ring.fillColor = SKColor(red: 0.10, green: 0.82, blue: 1.0, alpha: 0.12)
        ring.lineWidth = 4
        ring.zPosition = 45
        world.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 1.75, duration: 0.34), .fadeOut(withDuration: 0.34)]),
            .removeFromParent()
        ]))
    }

    private func applyDrainShortcut() {
        guard !isMoving else {
            isRoadPaused = false
            return
        }

        let origin = player.position
        let maxTargetColumn = playerColumn + 8
        var targetColumn = playerColumn + 2
        while targetColumn <= maxTargetColumn, laneKind(for: targetColumn) == .road {
            targetColumn += 1
        }
        if targetColumn > maxTargetColumn {
            targetColumn = playerColumn + 3
        }

        renderColumns(around: targetColumn)
        isMoving = true
        let skippedColumns = max(2, targetColumn - playerColumn)
        playerColumn = targetColumn
        score += skippedColumns
        onScoreChanged?(score)

        let targetPoint = CGPoint(x: laneCenter(for: playerColumn), y: player.position.y)
        let targetScroll = scrollOffset(for: playerColumn)
        scrollX = targetScroll

        drawPortalBurst(at: origin)
        drawPortalBurst(at: targetPoint)

        player.alpha = 0.26
        let move = SKAction.move(to: targetPoint, duration: 0.34)
        move.timingMode = .easeInEaseOut
        let scroll = SKAction.moveTo(x: -targetScroll, duration: 0.34)
        scroll.timingMode = .easeInEaseOut
        world.run(scroll, withKey: "ttrDrainShortcutScroll")

        player.run(.sequence([
            move,
            .fadeAlpha(to: 1.0, duration: 0.10)
        ])) { [weak self] in
            guard let self else { return }
            self.renderVisibleColumns()
            self.collectPickups()
            self.lastCrossingColumn = max(self.lastCrossingColumn, self.playerColumn)
            self.isMoving = false
            self.isRoadPaused = false
            self.checkCollision()
        }
    }

    private func drawPortalBurst(at point: CGPoint) {
        let portal = SKSpriteNode(imageNamed: "ttrPortalManhole")
        portal.size = CGSize(width: laneWidth * 1.25, height: laneWidth * 1.25)
        portal.position = point
        portal.zPosition = 42
        portal.setScale(0.20)
        portal.alpha = 0
        world.addChild(portal)
        portal.run(.sequence([
            .group([.fadeIn(withDuration: 0.08), .scale(to: 1.0, duration: 0.12)]),
            .wait(forDuration: 0.28),
            .group([.fadeOut(withDuration: 0.22), .scale(to: 1.35, duration: 0.22)]),
            .removeFromParent()
        ]))
    }

    private func makeRoadBarrierNode(width: CGFloat) -> SKNode {
        let barrier = SKSpriteNode(imageNamed: "ttrBarrier")
        barrier.size = CGSize(width: width, height: width * 0.38)
        barrier.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        return barrier
    }

    private func absorbCrash(with car: SKSpriteNode) {
        shieldHitsRemaining -= 1
        let spark = SKShapeNode(circleOfRadius: max(car.size.width, car.size.height) * 0.42)
        spark.position = car.position
        spark.fillColor = SKColor(red: 0.0, green: 0.60, blue: 1.0, alpha: 0.26)
        spark.strokeColor = SKColor(red: 1.0, green: 0.85, blue: 0.15, alpha: 1.0)
        spark.lineWidth = 4
        spark.zPosition = 55
        world.addChild(spark)
        spark.run(.sequence([
            .group([.scale(to: 1.75, duration: 0.22), .fadeOut(withDuration: 0.22)]),
            .removeFromParent()
        ]))

        car.name = "ttrShieldedCar"
        car.run(.sequence([
            .group([.fadeOut(withDuration: 0.16), .scale(to: 0.25, duration: 0.16)]),
            .removeFromParent()
        ]))
        cars.removeAll { $0.node.name == "ttrShieldedCar" || $0.node.parent == nil }

        if shieldHitsRemaining <= 0 {
            barrierNodes.forEach { node in
                node.removeAllActions()
                node.run(.sequence([.fadeOut(withDuration: 0.16), .removeFromParent()]))
            }
            barrierNodes.removeAll()
        }
    }

    private func drawHydrantWave() {
        let origin = CGPoint(
            x: player.position.x - player.displaySize.width * 0.62,
            y: player.position.y + player.displaySize.height * 0.24
        )
        let hydrant = SKSpriteNode(imageNamed: "ttrHydrantRed")
        hydrant.size = CGSize(width: laneWidth * 0.92, height: laneWidth * 0.92)
        hydrant.position = origin
        hydrant.zPosition = 58
        hydrant.setScale(0.20)
        hydrant.alpha = 0
        world.addChild(hydrant)
        hydrant.run(.sequence([
            .group([.fadeIn(withDuration: 0.08), .scale(to: 1.0, duration: 0.12)]),
            .wait(forDuration: 0.92),
            .group([.fadeOut(withDuration: 0.22), .scale(to: 0.82, duration: 0.22)]),
            .removeFromParent()
        ]))

        let jetAngles: [CGFloat] = [0, .pi / 4, .pi / 2, .pi * 3 / 4, .pi, .pi * 5 / 4, .pi * 3 / 2, .pi * 7 / 4]
        for (index, angle) in jetAngles.enumerated() {
            let length = laneWidth * CGFloat(index.isMultiple(of: 2) ? 3.0 : 2.15)
            let center = CGPoint(
                x: origin.x + cos(angle) * length * 0.50,
                y: origin.y + sin(angle) * length * 0.50
            )
            let jet = SKShapeNode(rectOf: CGSize(width: length, height: max(8, laneWidth * 0.12)), cornerRadius: max(4, laneWidth * 0.06))
            jet.position = center
            jet.zRotation = angle
            jet.fillColor = SKColor(red: 0.55, green: 0.92, blue: 1.0, alpha: 0.72)
            jet.strokeColor = SKColor.white.withAlphaComponent(0.82)
            jet.lineWidth = 1.8
            jet.zPosition = 54
            jet.xScale = 0.12
            world.addChild(jet)
            jet.run(.sequence([
                .group([.scaleX(to: 1.0, duration: 0.14), .fadeAlpha(to: 0.86, duration: 0.14)]),
                .wait(forDuration: 0.18),
                .group([.scaleX(to: 1.12, duration: 0.34), .fadeOut(withDuration: 0.34)]),
                .removeFromParent()
            ]))

            let splash = SKShapeNode(circleOfRadius: max(7, laneWidth * 0.12))
            splash.position = CGPoint(x: origin.x + cos(angle) * length, y: origin.y + sin(angle) * length)
            splash.fillColor = SKColor(red: 0.62, green: 0.94, blue: 1.0, alpha: 0.44)
            splash.strokeColor = SKColor.white.withAlphaComponent(0.72)
            splash.lineWidth = 2
            splash.zPosition = 55
            splash.setScale(0.35)
            world.addChild(splash)
            splash.run(.sequence([
                .group([.scale(to: 1.55, duration: 0.38), .fadeOut(withDuration: 0.38)]),
                .removeFromParent()
            ]))
        }
    }

    private func barrierHitBoxes() -> [CGRect] {
        [
            centeredRect(
                at: CGPoint(x: player.position.x, y: player.position.y + player.displaySize.height * 1.16),
                width: player.displaySize.width * 1.40,
                height: player.displaySize.height * 0.24
            ),
            centeredRect(
                at: CGPoint(x: player.position.x, y: player.position.y - player.displaySize.height * 0.15),
                width: player.displaySize.width * 1.40,
                height: player.displaySize.height * 0.24
            )
        ]
    }

    private var roadColor: SKColor {
        switch roadTheme {
        case .midnight: SKColor(red: 0.04, green: 0.06, blue: 0.075, alpha: 1)
        case .meadow: SKColor(red: 0.13, green: 0.15, blue: 0.13, alpha: 1)
        case .sunset: SKColor(red: 0.18, green: 0.10, blue: 0.13, alpha: 1)
        }
    }

    private var roadFleckColor: SKColor {
        switch roadTheme {
        case .midnight: SKColor(red: 0.18, green: 0.23, blue: 0.25, alpha: 0.22)
        case .meadow: SKColor(red: 0.34, green: 0.40, blue: 0.34, alpha: 0.20)
        case .sunset: SKColor(red: 0.42, green: 0.20, blue: 0.24, alpha: 0.20)
        }
    }

    private var grassColor: SKColor {
        switch roadTheme {
        case .midnight: SKColor(red: 0.17, green: 0.70, blue: 0.23, alpha: 1)
        case .meadow: SKColor(red: 0.36, green: 0.78, blue: 0.20, alpha: 1)
        case .sunset: SKColor(red: 0.52, green: 0.62, blue: 0.19, alpha: 1)
        }
    }

    private var grassBladeColor: SKColor {
        switch roadTheme {
        case .midnight: SKColor(red: 0.42, green: 0.88, blue: 0.26, alpha: 0.34)
        case .meadow: SKColor(red: 0.70, green: 0.96, blue: 0.24, alpha: 0.36)
        case .sunset: SKColor(red: 0.92, green: 0.74, blue: 0.26, alpha: 0.32)
        }
    }

    private var sidewalkColor: SKColor {
        switch roadTheme {
        case .midnight: SKColor(red: 0.62, green: 0.70, blue: 0.75, alpha: 1)
        case .meadow: SKColor(red: 0.66, green: 0.73, blue: 0.66, alpha: 1)
        case .sunset: SKColor(red: 0.72, green: 0.58, blue: 0.50, alpha: 1)
        }
    }

    private var sidewalkLineColor: SKColor {
        switch roadTheme {
        case .midnight: SKColor(red: 0.39, green: 0.47, blue: 0.52, alpha: 0.55)
        case .meadow: SKColor(red: 0.42, green: 0.51, blue: 0.42, alpha: 0.55)
        case .sunset: SKColor(red: 0.46, green: 0.34, blue: 0.31, alpha: 0.50)
        }
    }

    private var bushPalette: [(CGFloat, CGFloat, CGFloat, SKColor)] {
        switch roadTheme {
        case .midnight:
            [
                (-14, -2, 13, SKColor(red: 0.04, green: 0.48, blue: 0.22, alpha: 1)),
                (0, 3, 16, SKColor(red: 0.08, green: 0.64, blue: 0.30, alpha: 1)),
                (15, -1, 12, SKColor(red: 0.17, green: 0.76, blue: 0.38, alpha: 1)),
                (-2, -10, 14, SKColor(red: 0.06, green: 0.56, blue: 0.25, alpha: 1))
            ]
        case .meadow:
            [
                (-14, -2, 13, SKColor(red: 0.22, green: 0.56, blue: 0.16, alpha: 1)),
                (0, 3, 16, SKColor(red: 0.38, green: 0.74, blue: 0.22, alpha: 1)),
                (15, -1, 12, SKColor(red: 0.54, green: 0.86, blue: 0.32, alpha: 1)),
                (-2, -10, 14, SKColor(red: 0.28, green: 0.64, blue: 0.18, alpha: 1))
            ]
        case .sunset:
            [
                (-14, -2, 13, SKColor(red: 0.42, green: 0.48, blue: 0.20, alpha: 1)),
                (0, 3, 16, SKColor(red: 0.58, green: 0.60, blue: 0.22, alpha: 1)),
                (15, -1, 12, SKColor(red: 0.76, green: 0.62, blue: 0.25, alpha: 1)),
                (-2, -10, 14, SKColor(red: 0.50, green: 0.52, blue: 0.18, alpha: 1))
            ]
        }
    }

    private func seeded(_ column: Int, _ index: Int) -> Int {
        abs((column &* 73856093) ^ (index &* 19349663))
    }

    private func seededOffset(_ column: Int, _ index: Int, amplitude: CGFloat) -> CGFloat {
        let seed = seeded(column, index) % 2000
        return (CGFloat(seed) / 1000.0 - 1.0) * amplitude
    }
}
