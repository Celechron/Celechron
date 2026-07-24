//
//  SimpleQRCode.swift
//  CelechronWatch
//
//  watchOS 纯 Swift 二维码（Version 1–2，Byte 模式，纠错 M）。
//

import Foundation
import UIKit

enum SimpleQRCode {
    static func image(from text: String, size: CGFloat) -> UIImage? {
        guard let modules = encode(text) else { return nil }
        let n = modules.count
        let scale = max(1, Int(floor(size / CGFloat(n))))
        let px = n * scale
        // watchOS 无 UIGraphicsImageRenderer，使用 CGBitmapContext
        let bytesPerRow = px * 4
        guard let ctx = CGContext(
            data: nil,
            width: px,
            height: px,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: px, height: px))
        ctx.setFillColor(UIColor.black.cgColor)
        for y in 0 ..< n {
            for x in 0 ..< n where modules[y][x] {
                // CG 坐标系 y 轴向上，翻转绘制
                ctx.fill(
                    CGRect(
                        x: x * scale,
                        y: (n - 1 - y) * scale,
                        width: scale,
                        height: scale
                    )
                )
            }
        }
        guard let cgImage = ctx.makeImage() else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Encode

    private static func encode(_ text: String) -> [[Bool]]? {
        let bytes = Array(text.utf8)
        // Version 1 (M): 14 data bytes; Version 2 (M): 26 data bytes
        let version: Int
        if bytes.count <= 14 {
            version = 1
        } else if bytes.count <= 26 {
            version = 2
        } else {
            // 过长则截断到 26 字节
            return encode(String(text.prefix(26)))
        }

        let size = 17 + 4 * version
        // Total codewords / EC codewords for ECC=M
        let (totalCW, ecCW): (Int, Int) = version == 1 ? (26, 10) : (44, 16)
        // Wait - ISO tables for M:
        // V1 M: total 26 codewords, 10 EC → 16 data
        // V2 M: total 44 codewords, 16 EC → 28 data
        // Capacity bytes for byte mode ≈ data codewords - mode/count overhead
        let dataCW = totalCW - ecCW // 16 or 28

        var bits: [Bool] = []
        bits += bitsOf(0b0100, length: 4) // Byte mode
        bits += bitsOf(bytes.count, length: 8) // count (v1-9)
        for b in bytes {
            bits += bitsOf(Int(b), length: 8)
        }
        // Terminator up to 4 bits
        let capacityBits = dataCW * 8
        let termLen = min(4, capacityBits - bits.count)
        if termLen > 0 { bits += Array(repeating: false, count: termLen) }
        while bits.count % 8 != 0 { bits.append(false) }

        var dataCodewords: [UInt8] = []
        for i in stride(from: 0, to: bits.count, by: 8) {
            var v: UInt8 = 0
            for j in 0 ..< 8 where bits[i + j] {
                v |= 1 << (7 - j)
            }
            dataCodewords.append(v)
        }
        let pad: [UInt8] = [0xEC, 0x11]
        var pi = 0
        while dataCodewords.count < dataCW {
            dataCodewords.append(pad[pi % 2])
            pi += 1
        }

        let ec = rsEncode(dataCodewords, ecCount: ecCW)
        let all = dataCodewords + ec

        var modules = Array(repeating: Array(repeating: false, count: size), count: size)
        var reserved = Array(repeating: Array(repeating: false, count: size), count: size)

        drawFinders(&modules, &reserved, size: size)
        drawSeparators(&modules, &reserved, size: size)
        drawTiming(&modules, &reserved, size: size)
        drawDarkModule(&modules, &reserved, version: version)
        if version >= 2 {
            drawAlignment(&modules, &reserved, size: size)
        }
        reserveFormat(&reserved, size: size)

        placeDataBits(&modules, reserved: reserved, codewords: all, size: size)

        let maskID = 0
        applyMask(&modules, reserved: reserved, mask: maskID, size: size)
        drawFormatBits(&modules, mask: maskID, size: size)

        // Quiet zone (1 module)
        let q = size + 2
        var out = Array(repeating: Array(repeating: false, count: q), count: q)
        for y in 0 ..< size {
            for x in 0 ..< size {
                out[y + 1][x + 1] = modules[y][x]
            }
        }
        return out
    }

