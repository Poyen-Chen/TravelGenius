//
//  Suitcase3DView.swift
//  TravelGenius
//
//  3D 互動行李箱（SceneKit）：打開的硬殼箱，每件物品用去背貼圖躺在箱底。
//   ・單指拖物品＝搬動；放到別的物品上會自動疊高，抽走下面的東西上面會掉下來
//   ・單指拖空白處＝旋轉視角，雙指＝縮放，點一下物品＝切換打包狀態
//  初始擺位沿用 PackingLayoutPacker 的輪廓打包結果，超過箱底深度的自動疊到上一層。
//  疊高上限 maxLevel：拖放超過上限會退回原位；初始建置超過上限會改放到最近的空位。
//  純 SceneKit，無外部相依；模擬器可跑。
//

import SwiftUI
import SceneKit
import UIKit

/// 打包結果與產生它的物品集合簽章綁在一起發布，
/// 場景只比較這個簽章，不會拿新簽章配上舊結果而漏掉重建。
struct SuitcaseLayout {
    let signature: String
    let result: PackingLayoutPacker.Result

    static func signature(of items: [PackingItem]) -> String {
        items.map(\.name).sorted().joined(separator: "|")
    }
}

struct Suitcase3DView: UIViewRepresentable {
    let layout: SuitcaseLayout
    let packedIDs: Set<UUID>
    let floorImage: UIImage?
    /// 每 +1 就丟掉手動擺位、重新照打包器排一次
    let resetToken: Int
    let onToggle: (UUID) -> Void

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.cameraNode
        context.coordinator.view = view
        context.coordinator.installGestures(on: view)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onToggle = onToggle
        if coordinator.builtSignature != layout.signature || coordinator.resetToken != resetToken {
            let fresh = coordinator.resetToken != resetToken || coordinator.builtSignature.isEmpty
            coordinator.resetToken = resetToken
            coordinator.builtSignature = layout.signature
            coordinator.build(from: layout.result, keepExisting: !fresh)
        }
        coordinator.applyPacked(packedIDs)
        coordinator.setFloorImage(floorImage)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator：場景、擺位狀態、手勢

    @MainActor
    final class Coordinator: NSObject {
        // 尺寸：1 格 = 0.1 單位；箱底 44 × 56 格 ≈ 登機箱 40 × 55 cm 的比例
        static let cell: Float = 0.1
        static let floorWCells = PackingLayoutPacker.cols
        static let floorDCells = 56
        static let floorW: Float = Float(floorWCells) * cell
        static let floorD: Float = Float(floorDCells) * cell
        static let layerH: Float = 0.26
        static let wallH: Float = 1.25
        static let maxLevel = 4

        struct Placement {
            var x: Float
            var z: Float
            let w: Float
            let d: Float
            var level: Int
        }

        let scene = SCNScene()
        let cameraNode = SCNNode()
        private let yawNode = SCNNode()
        private let pitchNode = SCNNode()
        private let itemsRoot = SCNNode()
        private let floorMaterial = SCNMaterial()
        private var floorImage: UIImage?

        weak var view: SCNView?
        var onToggle: (UUID) -> Void = { _ in }
        var builtSignature = ""
        var resetToken = 0
        #if DEBUG
        private var stressRan = false
        #endif

        private var placements: [UUID: Placement] = [:]
        private var nodes: [UUID: SCNNode] = [:]

        private var yaw: Float = 0
        private var pitch: Float = -0.95
        private var distance: Float = 9.5

        private enum ActiveGesture {
            case none
            case item(UUID, grabOffset: SIMD2<Float>, planeY: Float, origin: Placement)
            case orbit
        }
        private var active: ActiveGesture = .none
        private var lastPan: CGPoint = .zero
        private let haptic = UIImpactFeedbackGenerator(style: .light)
        private let rejectHaptic = UINotificationFeedbackGenerator()

        private static let shellColor = UIColor(red: 0.17, green: 0.19, blue: 0.24, alpha: 1)
        private static let liningColor = UIColor(red: 0.87, green: 0.80, blue: 0.68, alpha: 1)

