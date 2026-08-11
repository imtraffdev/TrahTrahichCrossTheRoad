import SpriteKit

final class TTRRiggedHeroNode: SKNode {
    private struct PartSpec {
        let bone: String
        let image: String
        let offsetX: CGFloat
        let offsetY: CGFloat
        let width: CGFloat
        let height: CGFloat
        let z: CGFloat
    }

    private struct BoneSpec {
        let name: String
        let parent: String?
        let x: CGFloat
        let y: CGFloat
    }

    private let groundY: CGFloat = 1454
    private let centerX: CGFloat = 432
    private let sourceHeight: CGFloat = 1454
    private let content = SKNode()
    private var bones: [String: SKNode] = [:]
    private var basePositions: [String: CGPoint] = [:]
    private var parts: [String: SKSpriteNode] = [:]
    private(set) var displaySize = CGSize(width: 74, height: 120)

    private let boneSpecs: [BoneSpec] = [
        BoneSpec(name: "root", parent: nil, x: 0, y: 0),
        BoneSpec(name: "hip", parent: "root", x: 500, y: 705),
        BoneSpec(name: "torso", parent: "hip", x: 0, y: -245),
        BoneSpec(name: "head", parent: "torso", x: 15, y: -285),
        BoneSpec(name: "arm_left", parent: "torso", x: -120, y: -135),
        BoneSpec(name: "arm_right", parent: "torso", x: 215, y: -110),
        BoneSpec(name: "leg_left_upper", parent: "hip", x: -125, y: 80),
        BoneSpec(name: "leg_left_lower", parent: "leg_left_upper", x: -40, y: 270),
        BoneSpec(name: "leg_right_upper", parent: "hip", x: 120, y: 80),
        BoneSpec(name: "leg_right_lower", parent: "leg_right_upper", x: 80, y: 280)
    ]

    private let specs: [PartSpec] = [
        PartSpec(bone: "leg_right_lower", image: "ttrRigLegRightLower", offsetX: -125, offsetY: -61, width: 284, height: 422, z: 0),
        PartSpec(bone: "leg_right_upper", image: "ttrRigThighRight", offsetX: -352, offsetY: -69, width: 456, height: 592, z: 1),
        PartSpec(bone: "leg_left_lower", image: "ttrRigLegLeftLower", offsetX: -115, offsetY: -40, width: 204, height: 434, z: 2),
        PartSpec(bone: "leg_left_upper", image: "ttrRigThighLeft", offsetX: -41, offsetY: -96, width: 375, height: 507, z: 3),
        PartSpec(bone: "hip", image: "ttrRigShorts", offsetX: -214, offsetY: -101, width: 405, height: 495, z: 4),
        PartSpec(bone: "arm_right", image: "ttrRigArmRight", offsetX: -124, offsetY: -32, width: 255, height: 414, z: 5),
        PartSpec(bone: "torso", image: "ttrRigTorso", offsetX: -211, offsetY: -211, width: 422, height: 1174, z: 6),
        PartSpec(bone: "head", image: "ttrRigHead", offsetX: -93, offsetY: -120, width: 185, height: 281, z: 7),
        PartSpec(bone: "arm_left", image: "ttrRigArmLeft", offsetX: -237, offsetY: -29, width: 560, height: 704, z: 8)
    ]

