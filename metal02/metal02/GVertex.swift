//
//  GVertex.swift
//  metal02
//
//  Created by LEE CHUL HYUN on 4/22/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import Foundation
import simd

struct GVertex {
    let position: vector_float4
    let color: vector_float4
    var texture: float2 = float2(0, 0)
}