        override init() {
            super.init()
            buildStage()
            setupCamera()
            setupLights()
        }

        // MARK: 舞台：箱底、四壁、掀開的箱蓋

        private func buildStage() {
            let outerW = Self.floorW + 0.4
            let outerD = Self.floorD + 0.4
            let wallT: Float = 0.14

            let base = SCNBox(width: CGFloat(outerW), height: 0.22, length: CGFloat(outerD), chamferRadius: 0.06)
            floorMaterial.diffuse.contents = Self.liningColor
            floorMaterial.lightingModel = .lambert
            base.materials = [shell(), shell(), shell(), shell(), floorMaterial, shell()]
            let baseNode = SCNNode(geometry: base)
            baseNode.position = SCNVector3(0, -0.11, 0)
            scene.rootNode.addChildNode(baseNode)

            // SCNBox 面序：0 前(+z) 1 右(+x) 2 後(-z) 3 左(-x) 4 上 5 下
            func wall(w: Float, d: Float, x: Float, z: Float, insideFace: Int, opacity: CGFloat) {
                let box = SCNBox(width: CGFloat(w), height: CGFloat(Self.wallH), length: CGFloat(d), chamferRadius: 0.03)
                var materials = (0..<6).map { _ in shell() }
                materials[insideFace] = lining()
                box.materials = materials
                let node = SCNNode(geometry: box)
                node.position = SCNVector3(x, Self.wallH / 2, z)
                node.opacity = opacity
                scene.rootNode.addChildNode(node)
            }
            wall(w: outerW, d: wallT, x: 0, z: -outerD / 2 + wallT / 2, insideFace: 0, opacity: 1)
            wall(w: outerW, d: wallT, x: 0, z: outerD / 2 - wallT / 2, insideFace: 2, opacity: 0.5) // 前壁半透明不擋視線
            wall(w: wallT, d: outerD, x: -outerW / 2 + wallT / 2, z: 0, insideFace: 1, opacity: 0.85)
            wall(w: wallT, d: outerD, x: outerW / 2 - wallT / 2, z: 0, insideFace: 3, opacity: 0.85)

            // 箱蓋：鉸鏈在後壁頂端，向後掀約 112°
            let hinge = SCNNode()
            hinge.position = SCNVector3(0, Self.wallH, -outerD / 2)
            hinge.eulerAngles.x = -1.95
            let lid = SCNBox(width: CGFloat(outerW), height: 0.16, length: CGFloat(outerD), chamferRadius: 0.06)
            lid.materials = [shell(), shell(), shell(), shell(), shell(), lining()]
            let lidNode = SCNNode(geometry: lid)
            lidNode.position = SCNVector3(0, 0.08, outerD / 2)
            hinge.addChildNode(lidNode)

            // 箱蓋內側的拉鍊網袋
            let pocket = SCNPlane(width: CGFloat(outerW - 0.6), height: CGFloat(outerD * 0.55))
            let pocketMaterial = SCNMaterial()
            pocketMaterial.diffuse.contents = UIColor(white: 0.2, alpha: 0.35)
            pocketMaterial.isDoubleSided = true
            pocket.materials = [pocketMaterial]
            let pocketNode = SCNNode(geometry: pocket)
            pocketNode.eulerAngles.x = .pi / 2
            pocketNode.position = SCNVector3(0, -0.006, outerD * 0.5)
            lidNode.addChildNode(pocketNode)
            scene.rootNode.addChildNode(hinge)

            scene.rootNode.addChildNode(itemsRoot)
        }

        private func shell() -> SCNMaterial {
            let m = SCNMaterial()
            m.diffuse.contents = Self.shellColor
            m.lightingModel = .blinn
            m.specular.contents = UIColor(white: 0.35, alpha: 1)
            return m
        }

        private func lining() -> SCNMaterial {
            let m = SCNMaterial()
            m.diffuse.contents = Self.liningColor
            m.lightingModel = .lambert
            return m
        }