    private static func bitsOf(_ value: Int, length: Int) -> [Bool] {
        (0 ..< length).map { ((value >> (length - 1 - $0)) & 1) == 1 }
    }

    // MARK: - Patterns

    private static func drawFinders(
        _ m: inout [[Bool]], _ r: inout [[Bool]], size: Int
    ) {
        func finder(_ ox: Int, _ oy: Int) {
            for dy in 0 ..< 7 {
                for dx in 0 ..< 7 {
                    let dark = dx == 0 || dx == 6 || dy == 0 || dy == 6
                        || (dx >= 2 && dx <= 4 && dy >= 2 && dy <= 4)
                    m[oy + dy][ox + dx] = dark
                    r[oy + dy][ox + dx] = true
                }
            }
        }
        finder(0, 0)
        finder(size - 7, 0)
        finder(0, size - 7)
    }

    private static func drawSeparators(
        _ m: inout [[Bool]], _ r: inout [[Bool]], size: Int
    ) {
        // White separators around finders
        for i in 0 ..< 8 {
            if i < size {
                setReservedWhite(&m, &r, x: 7, y: i)
                setReservedWhite(&m, &r, x: i, y: 7)
                setReservedWhite(&m, &r, x: size - 8, y: i)
                setReservedWhite(&m, &r, x: size - 1 - i, y: 7)
                setReservedWhite(&m, &r, x: 7, y: size - 1 - i)
                setReservedWhite(&m, &r, x: i, y: size - 8)
            }
        }
    }

    private static func setReservedWhite(
        _ m: inout [[Bool]], _ r: inout [[Bool]], x: Int, y: Int
    ) {
        guard y >= 0, x >= 0, y < m.count, x < m.count else { return }
        m[y][x] = false
        r[y][x] = true
    }

    private static func drawTiming(
        _ m: inout [[Bool]], _ r: inout [[Bool]], size: Int
    ) {
        for i in 0 ..< size {
            if !r[6][i] {
                m[6][i] = i % 2 == 0
                r[6][i] = true
            }
            if !r[i][6] {
                m[i][6] = i % 2 == 0
                r[i][6] = true
            }
        }
    }

    private static func drawDarkModule(
        _ m: inout [[Bool]], _ r: inout [[Bool]], version: Int
    ) {
        let y = 4 * version + 9
        m[y][8] = true
        r[y][8] = true
    }

    private static func drawAlignment(
        _ m: inout [[Bool]], _ r: inout [[Bool]], size: Int
    ) {
        // Version 2 alignment center = 6? Actually centers: [6, 18] for v2, but avoid finder overlap.
        // Only place at (18,18) for 25x25.
        let c = size - 7
        for dy in -2 ... 2 {
            for dx in -2 ... 2 {
                let x = c + dx
                let y = c + dy
                if r[y][x] { continue }
                m[y][x] = abs(dx) == 2 || abs(dy) == 2 || (dx == 0 && dy == 0)
                r[y][x] = true
            }
        }
    }

    private static func reserveFormat(_ r: inout [[Bool]], size: Int) {
        for i in 0 ... 8 {
            r[8][i] = true
            r[i][8] = true
            r[8][size - 1 - i] = true
            r[size - 1 - i][8] = true
        }
    }

    private static func placeDataBits(
        _ m: inout [[Bool]], reserved: [[Bool]], codewords: [UInt8], size: Int
    ) {
        var bits: [Bool] = []
        for b in codewords {
            bits += bitsOf(Int(b), length: 8)
        }
        var idx = 0
        var up = true
        var x = size - 1
        while x > 0 {
            if x == 6 { x -= 1 }
            let ys = up ? Array(stride(from: size - 1, through: 0, by: -1))
                : Array(0 ..< size)
            for y in ys {
                for dx in [0, -1] {
                    let xx = x + dx
                    if reserved[y][xx] { continue }
                    m[y][xx] = idx < bits.count ? bits[idx] : false
                    idx += 1
                }
            }
            up.toggle()
            x -= 2
        }
    }

