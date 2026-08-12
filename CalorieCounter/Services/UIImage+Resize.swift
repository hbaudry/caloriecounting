import UIKit

extension UIImage {
    /// Redimensionne l'image pour que sa plus grande dimension ne dépasse pas
    /// `maxDimension`, en conservant les proportions. Utilisé pour les miniatures
    /// du journal et pour normaliser l'image avant reconnaissance.
    func resizedForUpload(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
