import SpriteKit

final class TTRHeroPreviewScene: SKScene {
    private let hero = TTRRiggedHeroNode()
    private var configuredSize: CGSize = .zero

    override init(size: CGSize = CGSize(width: 220, height: 240)) {
        super.init(size: size)
        anchorPoint = .zero
        backgroundColor = .clear
        scaleMode = .resizeFill
        addChild(hero)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(size newSize: CGSize) {
        guard newSize.width > 1, newSize.height > 1 else { return }
        if configuredSize == newSize {
            return
        }
        configuredSize = newSize
        size = newSize
        hero.setDisplayHeight(newSize.height * 0.90)
        hero.position = CGPoint(x: newSize.width * 0.50, y: newSize.height * 0.06)
        hero.zPosition = 10
        hero.playIdle()
    }
}