        private func setupCamera() {
            let camera = SCNCamera()
            camera.fieldOfView = 46
            camera.zNear = 0.1
            camera.zFar = 100
            cameraNode.camera = camera
            yawNode.position = SCNVector3(0, 0.35, 0)
            scene.rootNode.addChildNode(yawNode)
            yawNode.addChildNode(pitchNode)
            pitchNode.addChildNode(cameraNode)
            applyCamera()
        }

        private func applyCamera() {
            yawNode.eulerAngles.y = yaw
            pitchNode.eulerAngles.x = pitch
            cameraNode.position = SCNVector3(0, 0, distance)
        }

        private func setupLights() {
            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.intensity = 600
            let ambientNode = SCNNode()
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)

            let key = SCNLight()
            key.type = .directional
            key.intensity = 850
            let keyNode = SCNNode()
            keyNode.light = key
            keyNode.eulerAngles = SCNVector3(-1.1, 0.45, 0)
            scene.rootNode.addChildNode(keyNode)
        }

        // MARK: 物品節點

        func build(from result: PackingLayoutPacker.Result, keepExisting: Bool) {
            let previous = keepExisting ? placements : [:]
            placements = [:]
            nodes.values.forEach { $0.removeFromParentNode() }
            nodes = [:]

            var proposed: [UUID: Placement] = [:]
            var kept: [UUID] = []
            var fresh: [UUID] = []
            for placed in result.placed {
                let w = Float(placed.w) * Self.cell
                let d = Float(placed.h) * Self.cell
                if let existing = previous[placed.id] {
                    proposed[placed.id] = existing
                    kept.append(placed.id)
                } else {
                    proposed[placed.id] = initialPlacement(for: placed, w: w, d: d)
                    fresh.append(placed.id)
                }
                let node = makeItemNode(placed.item, w: w, d: d)
                node.name = "item:\(placed.id.uuidString)"
                nodes[placed.id] = node
                itemsRoot.addChildNode(node)
            }

            // 沿用的手動擺位先就位（低層在前），新物品照打包順序疊上去；
            // 疊高超過上限的新物品改放到最近的空位。
            kept.sort { a, b in
                let la = proposed[a]!.level, lb = proposed[b]!.level
                return la != lb ? la < lb : a.uuidString < b.uuidString
            }
            placements = settle(kept + fresh, proposed: proposed) { _, placement, settled in
                relocated(placement, over: settled) ?? placement
            }
            for (id, placement) in placements {
                if let node = nodes[id] { apply(placement, to: node) }
            }
            logInvariant("build")
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-suitcaseLayoutStress"), !stressRan {
                stressRan = true
                debugStackStress()
            }
            #endif
        }

        /// 打包器把畫布往下無限延伸；超過箱底深度的部分摺成上一層（層數只是提議，結算時以實際重疊為準）
        private func initialPlacement(for placed: PackedItem, w: Float, d: Float) -> Placement {
            var layer = placed.y / Self.floorDCells
            var zCell = placed.y % Self.floorDCells
            if zCell + placed.h > Self.floorDCells {
                layer += 1
                zCell = 0
            }
            return Placement(
                x: (Float(placed.x) + Float(placed.w) / 2) * Self.cell - Self.floorW / 2,
                z: (Float(zCell) + Float(placed.h) / 2) * Self.cell - Self.floorD / 2,
                w: w, d: d,
                level: layer
            )
        }

        private func makeItemNode(_ item: PackingItem, w: Float, d: Float) -> SCNNode {
            let textures = ItemTextures.textures(for: item)
            let node = SCNNode()

            let shadow = SCNNode(geometry: plane(w * 1.04, d * 1.04, textures.silhouette))
            shadow.eulerAngles.x = -.pi / 2
            shadow.opacity = 0.28
            shadow.position = SCNVector3(0.06, -0.012, 0.06)
            node.addChildNode(shadow)

            let art = SCNNode(geometry: plane(w, d, textures.art))
            art.eulerAngles.x = -.pi / 2
            node.addChildNode(art)
            return node
        }

        private func plane(_ w: Float, _ h: Float, _ image: UIImage) -> SCNPlane {
            let plane = SCNPlane(width: CGFloat(w), height: CGFloat(h))
            let material = SCNMaterial()
            material.diffuse.contents = image
            material.lightingModel = .constant
            material.isDoubleSided = true
            material.transparencyMode = .aOne
            material.blendMode = .alpha
            plane.materials = [material]
            return plane
        }

        private func yFor(level: Int) -> Float {
            0.02 + Float(level) * Self.layerH
        }

        private func apply(_ placement: Placement, to node: SCNNode) {
            node.position = SCNVector3(placement.x, yFor(level: placement.level), placement.z)
            node.renderingOrder = placement.level * 10 + 1
        }

        func applyPacked(_ ids: Set<UUID>) {
            for (id, node) in nodes {
                node.opacity = ids.contains(id) ? 1 : 0.38
            }
        }

        func setFloorImage(_ image: UIImage?) {
            guard image !== floorImage else { return }
            floorImage = image
            floorMaterial.diffuse.contents = image ?? Self.liningColor
        }

        // MARK: 手勢

        func installGestures(on view: SCNView) {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.maximumNumberOfTouches = 1
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            view.addGestureRecognizer(pan)
            view.addGestureRecognizer(pinch)
            view.addGestureRecognizer(tap)
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view else { return }
            let location = gesture.location(in: view)
            switch gesture.state {
            case .began:
                if let id = itemID(at: location, in: view),
                   let placement = placements[id],
                   let node = nodes[id] {
                    let planeY = yFor(level: placement.level)
                    let hit = floorPoint(at: location, planeY: planeY, in: view) ?? SIMD2(placement.x, placement.z)
                    active = .item(id, grabOffset: SIMD2(placement.x - hit.x, placement.z - hit.y), planeY: planeY, origin: placement)
                    haptic.prepare()
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.15
                    node.position.y = planeY + 0.55
                    node.scale = SCNVector3(1.06, 1.06, 1.06)
                    node.renderingOrder = 1_000
                    SCNTransaction.commit()
                } else {
                    active = .orbit
                }
                lastPan = location

            case .changed:
                switch active {
                case .item(let id, let offset, let planeY, _):
                    guard var placement = placements[id],
                          let node = nodes[id],
                          let hit = floorPoint(at: location, planeY: planeY, in: view) else { return }
                    placement.x = clamp(hit.x + offset.x, -Self.floorW / 2 + placement.w / 2, Self.floorW / 2 - placement.w / 2)
                    placement.z = clamp(hit.y + offset.y, -Self.floorD / 2 + placement.d / 2, Self.floorD / 2 - placement.d / 2)
                    placements[id] = placement
                    node.position.x = placement.x
                    node.position.z = placement.z
                case .orbit:
                    let dx = Float(location.x - lastPan.x)
                    let dy = Float(location.y - lastPan.y)
                    yaw -= dx * 0.008
                    pitch = clamp(pitch - dy * 0.006, -1.45, -0.28)
                    applyCamera()
                    lastPan = location
                case .none:
                    break
                }

            case .ended, .cancelled, .failed:
                if case .item(let id, _, _, let origin) = active {
                    if resettle(dropped: id, origin: origin) {
                        haptic.impactOccurred()
                    } else {
                        rejectHaptic.notificationOccurred(.warning)
                    }
                }
                active = .none

            default:
                break
            }
        }

        @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard gesture.state == .changed else { return }
            distance = clamp(distance / Float(gesture.scale), 5, 14)
            gesture.scale = 1
            applyCamera()
        }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view, let id = itemID(at: gesture.location(in: view), in: view) else { return }
            haptic.impactOccurred()
            onToggle(id)
        }

        /// 重新計算所有物品的疊放層：由低往高處理，剛放下的最後處理（永遠在最上面）。
        /// 抽走下層物品時，上面的會自然掉下來。放下處疊高會超過上限時，退回拖起前的位置。
        /// 回傳 false 表示這次放置被退回。
        @discardableResult
        private func resettle(dropped: UUID, origin: Placement) -> Bool {
            let order = placements.keys.sorted { a, b in
                if a == dropped { return false }
                if b == dropped { return true }
                let la = placements[a]!.level, lb = placements[b]!.level
                return la != lb ? la < lb : a.uuidString < b.uuidString
            }
            var accepted = true
            let settled = settle(order, proposed: placements) { id, placement, settled in
                guard id == dropped else { return placement }
                accepted = false
                var back = origin
                back.level = stackLevel(for: back, over: settled)
                return back
            }

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.22
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
            for (id, placement) in settled {
                guard let node = nodes[id] else { continue }
                if placements[id]?.level != placement.level || id == dropped {
                    apply(placement, to: node)
                }
                if id == dropped { node.scale = SCNVector3(1, 1, 1) }
            }
            SCNTransaction.commit()
            placements = settled
            logInvariant(accepted ? "drop" : "drop-rejected")
            return accepted
        }

        /// 依序結算每件物品的層數；超過上限時交給 overflow 決定最終擺位
        private func settle(
            _ order: [UUID],
            proposed: [UUID: Placement],
            overflow: (UUID, Placement, [UUID: Placement]) -> Placement
        ) -> [UUID: Placement] {
            var settled: [UUID: Placement] = [:]
            for id in order {
                guard var placement = proposed[id] else { continue }
                placement.level = stackLevel(for: placement, over: settled)
                if placement.level > Self.maxLevel {
                    placement = overflow(id, placement, settled)
                }
                settled[id] = placement
            }
            return settled
        }

        /// 與已就位物品重疊者之上一層
        private func stackLevel(for placement: Placement, over settled: [UUID: Placement]) -> Int {
            let mine = footprint(placement)
            var level = 0
            for other in settled.values where footprint(other).intersects(mine) {
                level = max(level, other.level + 1)
            }
            return level
        }

        /// 在箱底掃描一個疊高不超過上限的位置：層數最低優先，同層取離原位最近者。
        /// 整箱都放不下時回傳 nil。
        private func relocated(_ placement: Placement, over settled: [UUID: Placement]) -> Placement? {
            let step = Self.cell * 4
            var best: (placement: Placement, distance: Float)?
            var x = -Self.floorW / 2 + placement.w / 2
            while x <= Self.floorW / 2 - placement.w / 2 + 1e-4 {
                var z = -Self.floorD / 2 + placement.d / 2
                while z <= Self.floorD / 2 - placement.d / 2 + 1e-4 {
                    var candidate = placement
                    candidate.x = x
                    candidate.z = z
                    candidate.level = stackLevel(for: candidate, over: settled)
                    if candidate.level <= Self.maxLevel {
                        let distance = (x - placement.x) * (x - placement.x) + (z - placement.z) * (z - placement.z)
                        if let current = best {
                            if candidate.level < current.placement.level
                                || (candidate.level == current.placement.level && distance < current.distance) {
                                best = (candidate, distance)
                            }
                        } else {
                            best = (candidate, distance)
                        }
                    }
                    z += step
                }
                x += step
            }
            return best?.placement
        }

        /// 不變量：重疊的物品不得同層；超過上限只在整箱放不下時發生。Debug 時寫進 log 供模擬器驗證。
        private func logInvariant(_ event: String) {
            #if DEBUG
            let all = Array(placements)
            var sameLevelOverlaps = 0
            for i in all.indices {
                for j in all.indices where j > i {
                    let a = all[i].value, b = all[j].value
                    if a.level == b.level && footprint(a).intersects(footprint(b)) { sameLevelOverlaps += 1 }
                }
            }
            let top = all.map(\.value.level).max() ?? -1
            NSLog("SUITCASE-3D %@ nodes=%d sameLevelOverlaps=%d topLevel=%d", event, nodes.count, sameLevelOverlaps, top)
            #endif
        }

        #if DEBUG
        /// 模擬器驗證用（`-suitcaseLayoutStress`）：把前 6 件物品依序放到同一點，模擬連續疊放。
        func debugStackStress() {
            let ids = placements.keys.sorted { $0.uuidString < $1.uuidString }.prefix(6)
            for id in ids {
                guard let origin = placements[id] else { continue }
                var moved = origin
                moved.x = 0
                moved.z = 0
                placements[id] = moved
                let accepted = resettle(dropped: id, origin: origin)
                let final = placements[id]!
                NSLog("SUITCASE-3D stress-drop accepted=%d level=%d x=%.2f z=%.2f", accepted ? 1 : 0, final.level, final.x, final.z)
            }
        }
        #endif

        /// 判定疊放用的佔地（縮 20% 讓邊緣輕碰不算疊上）
        private func footprint(_ p: Placement) -> CGRect {
            CGRect(x: CGFloat(p.x - p.w / 2), y: CGFloat(p.z - p.d / 2), width: CGFloat(p.w), height: CGFloat(p.d))
                .insetBy(dx: CGFloat(p.w) * 0.2, dy: CGFloat(p.d) * 0.2)
        }

        private func itemID(at point: CGPoint, in view: SCNView) -> UUID? {
            let hits = view.hitTest(point, options: [
                .searchMode: SCNHitTestSearchMode.all.rawValue,
                .ignoreHiddenNodes: true,
            ])
            for hit in hits {
                var current: SCNNode? = hit.node
                while let node = current {
                    if let name = node.name, name.hasPrefix("item:"),
                       let id = UUID(uuidString: String(name.dropFirst(5))) {
                        return id
                    }
                    current = node.parent
                }
            }
            return nil
        }

        /// 螢幕點 → 與水平面 y = planeY 的交點（x, z）
        private func floorPoint(at point: CGPoint, planeY: Float, in view: SCNView) -> SIMD2<Float>? {
            let near = view.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 0))
            let far = view.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 1))
            let dy = far.y - near.y
            guard abs(dy) > 1e-5 else { return nil }
            let t = (planeY - near.y) / dy
            guard t > 0 else { return nil }
            return SIMD2(near.x + (far.x - near.x) * t, near.z + (far.z - near.z) * t)
        }

        private func clamp(_ v: Float, _ lo: Float, _ hi: Float) -> Float {
            min(max(v, lo), hi)
        }
    }
}