    private static func applyMask(
        _ m: inout [[Bool]], reserved: [[Bool]], mask: Int, size: Int
    ) {
        for y in 0 ..< size {
            for x in 0 ..< size where !reserved[y][x] {
                let flip: Bool
                switch mask {
                case 0: flip = (x + y) % 2 == 0
                case 1: flip = y % 2 == 0
                default: flip = false
                }
                if flip { m[y][x].toggle() }
            }
        }
    }

    /// Format info: ECC level M (00) + mask id, BCH(15,5), XOR mask 0x5412
    private static func drawFormatBits(_ m: inout [[Bool]], mask: Int, size: Int) {
        // ECC M = 00 per ISO/IEC 18004
        let data = (0b00 << 3) | (mask & 0b111)
        var d = data << 10
        let poly = 0b10100110111
        for i in stride(from: 14, through: 10, by: -1) {
            if (d & (1 << i)) != 0 {
                d ^= poly << (i - 10)
            }
        }
        let bits = ((data << 10) | d) ^ 0b101010000010010

        func bit(_ i: Int) -> Bool { ((bits >> (14 - i)) & 1) == 1 }

        // Around top-left
        let map: [(Int, Int)] = [
            (0, 8), (1, 8), (2, 8), (3, 8), (4, 8), (5, 8), (7, 8), (8, 8),
            (8, 7), (8, 5), (8, 4), (8, 3), (8, 2), (8, 1), (8, 0),
        ]
        for (i, p) in map.enumerated() {
            m[p.1][p.0] = bit(i)
        }
        // Other copy
        let map2: [(Int, Int)] = [
            (size - 1, 8), (size - 2, 8), (size - 3, 8), (size - 4, 8),
            (size - 5, 8), (size - 6, 8), (size - 7, 8),
            (8, size - 8), (8, size - 7), (8, size - 6), (8, size - 5),
            (8, size - 4), (8, size - 3), (8, size - 2), (8, size - 1),
        ]
        for (i, p) in map2.enumerated() {
            m[p.1][p.0] = bit(i)
        }
    }

    // MARK: - Reed-Solomon (GF(256), poly 0x11D)

    private static func rsEncode(_ data: [UInt8], ecCount: Int) -> [UInt8] {
        var generator: [UInt8] = [1]
        for i in 0 ..< ecCount {
            generator = polyMul(generator, [1, gfPow(2, i)])
        }
        var msg = data + [UInt8](repeating: 0, count: ecCount)
        for i in 0 ..< data.count {
            let coef = msg[i]
            if coef == 0 { continue }
            for j in 0 ..< generator.count {
                msg[i + j] ^= gfMul(generator[j], coef)
            }
        }
        return Array(msg.suffix(ecCount))
    }

    private static func polyMul(_ a: [UInt8], _ b: [UInt8]) -> [UInt8] {
        var r = [UInt8](repeating: 0, count: a.count + b.count - 1)
        for i in 0 ..< a.count {
            for j in 0 ..< b.count {
                r[i + j] ^= gfMul(a[i], b[j])
            }
        }
        return r
    }

    private static func gfMul(_ x: UInt8, _ y: UInt8) -> UInt8 {
        if x == 0 || y == 0 { return 0 }
        return expTable[Int(logTable[Int(x)]) + Int(logTable[Int(y)])]
    }

    private static func gfPow(_ x: UInt8, _ p: Int) -> UInt8 {
        var r: UInt8 = 1
        for _ in 0 ..< p { r = gfMul(r, x) }
        return r
    }

    private static let expTable: [UInt8] = {
        var t = [UInt8](repeating: 0, count: 512)
        var x: UInt8 = 1
        for i in 0 ..< 255 {
            t[i] = x
            let hi = (x & 0x80) != 0
            x <<= 1
            if hi { x ^= 0x1D }
        }
        for i in 255 ..< 512 { t[i] = t[i - 255] }
        return t
    }()

    private static let logTable: [UInt8] = {
        var t = [UInt8](repeating: 0, count: 256)
        var x: UInt8 = 1
        for i in 0 ..< 255 {
            t[Int(x)] = UInt8(i)
            let hi = (x & 0x80) != 0
            x <<= 1
            if hi { x ^= 0x1D }
        }
        return t
    }()
}
