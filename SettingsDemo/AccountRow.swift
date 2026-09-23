import SwiftUI

struct AccountRow: View {
    let name: String

    @ScaledMetric(relativeTo: .body) private var avatarSize = 48.0

    var body: some View {
        HStack {
            Text("J")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: avatarSize, height: avatarSize)
                .background(.red, in: Circle())

            Text(name)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    Form {
        AccountRow(name: AppCredentials.username)
    }
}
