//
//  File.swift
//  SDK
//
//  Created by Dubon Ya'ar on 05/11/2024.
//

import Foundation

public enum Utils {
    static var osVersion: String = {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
    }()

    public static var deviceModel: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }()

    public static var marketingDeviceName: String? = {
        deviceMap[deviceModel]
    }()

    static let deviceMap: [String: String] = [
        // iPhone
        "iPhone1,1": "iPhone",
        "iPhone1,2": "iPhone 3G",
        "iPhone2,1": "iPhone 3GS",
        "iPhone3,1": "iPhone 4",
        "iPhone3,2": "iPhone 4",
        "iPhone3,3": "iPhone 4 (CDMA)",
        "iPhone4,1": "iPhone 4S",
        "iPhone5,1": "iPhone 5 (GSM)",
        "iPhone5,2": "iPhone 5 (Global)",
        "iPhone5,3": "iPhone 5C (GSM)",
        "iPhone5,4": "iPhone 5C (Global)",
        "iPhone6,1": "iPhone 5S (GSM)",
        "iPhone6,2": "iPhone 5S (Global)",
        "iPhone7,2": "iPhone 6",
        "iPhone7,1": "iPhone 6 Plus",
        "iPhone8,1": "iPhone 6S",
        "iPhone8,2": "iPhone 6S Plus",
        "iPhone8,4": "iPhone SE (1st Gen)",
        "iPhone9,1": "iPhone 7",
        "iPhone9,2": "iPhone 7 Plus",
        "iPhone9,3": "iPhone 7",
        "iPhone9,4": "iPhone 7 Plus",
        "iPhone10,1": "iPhone 8",
        "iPhone10,2": "iPhone 8 Plus",
        "iPhone10,3": "iPhone X (Global)",
        "iPhone10,4": "iPhone 8",
        "iPhone10,5": "iPhone 8 Plus",
        "iPhone10,6": "iPhone X (GSM)",
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max (China)",
        "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd Gen)",
        "iPhone13,1": "iPhone 12 Mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 Mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3rd Gen)",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone16,1": "iPhone 15",
        "iPhone16,2": "iPhone 15 Plus",
        "iPhone16,3": "iPhone 15 Pro",
        "iPhone16,4": "iPhone 15 Pro Max",

        // iPad
        "iPad1,1": "iPad",
        "iPad2,1": "iPad 2 (Wi-Fi)",
        "iPad2,2": "iPad 2 (GSM)",
        "iPad2,3": "iPad 2 (CDMA)",
        "iPad2,4": "iPad 2 (Wi-Fi, Rev A)",
        "iPad3,1": "iPad (3rd Gen, Wi-Fi)",
        "iPad3,2": "iPad (3rd Gen, GSM/CDMA)",
        "iPad3,3": "iPad (3rd Gen, GSM)",
        "iPad3,4": "iPad (4th Gen, Wi-Fi)",
        "iPad3,5": "iPad (4th Gen, GSM)",
        "iPad3,6": "iPad (4th Gen, GSM/CDMA)",
        "iPad6,11": "iPad (5th Gen, Wi-Fi)",
        "iPad6,12": "iPad (5th Gen, Cellular)",
        "iPad7,5": "iPad (6th Gen, Wi-Fi)",
        "iPad7,6": "iPad (6th Gen, Cellular)",
        "iPad7,11": "iPad (7th Gen, Wi-Fi)",
        "iPad7,12": "iPad (7th Gen, Cellular)",
        "iPad11,6": "iPad (8th Gen, Wi-Fi)",
        "iPad11,7": "iPad (8th Gen, Cellular)",
        "iPad12,1": "iPad (9th Gen, Wi-Fi)",
        "iPad12,2": "iPad (9th Gen, Cellular)",
        "iPad13,18": "iPad (10th Gen, Wi-Fi)",
        "iPad13,19": "iPad (10th Gen, Cellular)",

        // iPad Air
        "iPad4,1": "iPad Air (Wi-Fi)",
        "iPad4,2": "iPad Air (Cellular)",
        "iPad4,3": "iPad Air (China)",
        "iPad5,3": "iPad Air 2 (Wi-Fi)",
        "iPad5,4": "iPad Air 2 (Cellular)",
        "iPad11,3": "iPad Air (3rd Gen, Wi-Fi)",
        "iPad11,4": "iPad Air (3rd Gen, Cellular)",
        "iPad13,1": "iPad Air (4th Gen, Wi-Fi)",
        "iPad13,2": "iPad Air (4th Gen, Cellular)",
        "iPad13,16": "iPad Air (5th Gen, Wi-Fi)",
        "iPad13,17": "iPad Air (5th Gen, Cellular)",

        // iPad Mini
        "iPad2,5": "iPad Mini (Wi-Fi)",
        "iPad2,6": "iPad Mini (GSM)",
        "iPad2,7": "iPad Mini (GSM/CDMA)",
        "iPad4,4": "iPad Mini 2 (Wi-Fi)",
        "iPad4,5": "iPad Mini 2 (Cellular)",
        "iPad4,6": "iPad Mini 2 (China)",
        "iPad4,7": "iPad Mini 3 (Wi-Fi)",
        "iPad4,8": "iPad Mini 3 (Cellular)",
        "iPad4,9": "iPad Mini 3 (China)",
        "iPad5,1": "iPad Mini 4 (Wi-Fi)",
        "iPad5,2": "iPad Mini 4 (Cellular)",
        "iPad11,1": "iPad Mini (5th Gen, Wi-Fi)",
        "iPad11,2": "iPad Mini (5th Gen, Cellular)",
        "iPad14,1": "iPad Mini (6th Gen, Wi-Fi)",
        "iPad14,2": "iPad Mini (6th Gen, Cellular)",

        // iPad Pro
        "iPad6,3": "iPad Pro (9.7-inch, Wi-Fi)",
        "iPad6,4": "iPad Pro (9.7-inch, Cellular)",
        "iPad6,7": "iPad Pro (12.9-inch, Wi-Fi)",
        "iPad6,8": "iPad Pro (12.9-inch, Cellular)",
        "iPad7,1": "iPad Pro (12.9-inch, 2nd Gen, Wi-Fi)",
        "iPad7,2": "iPad Pro (12.9-inch, 2nd Gen, Cellular)",
        "iPad7,3": "iPad Pro (10.5-inch, Wi-Fi)",
        "iPad7,4": "iPad Pro (10.5-inch, Cellular)",
        "iPad8,1": "iPad Pro (11-inch, 1st Gen, Wi-Fi)",
        "iPad8,2": "iPad Pro (11-inch, 1st Gen, Wi-Fi, 1TB)",
        "iPad8,3": "iPad Pro (11-inch, 1st Gen, Cellular)",
        "iPad8,4": "iPad Pro (11-inch, 1st Gen, Cellular, 1TB)",
        "iPad8,5": "iPad Pro (12.9-inch, 3rd Gen, Wi-Fi)",
        "iPad8,6": "iPad Pro (12.9-inch, 3rd Gen, Wi-Fi, 1TB)",
        "iPad8,7": "iPad Pro (12.9-inch, 3rd Gen, Cellular)",
        "iPad8,8": "iPad Pro (12.9-inch, 3rd Gen, Cellular, 1TB)",
        "iPad8,9": "iPad Pro (11-inch, 2nd Gen, Wi-Fi)",
        "iPad8,10": "iPad Pro (11-inch, 2nd Gen, Cellular)",
        "iPad8,11": "iPad Pro (12.9-inch, 4th Gen, Wi-Fi)",
        "iPad8,12": "iPad Pro (12.9-inch, 4th Gen, Cellular)",
        "iPad13,4": "iPad Pro (11-inch, 3rd Gen, Wi-Fi)",
        "iPad13,5": "iPad Pro (11-inch, 3rd Gen, Cellular)",
        "iPad13,6": "iPad Pro (11-inch, 3rd Gen, Cellular)",
        "iPad13,7": "iPad Pro (11-inch, 3rd Gen, Cellular)",
        "iPad13,8": "iPad Pro (12.9-inch, 5th Gen, Wi-Fi)",
        "iPad13,9": "iPad Pro (12.9-inch, 5th Gen, Cellular)",
        "iPad13,10": "iPad Pro (12.9-inch, 5th Gen, Cellular)",
        "iPad13,11": "iPad Pro (12.9-inch, 5th Gen, Cellular)",
        "iPad14,3": "iPad Pro (11-inch, 4th Gen, Wi-Fi)",
        "iPad14,4": "iPad Pro (11-inch, 4th Gen, Cellular)",
        "iPad14,5": "iPad Pro (12.9-inch, 6th Gen, Wi-Fi)",
        "iPad14,6": "iPad Pro (12.9-inch, 6th Gen, Cellular)",

        // iPod
        "iPod1,1": "iPod Touch",
        "iPod2,1": "iPod Touch (2nd Gen)",
        "iPod3,1": "iPod Touch (3rd Gen)",
        "iPod4,1": "iPod Touch (4th Gen)",
        "iPod5,1": "iPod Touch (5th Gen)",
        "iPod7,1": "iPod Touch (6th Gen)",
        "iPod9,1": "iPod Touch (7th Gen)",
    ]
}
