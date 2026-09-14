//
//  SuitcaseLayoutView.swift
//  TravelGenius
//
//  行李箱擺位（3D 互動版）：打開的硬殼箱裡，每件物品用去背照片依實際大小躺在箱底，
//  可以直接用手指搬動、疊高、轉視角。初始擺位由 PackingLayoutPacker 的輪廓打包算出。
//  拍/選一張行李箱照片會貼成箱底襯裡；未打包＝淡化待放；已打包＝滿版清楚，點一下可切換。
//  模擬器沒相機 → 走相簿；實機才顯示「拍照」。
//

import SwiftUI
import PhotosUI
import UIKit

struct SuitcaseLayoutView: View {
    let trip: Trip

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var suitcaseImage: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false
    /// 打包結果與其物品簽章一起發布（見 SuitcaseLayout）
    @State private var layout: SuitcaseLayout?
    @State private var resetToken = 0

    private var items: [PackingItem] {
        (trip.packingItems ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }
    /// 只由「物品集合」決定初始版面（打包勾選只改透明度，不重排）。
    private var layoutSignature: String { SuitcaseLayout.signature(of: items) }
    private var packedIDs: Set<UUID> {
        Set(items.filter(\.isPacked).map(\.id))
    }
    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("拖動物品擺進箱子，疊到別的東西上會自動堆高。拖空白處旋轉、雙指縮放、點一下切換打包。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                stage

                HStack {
                    Label("已打包 \(packedIDs.count) / \(items.count)", systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("重新排列", systemImage: "arrow.triangle.2.circlepath") {
                        resetToken += 1
                    }
                    .font(.subheadline)
                }

                sourceButtons
            }
            .padding()
            .navigationTitle("行李箱擺位")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task(id: layoutSignature) {
                // 用同一份快照算簽章與結果，兩者一起發布
                let snapshot = items
                layout = SuitcaseLayout(signature: SuitcaseLayout.signature(of: snapshot), result: PackingLayoutPacker.pack(snapshot))
            }
            .task { await runStressIfRequested() }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        suitcaseImage = image
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { image in suitcaseImage = image }
                    .ignoresSafeArea()
            }
        }
    }

    private var stage: some View {
        ZStack {
            if let layout, !layout.result.placed.isEmpty {
                Suitcase3DView(
                    layout: layout,
                    packedIDs: packedIDs,
                    floorImage: suitcaseImage,
                    resetToken: resetToken,
                    onToggle: { id in
                        items.first { $0.id == id }?.isPacked.toggle()
                    }
                )
            } else if layout == nil {
                ProgressView()
            } else {
                ContentUnavailableView("還沒有行李", systemImage: "suitcase", description: Text("先產生清單，再回來擺箱。"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(.secondarySystemGroupedBackground), Color(.systemGroupedBackground)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08))
        )
    }

    /// 模擬器驗證用（`-suitcaseLayoutStress`）：擺位頁開著時新增再刪除一件物品，
    /// 對照 log 裡 SUITCASE-3D 的 nodes 與這裡的 items 數量。
    private func runStressIfRequested() async {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-suitcaseLayoutStress") else { return }
        try? await Task.sleep(for: .seconds(4))
        let added = PackingItem(
            name: "壓力測試物品",
            category: .other,
            reasonKey: PackingListGenerator.customReason,
            quantity: 1,
            isCustom: true,
            sortIndex: PackingListGenerator.customSortIndex,
            trip: trip
        )
        context.insert(added)
        NSLog("SUITCASE-3D stress items=%d after insert", items.count)
        try? await Task.sleep(for: .seconds(4))
        if let victim = items.first(where: { $0.id != added.id }) {
            context.delete(victim)
        }
        NSLog("SUITCASE-3D stress items=%d after delete", items.count)
        #endif
    }

    private var sourceButtons: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("箱底用相簿照片", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if cameraAvailable {
                Button {
                    showingCamera = true
                } label: {
                    Label("拍照", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if suitcaseImage != nil {
                Button {
                    suitcaseImage = nil
                    photoItem = nil
                } label: {
                    Label("還原襯裡", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
            }
        }
        .font(.subheadline)
    }
}

// MARK: - 相機（實機用；模擬器無相機不會顯示此入口）

private struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
