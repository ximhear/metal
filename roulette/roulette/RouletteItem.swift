//
//  RouletteItem.swift
//  roulette
//
//  Created by LEE CHUL HYUN on 9/11/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import Foundation
import UIKit

class RouletteItem {
    let text: String
    let color: simd_float4
    var scaleX: Float
    var scaleY: Float
    var fontTexture: MTLTexture?
    var textColor: simd_float4
    var bgColor: simd_float4

    init(text: String, color: simd_float4, textColor: simd_float4, bgColor: simd_float4) {
        self.text = text
        self.color = color
        scaleX = 1
        scaleY = 1
        self.textColor = textColor
        self.bgColor = bgColor
    }
}
