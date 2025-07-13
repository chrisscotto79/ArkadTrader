//
//  NewsAnalytics.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/13/25.
//



// File: Shared/Models/NewsAnalytics.swift
import Foundation

struct NewsAnalytics {
    let totalArticles: Int
    let recentArticles: Int
    let topKeywords: [String]
    let lastUpdated: Date
}