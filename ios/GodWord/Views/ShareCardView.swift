import SwiftUI

/// 공유용 결과 카드 (ImageRenderer로 이미지로 만들어 공유합니다)
struct ShareCardView: View {
    let prescription: Prescription

    private let teal = Color(red: 0.122, green: 0.435, blue: 0.471)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("오늘의 말씀 처방")
                .font(.caption.bold())
                .foregroundStyle(teal)

            Text(prescription.summary)
                .font(.title3.bold())
                .foregroundStyle(.black)

            if let verse = prescription.verses.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verse.text)
                        .font(.body)
                        .lineSpacing(4)
                        .foregroundStyle(.black)
                    Text(verse.reference)
                        .font(.footnote.bold())
                        .foregroundStyle(teal)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 0) {
                ForEach(prescription.energy.items, id: \.name) { item in
                    VStack(spacing: 4) {
                        Text("\(item.value)")
                            .font(.headline)
                            .foregroundStyle(teal)
                        Text(item.name)
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Text("말씀의 위로")
                .font(.caption.bold())
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(24)
        .frame(width: 360)
        .background(.white)
    }
}

#Preview {
    ShareCardView(prescription: .sample)
}
