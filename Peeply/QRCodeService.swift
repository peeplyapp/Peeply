//
//  QRCodeService.swift
//  Peeply
//
//  Copyright 2026 Peeply LLC. All rights reserved.
//  This software is confidential and proprietary property.
//  Unauthorized copying, modification, or distribution is strictly prohibited.

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum QRCodeService {
    private static let context = CIContext()

    /// Generate a sharp QR image for display in the digital business card sheet.
    static func makeImage(from string: String, dimension: CGFloat = 900) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let extent = outputImage.extent.integral
        let scale = min(dimension / extent.width, dimension / extent.height)
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