    override init() {
        super.init()
        addChild(content)
        buildParts()
        playIdle()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setDisplayHeight(_ height: CGFloat) {
        let scale = height / sourceHeight
        content.setScale(scale)
        displaySize = CGSize(width: height * 0.70, height: height)
    }

    func playIdle() {
        resetPose()
        runLoop(on: "torso", key: "ttrRigIdleTorso", angles: [0, -1.4, 0], step: 0.72)
        runLoop(on: "head", key: "ttrRigIdleHead", angles: [0, 1.8, 0], step: 0.72)
        runLoop(on: "arm_left", key: "ttrRigIdleArmLeft", angles: [0, -2.0, 0], step: 0.72)
        runLoop(on: "arm_right", key: "ttrRigIdleArmRight", angles: [0, 1.6, 0], step: 0.72)
    }

    func playWalkStep(duration: TimeInterval) {
        removeAction(forKey: "ttrRigReturnIdle")
        removeBoneActions()
        animate(on: "leg_left_upper", key: "ttrRigWalkLLU", angles: [6, -13, 7], duration: duration)
        animate(on: "leg_left_lower", key: "ttrRigWalkLLL", angles: [-2, 8, -8], duration: duration)
        animate(on: "leg_right_upper", key: "ttrRigWalkLRU", angles: [-7, 16, -6], duration: duration)
        animate(on: "leg_right_lower", key: "ttrRigWalkLRL", angles: [8, -12, 8], duration: duration)
        animate(on: "arm_left", key: "ttrRigWalkArmLeft", angles: [-4, 8, 4], duration: duration)
        animate(on: "arm_right", key: "ttrRigWalkArmRight", angles: [4, -10, -4], duration: duration)
        animate(on: "torso", key: "ttrRigWalkTorso", angles: [0, -4, 0], duration: duration)
        animate(on: "head", key: "ttrRigWalkHead", angles: [0, 3, 0], duration: duration)

        run(SKAction.sequence([
            .wait(forDuration: duration),
            .run { [weak self] in self?.playIdle() }
        ]), withKey: "ttrRigReturnIdle")
    }

    func playDeath(duration: TimeInterval, completion: @escaping () -> Void) {
        removeAllActions()
        removeBoneActions()
        animate(on: "hip", key: "ttrRigDeathHip", angles: [0, -8, 38, 76], duration: duration)
        animate(on: "torso", key: "ttrRigDeathTorso", angles: [0, -10, 24, 54], duration: duration)
        animate(on: "head", key: "ttrRigDeathHead", angles: [0, -10, 15, 25], duration: duration)
        animate(on: "arm_left", key: "ttrRigDeathArmLeft", angles: [0, -20, -55, -85], duration: duration)
        animate(on: "arm_right", key: "ttrRigDeathArmRight", angles: [0, 16, 38, 70], duration: duration)
        animate(on: "leg_left_upper", key: "ttrRigDeathLegLeft", angles: [0, -8, -20, -28], duration: duration)
        animate(on: "leg_right_upper", key: "ttrRigDeathLegRight", angles: [0, 10, 18, 24], duration: duration)
        animate(on: "leg_left_lower", key: "ttrRigDeathLegLeftLower", angles: [0, 8, 18, 24], duration: duration)
        animate(on: "leg_right_lower", key: "ttrRigDeathLegRightLower", angles: [0, -8, -16, -24], duration: duration)

        let settle = SKAction.group([
            .moveBy(x: -displaySize.width * 0.10, y: -displaySize.height * 0.10, duration: duration),
            .rotate(byAngle: -0.20, duration: duration)
        ])
        settle.timingMode = .easeIn

        run(.sequence([
            settle,
            .wait(forDuration: 0.18),
            .run(completion)
        ]), withKey: "ttrRigDeath")
    }

    func flashHit() {
        for part in parts.values {
            part.color = SKColor(red: 0.2, green: 0.9, blue: 1.0, alpha: 1)
            let blink = SKAction.sequence([
                .colorize(withColorBlendFactor: 0.48, duration: 0.08),
                .colorize(withColorBlendFactor: 0.0, duration: 0.08)
            ])
            part.run(.repeat(blink, count: 2), withKey: "ttrRigFlash")
        }
    }

    private func buildParts() {
        for spec in boneSpecs {
            let bone = SKNode()
            if spec.name == "root" {
                bone.position = CGPoint(x: -centerX, y: groundY)
            } else {
                bone.position = CGPoint(x: spec.x, y: -spec.y)
            }
            bone.zPosition = 0
            bones[spec.name] = bone
            basePositions[spec.name] = bone.position
        }

        for spec in boneSpecs {
            guard let bone = bones[spec.name] else { continue }
            if let parent = spec.parent, let parentBone = bones[parent] {
                parentBone.addChild(bone)
            } else {
                content.addChild(bone)
            }
        }

        for spec in specs {
            guard let bone = bones[spec.bone] else { continue }

            let sprite = SKSpriteNode(imageNamed: spec.image)
            sprite.size = CGSize(width: spec.width, height: spec.height)
            sprite.position = CGPoint(
                x: spec.offsetX + spec.width / 2,
                y: -(spec.offsetY + spec.height / 2)
            )
            sprite.zPosition = spec.z
            bone.addChild(sprite)
            parts[spec.bone] = sprite
        }
    }

    private func resetPose() {
        removeBoneActions()
        position.y = position.y.rounded()
        zRotation = 0
        setScale(1)
        for (name, bone) in bones {
            bone.zRotation = 0
            if let basePosition = basePositions[name] {
                bone.position = basePosition
            }
        }
    }

    private func removeBoneActions() {
        for bone in bones.values {
            bone.removeAllActions()
        }
    }

    private func runLoop(on boneName: String, key: String, angles: [CGFloat], step: TimeInterval) {
        guard let bone = bones[boneName] else { return }
        let actions = angles.map { angle in
            SKAction.rotate(toAngle: radians(-angle), duration: step, shortestUnitArc: true)
        }
        bone.run(.repeatForever(.sequence(actions)), withKey: key)
    }

    private func animate(on boneName: String, key: String, angles: [CGFloat], duration: TimeInterval) {
        guard let bone = bones[boneName], !angles.isEmpty else { return }
        let segment = duration / TimeInterval(max(angles.count - 1, 1))
        let actions = angles.map { angle in
            SKAction.rotate(toAngle: radians(-angle), duration: segment, shortestUnitArc: true)
        }
        bone.run(.sequence(actions), withKey: key)
    }

    private func radians(_ degrees: CGFloat) -> CGFloat {
        degrees * .pi / 180
    }
}
