//
//  GTextureProvider.swift
//  imageprocessing01
//
//  Created by LEE CHUL HYUN on 5/11/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import Foundation
import Metal

protocol GTextureProvider {
    var texture: MTLTexture! {get}
}

protocol GTextureConsumer {
    var provider: GTextureProvider! {get set}
}
