//
//  GRotationFilter.swift
//  imageprocessing02
//
//  Created by C.H Lee on 13/05/2018.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import Foundation
import Metal

class GRotationFilter: GImageFilter {
    
    init?(context: GContext) {
        super.init(functionName: "rotation_around_center", context: context)
    }
}
