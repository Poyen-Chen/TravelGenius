//
//  SuitcaseLayoutView.swift
//  TravelGenius
//
//  行李箱擺位：拍/選一張行李箱照片當固定 2D 畫布，用每件物品去背照片的「輪廓」
//  （alpha ＝ 現成 segmentation）做非矩形、compact 的形狀打包，像真的把東西塞進去。
//  未打包＝淡化待放；已打包＝滿版清楚。冷門品項退回 emoji。
//  模擬器沒相機 → 走相簿或內建示意行李箱；實機才顯示「拍照」。
//

import SwiftUI
import PhotosUI
import UIKit

struct SuitcaseLayoutView: View {
    let trip: Trip

    @Environment(\.dismiss) private var dismiss
    @State private var suitcaseImage: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var packResult: PackingLayoutPacker.Result?

    private var items: [PackingItem] {
        (trip.packingItems ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }
    /// 只由「物品集合」決定版面（打包勾選只改透明度，不重排）。
    private var layoutSignature: String {
        items.map(\.name).sorted().joined(separator: "|")
    }
    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text("依物品實際大小與輪廓擺進行李箱：淡色是還沒打包的，打包好就變清楚。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    canvas

                    sourceButtons
                }
                .padding()
            }
            .navigationTitle("行李箱擺位")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task(id: layoutSignature) {
                packResult = PackingLayoutPacker.pack(items)
            }
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

    private var canvas: some View {
        GeometryReader { geo in
            if let result = packResult, !result.placed.isEmpty {
                let cell = min(geo.size.width / CGFloat(result.cols),
                               500.0 / CGFloat(max(result.rows, 1)))
                let cw = CGFloat(result.cols) * cell
                let ch = CGFloat(result.rows) * cell
                ZStack(alignment: .topLeading) {
                    ForEach(result.placed) { placed in
                        itemArt(placed.item)
                            .frame(width: CGFloat(placed.w) * cell, height: CGFloat(placed.h) * cell)
                            .opacity(placed.item.isPacked ? 1 : 0.35)
                            .shadow(color: .black.opacity(placed.item.isPacked ? 0.25 : 0), radius: 3, y: 2)
                            .position(
                                x: (CGFloat(placed.x) + CGFloat(placed.w) / 2) * cell,
                                y: (CGFloat(placed.y) + CGFloat(placed.h) / 2) * cell
                            )
                    }
                }
                .frame(width: cw, height: ch)
                .padding(10)
                .background {
                    if let suitcaseImage {
                        Image(uiImage: suitcaseImage).resizable().scaledToFill()
                    } else {
                        DrawnSuitcase()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.12))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity) // 在固定框內置中
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: 520)
    }

    @ViewBuilder
    private func itemArt(_ item: PackingItem) -> some View {
        if let image = PackingItemImage.image(for: item) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            GeometryReader { g in
                Text(PackingGlyph.emoji(for: item))
                    .font(.system(size: min(g.size.width, g.size.height) * 0.82))
                    .minimumScaleFactor(0.1)
                    .frame(width: g.size.width, height: g.size.height)
            }
        }
    }

    private var sourceButtons: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("從相簿選", systemImage: "photo.on.rectangle")
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
                    Label("用示意圖", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
            }
        }
        .font(.subheadline)
    }
}

// MARK: - 內建示意行李箱（無照片時的固定畫布）

private struct DrawnSuitcase: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.80, green: 0.68, blue: 0.52), Color(red: 0.66, green: 0.53, blue: 0.39)],
                startPoint: .top, endPoint: .bottom
            )
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 2)
                .padding(10)
        }
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
