import SwiftUI
import CoreImage.CIFilterBuiltins

struct BuyMeVadapavView: View {
    // Replace with your actual UPI ID and Name
    let upiID: String = "blockgame976@okaxis"
    let payeeName: String = "Om Bichave"
    
    @Environment(\.dismiss) private var dismiss
    @State private var qrImage: NSImage?
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, -10)
            .padding(.trailing, -10)
            
            HStack(spacing: 6) {
                Text("Buy me a Vadapav")
                Image("vadapav")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .offset(y: -2)
            }
            .font(.system(size: 20, weight: .bold, design: .rounded))
            
            Text("Scan with any UPI app (GPay, PhonePe, Paytm) to send whatever amount you like.")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
            
            if let qrImage {
                ZStack {
                    Image(nsImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
                    
                    Image("vadapav")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .padding(6)
                        .background(Color(NSColor.windowBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else {
                ProgressView()
                    .frame(width: 180, height: 180)
            }
            
            Text(upiID)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 320)
        .onAppear {
            generateQRCode()
        }
    }
    
    private func generateQRCode() {
        // UPI deep link format
        // pa = Payee Address (UPI ID)
        // pn = Payee Name
        // cu = Currency (INR)
        let upiString = "upi://pay?pa=\(upiID)&pn=\(payeeName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&cu=INR"
        
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(upiString.utf8)
        filter.correctionLevel = "H" // Use High error correction to allow center overlay
        
        if let outputImage = filter.outputImage {
            // Scale up the image to make it crisp
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                self.qrImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            }
        }
    }
}
