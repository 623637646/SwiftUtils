//
//  CodableExtension.swift
//  OneKey-Swift
//
//  Created by Wang Ya on 22/9/23.
//

import Foundation

// MARK: Dictionary from or to Model
extension [AnyHashable : Any] {
    
    func into<T: Decodable>() throws -> T {
        let data = try JSONSerialization.data(withJSONObject: self)
        return try JSONDecoder().decode(T.self, from: data)
    }

}

extension Encodable {
    
    func toDictionary() throws -> [AnyHashable : Any] {
        let data = try JSONEncoder().encode(self)
        return try JSONSerialization.jsonObject(with: data) as! [AnyHashable : Any]
    }
    
}

// MARK: Array from or to Models
extension [[AnyHashable : Any]] {
    
    func into<T: Decodable>() throws -> [T] {
        let data = try JSONSerialization.data(withJSONObject: self)
        return try JSONDecoder().decode([T].self, from: data)
    }
    
}

extension Array where Element: Encodable {

    func toArray() throws -> [[AnyHashable : Any]] {
        let data = try JSONEncoder().encode(self)
        return try JSONSerialization.jsonObject(with: data) as! [[AnyHashable : Any]]
    }

}
