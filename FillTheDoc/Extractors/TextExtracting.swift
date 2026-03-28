//
//  TextExtracting.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 10.02.2026.
//


import Foundation

protocol TextExtracting {
    func extract(from url: URL) throws -> RawExtractionOutput
}
