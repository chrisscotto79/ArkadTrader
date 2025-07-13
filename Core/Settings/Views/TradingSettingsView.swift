//
//  TradingSettingsView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/12/25.
//


// File: Core/Settings/Views/TradingSettingsView.swift

import SwiftUI

struct TradingSettingsView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    // Trading preferences stored in UserDefaults
    @AppStorage("auto_calculate_position_size") private var autoCalculatePositionSize = true
    @AppStorage("default_position_size_percent") private var defaultPositionSizePercent = 5.0
    @AppStorage("max_daily_loss_percent") private var maxDailyLossPercent = 10.0
    @AppStorage("default_stop_loss_percent") private var defaultStopLossPercent = 5.0
    @AppStorage("default_take_profit_percent") private var defaultTakeProfitPercent = 10.0
    
    // Risk management
    @AppStorage("enable_risk_warnings") private var enableRiskWarnings = true
    @AppStorage("require_confirmation_large_trades") private var requireConfirmationLargeTrades = true
    @AppStorage("large_trade_threshold") private var largeTradeThreshold = 1000.0
    
    // Display preferences
    @AppStorage("show_unrealized_pnl") private var showUnrealizedPnL = true
    @AppStorage("show_daily_pnl") private var showDailyPnL = true
    @AppStorage("default_chart_timeframe") private var defaultChartTimeframe = "1D"
    @AppStorage("auto_refresh_portfolio") private var autoRefreshPortfolio = true
    @AppStorage("refresh_interval_seconds") private var refreshIntervalSeconds = 30.0
    
    // Trading journal
    @AppStorage("auto_save_trades") private var autoSaveTrades = true
    @AppStorage("require_trade_notes") private var requireTradeNotes = false
    @AppStorage("enable_trade_screenshots") private var enableTradeScreenshots = true
    
    private let chartTimeframes = ["1m", "5m", "15m", "1H", "4H", "1D", "1W"]
    private let refreshIntervals = [5.0, 10.0, 15.0, 30.0, 60.0]
    
    var body: some View {
        NavigationView {
            List {
                // Position Management
                positionManagementSection
                
                // Risk Management
                riskManagementSection
                
                // Display Preferences
                displayPreferencesSection
                
                // Trading Journal
                tradingJournalSection
                
                // Reset Settings
                resetSettingsSection
            }
            .navigationTitle("Trading Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.arkadGold)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Position Management Section
    private var positionManagementSection: some View {
        Section("Position Management") {
            tradingToggle(
                title: "Auto Calculate Position Size",
                description: "Automatically calculate position size based on risk percentage",
                icon: "percent",
                color: .green,
                isOn: $autoCalculatePositionSize
            )
            
            if autoCalculatePositionSize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "chart.pie")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default Position Size")
                                .fontWeight(.medium)
                            Text("Percentage of portfolio per trade")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Text("\(defaultPositionSizePercent, specifier: "%.1f")%")
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                    }
                    
                    Slider(value: $defaultPositionSizePercent, in: 1...20, step: 0.5)
                        .accentColor(.green)
                }
                .padding(.vertical, 4)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default Stop Loss")
                            .fontWeight(.medium)
                        Text("Percentage below entry price")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text("\(defaultStopLossPercent, specifier: "%.1f")%")
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                }
                
                Slider(value: $defaultStopLossPercent, in: 1...15, step: 0.5)
                    .accentColor(.red)
            }
            .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.up.circle")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default Take Profit")
                            .fontWeight(.medium)
                        Text("Percentage above entry price")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text("\(defaultTakeProfitPercent, specifier: "%.1f")%")
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
                
                Slider(value: $defaultTakeProfitPercent, in: 5...50, step: 1.0)
                    .accentColor(.green)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Risk Management Section
    private var riskManagementSection: some View {
        Section("Risk Management") {
            tradingToggle(
                title: "Risk Warnings",
                description: "Show warnings for high-risk trades",
                icon: "exclamationmark.triangle",
                color: .orange,
                isOn: $enableRiskWarnings
            )
            
            tradingToggle(
                title: "Large Trade Confirmations",
                description: "Require confirmation for trades above threshold",
                icon: "checkmark.shield",
                color: .orange,
                isOn: $requireConfirmationLargeTrades
            )
            
            if requireConfirmationLargeTrades {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "dollarsign.circle")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Large Trade Threshold")
                                .fontWeight(.medium)
                            Text("Dollar amount requiring confirmation")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Text("$\(largeTradeThreshold, specifier: "%.0f")")
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                    }
                    
                    Slider(value: $largeTradeThreshold, in: 100...10000, step: 100)
                        .accentColor(.orange)
                }
                .padding(.vertical, 4)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "hand.raised")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Max Daily Loss")
                            .fontWeight(.medium)
                        Text("Stop trading after this percentage loss")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text("\(maxDailyLossPercent, specifier: "%.1f")%")
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                }
                
                Slider(value: $maxDailyLossPercent, in: 5...25, step: 1.0)
                    .accentColor(.red)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Display Preferences Section
    private var displayPreferencesSection: some View {
        Section("Display Preferences") {
            tradingToggle(
                title: "Show Unrealized P&L",
                description: "Display profit/loss for open positions",
                icon: "chart.line.uptrend.xyaxis",
                color: .blue,
                isOn: $showUnrealizedPnL
            )
            
            tradingToggle(
                title: "Show Daily P&L",
                description: "Display today's profit/loss",
                icon: "calendar",
                color: .blue,
                isOn: $showDailyPnL
            )
            
            tradingToggle(
                title: "Auto Refresh Portfolio",
                description: "Automatically update portfolio data",
                icon: "arrow.clockwise",
                color: .blue,
                isOn: $autoRefreshPortfolio
            )
            
            // Chart timeframe picker
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Default Chart Timeframe")
                        .fontWeight(.medium)
                    Text("Default timeframe for price charts")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Picker("Timeframe", selection: $defaultChartTimeframe) {
                    ForEach(chartTimeframes, id: \.self) { timeframe in
                        Text(timeframe).tag(timeframe)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            .padding(.vertical, 4)
            
            if autoRefreshPortfolio {
                // Refresh interval picker
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Refresh Interval")
                            .fontWeight(.medium)
                        Text("How often to update data")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Picker("Interval", selection: $refreshIntervalSeconds) {
                        ForEach(refreshIntervals, id: \.self) { interval in
                            Text("\(Int(interval))s").tag(interval)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Trading Journal Section
    private var tradingJournalSection: some View {
        Section("Trading Journal") {
            tradingToggle(
                title: "Auto Save Trades",
                description: "Automatically save trades to journal",
                icon: "square.and.arrow.down",
                color: .purple,
                isOn: $autoSaveTrades
            )
            
            tradingToggle(
                title: "Require Trade Notes",
                description: "Mandatory notes for each trade",
                icon: "note.text",
                color: .purple,
                isOn: $requireTradeNotes
            )
            
            tradingToggle(
                title: "Enable Trade Screenshots",
                description: "Allow attaching screenshots to trades",
                icon: "camera",
                color: .purple,
                isOn: $enableTradeScreenshots
            )
        }
    }
    
    // MARK: - Reset Settings Section
    private var resetSettingsSection: some View {
        Section("Reset") {
            Button(action: resetToDefaults) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset to Defaults")
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                        Text("Restore all trading preferences to default values")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Helper Views
    
    private func tradingToggle(
        title: String,
        description: String,
        icon: String,
        color: Color,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(.medium)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func resetToDefaults() {
        autoCalculatePositionSize = true
        defaultPositionSizePercent = 5.0
        maxDailyLossPercent = 10.0
        defaultStopLossPercent = 5.0
        defaultTakeProfitPercent = 10.0
        enableRiskWarnings = true
        requireConfirmationLargeTrades = true
        largeTradeThreshold = 1000.0
        showUnrealizedPnL = true
        showDailyPnL = true
        defaultChartTimeframe = "1D"
        autoRefreshPortfolio = true
        refreshIntervalSeconds = 30.0
        autoSaveTrades = true
        requireTradeNotes = false
        enableTradeScreenshots = true
    }
}

#Preview {
    TradingSettingsView()
        .environmentObject(FirebaseAuthService.shared)
}