// MARK: - 貼圖：去背照片或 emoji，加一張黑色剪影當接觸陰影

enum ItemTextures {
    private static var cache: [String: (art: UIImage, silhouette: UIImage)] = [:]

    static func textures(for item: PackingItem) -> (art: UIImage, silhouette: UIImage) {
        let key = PackingItemImage.imageKey(for: item) ?? "emoji:\(PackingGlyph.emoji(for: item))"
        if let cached = cache[key] { return cached }
        let art = PackingItemImage.image(for: item) ?? emojiImage(PackingGlyph.emoji(for: item))
        let result = (art: art, silhouette: silhouette(of: art))
        cache[key] = result
        return result
    }

    private static func emojiImage(_ emoji: String) -> UIImage {
        let size = CGSize(width: 256, height: 256)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let text = NSAttributedString(string: emoji, attributes: [.font: UIFont.systemFont(ofSize: 190)])
            let bounds = text.size()
            text.draw(at: CGPoint(x: (size.width - bounds.width) / 2, y: (size.height - bounds.height) / 2))
        }
    }

    /// 保留 alpha、把顏色全填黑（sourceIn）
    private static func silhouette(of image: UIImage) -> UIImage {
        let size = CGSize(width: max(image.size.width, 1), height: max(image.size.height, 1))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            image.draw(in: rect)
            ctx.cgContext.setBlendMode(.sourceIn)
            ctx.cgContext.setFillColor(UIColor.black.cgColor)
            ctx.cgContext.fill(rect)
        }
    }
}
