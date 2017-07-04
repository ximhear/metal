//
//  UIColor-extension.swift
//  light
//
//  Created by LEE CHUL HYUN on 7/5/17.
//  Copyright © 2017 LEE CHUL HYUN. All rights reserved.
//

import Foundation
import UIKit

extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    convenience init(netHex:Int) {
        self.init(red:(netHex >> 16) & 0xff, green:(netHex >> 8) & 0xff, blue:netHex & 0xff)
    }
}

extension UIColor {
    struct FlatColor {
        struct Green {
            static let Fern = UIColor(netHex: 0x6ABB72)
            static let MountainMeadow = UIColor(netHex: 0x3ABB9D)
            static let ChateauGreen = UIColor(netHex: 0x4DA664)
            static let PersianGreen = UIColor(netHex: 0x2CA786)
        }
        
        struct Blue {
            static let PictonBlue = UIColor(netHex: 0x5CADCF)
            static let Mariner = UIColor(netHex: 0x3585C5)
            static let CuriousBlue = UIColor(netHex: 0x4590B6)
            static let Denim = UIColor(netHex: 0x2F6CAD)
            static let Chambray = UIColor(netHex: 0x485675)
            static let BlueWhale = UIColor(netHex: 0x29334D)
        }
        
        struct Violet {
            static let Wisteria = UIColor(netHex: 0x9069B5)
            static let BlueGem = UIColor(netHex: 0x533D7F)
        }
        
        struct Yellow {
            static let Energy = UIColor(netHex: 0xF2D46F)
            static let Turbo = UIColor(netHex: 0xF7C23E)
        }
        
        struct Orange {
            static let NeonCarrot = UIColor(netHex: 0xF79E3D)
            static let Sun = UIColor(netHex: 0xEE7841)
        }
        
        struct Red {
            static let TerraCotta = UIColor(netHex: 0xE66B5B)
            static let Valencia = UIColor(netHex: 0xCC4846)
            static let Cinnabar = UIColor(netHex: 0xDC5047)
            static let WellRead = UIColor(netHex: 0xB33234)
        }
        
        struct Gray {
            static let AlmondFrost = UIColor(netHex: 0xA28F85)
            static let WhiteSmoke = UIColor(netHex: 0xEFEFEF)
            static let Iron = UIColor(netHex: 0xD1D5D8)
            static let IronGray = UIColor(netHex: 0x75706B)
        }
    }
    
    static func getRandomColor() -> UIColor {
        let colors = [
            UIColor.FlatColor.Green.Fern,
            UIColor.FlatColor.Green.MountainMeadow,
            UIColor.FlatColor.Green.ChateauGreen,
            UIColor.FlatColor.Green.PersianGreen,
            
            UIColor.FlatColor.Blue.PictonBlue,
            UIColor.FlatColor.Blue.Mariner,
            UIColor.FlatColor.Blue.CuriousBlue,
            UIColor.FlatColor.Blue.Denim,
            UIColor.FlatColor.Blue.Chambray,
            UIColor.FlatColor.Blue.BlueWhale,
            
            UIColor.FlatColor.Violet.Wisteria,
            UIColor.FlatColor.Violet.BlueGem,
            
            UIColor.FlatColor.Yellow.Energy,
            UIColor.FlatColor.Yellow.Turbo,
            
            UIColor.FlatColor.Orange.NeonCarrot,
            UIColor.FlatColor.Orange.Sun,
            
            UIColor.FlatColor.Red.TerraCotta,
            UIColor.FlatColor.Red.Valencia,
            UIColor.FlatColor.Red.Cinnabar,
            UIColor.FlatColor.Red.WellRead,
            
            UIColor.FlatColor.Gray.AlmondFrost,
            UIColor.FlatColor.Gray.WhiteSmoke,
            UIColor.FlatColor.Gray.Iron,
            UIColor.FlatColor.Gray.IronGray,
        ]
        
        let index = Int(arc4random_uniform(UInt32(colors.count)))
        return colors[index]
    }
}
