import SwiftUI
import PhotosUI

// MARK: - Scan Result Model
struct ScanResult: Codable {
    let product_name: String
    let verdict: String // "safe", "caution", "avoid"
    let score: Double
    let warnings: [String]
    let positives: [String]
    let summary: String
}

// MARK: - Scan & Decide View
struct ScanDecideView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var scanResult: ScanResult?
    @State private var isScanning = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // Header
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.green, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "barcode.viewfinder")
                                    .foregroundColor(.white)
                                    .font(.title3)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Scan & Decide").font(.title2).bold()
                                Text("AI анализ состава продукта").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
                    }
                    .padding(.horizontal)

                    // Photo picker
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemGray6))
                                .frame(height: 200)

                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.green, lineWidth: 2)
                                    )
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "barcode.viewfinder")
                                        .font(.system(size: 48))
                                        .foregroundColor(.green.opacity(0.7))
                                    Text("Сфотографируй этикетку")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("AI найдёт вредные добавки, сахар и трансжиры")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                            }

                            if isScanning {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.black.opacity(0.5))
                                    .frame(height: 200)
                                VStack(spacing: 10) {
                                    ProgressView().tint(.white)
                                    Text("Gemini анализирует...").font(.subheadline).foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .onChange(of: selectedItem) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                selectedImage = image
                                await scanProduct(imageData: data)
                            }
                        }
                    }

                    // Result
                    if let result = scanResult {
                        ScanResultCard(result: result)
                            .padding(.horizontal)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage).font(.caption).foregroundColor(.red).padding(.horizontal)
                    }

                    // Tips
                    if scanResult == nil && !isScanning {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("На что обращать внимание").font(.headline)

                            TipRow(icon: "exclamationmark.triangle.fill", color: .red, tip: "E621, E631 — усилители вкуса")
                            TipRow(icon: "exclamationmark.triangle.fill", color: .orange, tip: "Трансжиры — hydrogenated oil")
                            TipRow(icon: "drop.fill", color: .blue, tip: "Натрий > 600мг на порцию")
                            TipRow(icon: "cube.fill", color: .purple, tip: "Сахар в первых 3 ингредиентах")
                            TipRow(icon: "checkmark.circle.fill", color: .green, tip: "Менее 5 ингредиентов — хорошо")
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 30)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Scan & Decide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") { dismiss() }
                }
                if scanResult != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Сканировать ещё") {
                            selectedImage = nil
                            scanResult = nil
                            selectedItem = nil
                        }
                    }
                }
            }
        }
    }

    func scanProduct(imageData: Data) async {
        isScanning = true
        errorMessage = ""
        do {
            scanResult = try await NetworkManager.shared.scanProduct(imageData: imageData)
        } catch {
            errorMessage = "Не удалось проанализировать продукт"
        }
        isScanning = false
    }
}

// MARK: - Scan Result Card
struct ScanResultCard: View {
    let result: ScanResult

    var verdictColor: Color {
        switch result.verdict {
        case "safe": return .green
        case "caution": return .orange
        case "avoid": return .red
        default: return .gray
        }
    }

    var verdictEmoji: String {
        switch result.verdict {
        case "safe": return "✅"
        case "caution": return "⚠️"
        case "avoid": return "🚫"
        default: return "❓"
        }
    }

    var verdictText: String {
        switch result.verdict {
        case "safe": return "Можно есть"
        case "caution": return "С осторожностью"
        case "avoid": return "Лучше избегать"
        default: return "Неизвестно"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Product name + verdict
            HStack(spacing: 14) {
                Text(verdictEmoji).font(.system(size: 36))

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.product_name).font(.title3).bold().lineLimit(2)
                    Text(verdictText)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(verdictColor)
                }

                Spacer()

                // Score circle
                ZStack {
                    Circle()
                        .stroke(verdictColor.opacity(0.2), lineWidth: 6)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: result.score / 10)
                        .stroke(verdictColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(String(format: "%.1f", result.score))
                            .font(.system(size: 14, weight: .bold))
                        Text("/10").font(.system(size: 8)).foregroundColor(.secondary)
                    }
                }
            }

            Divider()

            // Summary
            Text(result.summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(3)

            // Warnings
            if !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("⚠️ Предупреждения").font(.subheadline).bold().foregroundColor(.red)
                    ForEach(result.warnings, id: \.self) { warning in
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.red).font(.caption)
                            Text(warning).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.red.opacity(0.06))
                .cornerRadius(12)
            }

            // Positives
            if !result.positives.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("✅ Плюсы").font(.subheadline).bold().foregroundColor(.green)
                    ForEach(result.positives, id: \.self) { positive in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
                            Text(positive).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.green.opacity(0.06))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: verdictColor.opacity(0.15), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(verdictColor.opacity(0.2), lineWidth: 1.5)
        )
    }
}

struct TipRow: View {
    let icon: String
    let color: Color
    let tip: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(color).font(.subheadline).frame(width: 20)
            Text(tip).font(.subheadline).foregroundColor(.secondary)
        }
    }
}
