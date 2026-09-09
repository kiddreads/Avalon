//
//  SelectedSnapshot.swift
//  Folium
//
//  Created by Jarrod Norwell on 21/6/2026.
//

enum SelectedSnapshot : Int {
    case application, cherry, cytrus, durian, grape, kiwi, lychee, mandarine, mango, plum, tomato
    
    var string: String {
        switch self {
        case .application:
            "Application"
        case .cherry:
            "Cherry"
        case .cytrus:
            "Cytrus"
        case .durian:
            "Durian"
        case .grape:
            "Grape"
        case .kiwi:
            "Kiwi"
        case .lychee:
            "Lychee"
        case .mandarine:
            "Mandarine"
        case .mango:
            "Mango"
        case .plum:
            "Plum"
        case .tomato:
            "Tomato"
        }
    }
    
    var system: System? {
        switch self {
        case .application:
            nil
        case .cherry:
            System.cherry
        case .cytrus:
            System.cytrus
        case .durian:
            System.durian
        case .grape:
            System.grape
        case .kiwi:
            System.kiwi
        case .lychee:
            System.lychee
        case .mandarine:
            System.mandarine
        case .mango:
            System.mango
        case .plum:
            System.plum
        case .tomato:
            System.tomato
        }
    }
    
    var valid: Bool {
        neq(.application)
    }
    
    private func neq(_ value: SelectedSnapshot) -> Bool {
        self != value
    }
}
