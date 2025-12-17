//
//  ImageStorage.swift
//  playground
//
//  CalAI Clone - Local image storage management
//

import Foundation
import UIKit

/// Manages local storage of meal images
final class ImageStorage {
    static let shared = ImageStorage()
    
    private let fileManager = FileManager.default
    private let imageDirectory: URL
    
    private init() {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        imageDirectory = documentsDirectory.appendingPathComponent("MealImages", isDirectory: true)
        
        // Create directory if needed
        if !fileManager.fileExists(atPath: imageDirectory.path) {
            try? fileManager.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        }
    }
    
    /// Saves an image and returns the file URL
    func saveImage(_ image: UIImage, for mealId: UUID) throws -> URL {
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            throw ImageStorageError.compressionFailed
        }
        
        let fileName = "\(mealId.uuidString).jpg"
        let fileURL = imageDirectory.appendingPathComponent(fileName)
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    /// Loads an image from a file URL
    func loadImage(from urlString: String) -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        
        // Check if it's a file URL
        if url.isFileURL {
            return UIImage(contentsOfFile: url.path)
        }
        
        // Try as a path within our image directory
        let fileURL = imageDirectory.appendingPathComponent(url.lastPathComponent)
        return UIImage(contentsOfFile: fileURL.path)
    }
    
    /// Deletes an image file
    func deleteImage(at urlString: String) {
        guard let url = URL(string: urlString) else { return }
        try? fileManager.removeItem(at: url)
    }
    
    /// Deletes all stored images
    func deleteAllImages() throws {
        let contents = try fileManager.contentsOfDirectory(at: imageDirectory, includingPropertiesForKeys: nil)
        for url in contents {
            try fileManager.removeItem(at: url)
        }
    }
}

enum ImageStorageError: LocalizedError {
    case compressionFailed
    case saveFailed
    case loadFailed
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .saveFailed:
            return "Failed to save image"
        case .loadFailed:
            return "Failed to load image"
        }
    }
}
