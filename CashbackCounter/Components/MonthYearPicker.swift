//
//  MonthYearPicker.swift
//  CashbackCounter
//
//  Created by Assistant on 12/20/25.
//

import SwiftUI

/// 一个自定义的日期选择器，支持选择"某年某月"或者"某年全年"
struct MonthYearPicker: View {
    // MARK: - Properties
    
    @Binding var date: Date
    @Binding var isWholeYear: Bool
    @Environment(\.dismiss) private var dismiss
    
    // Configuration
    private let yearsRange = 10 // 前后各10年
    private let calendar = Calendar.current
    
    // State
    @State private var selectedYear: Int
    @State private var selectedMonth: Int // 0 表示全年，1-12 表示月份
    
    // Data Sources
    private var availableYears: [Int] {
        let currentYear = calendar.component(.year, from: Date())
        return Array((currentYear - yearsRange)...(currentYear + yearsRange))
    }
    
    private var availableMonths: [Int] {
        Array(0...12) // 0: 全年, 1-12: 月份
    }
    
    // MARK: - Initialization
    
    init(date: Binding<Date>, isWholeYear: Binding<Bool>) {
        self._date = date
        self._isWholeYear = isWholeYear
        
        let initialDate = date.wrappedValue
        let initialYear = Calendar.current.component(.year, from: initialDate)
        let initialMonth = isWholeYear.wrappedValue ? 0 : Calendar.current.component(.month, from: initialDate)
        
        _selectedYear = State(initialValue: initialYear)
        _selectedMonth = State(initialValue: initialMonth)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            pickersView
        }
        .background(Color(uiColor: .systemBackground))
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Button(AppConstants.General.cancel) {
                dismiss()
            }
            .foregroundColor(.secondary)
            
            Spacer()
            
            Text(AppConstants.DateConstants.selectTime)
                .font(.headline)
            
            Spacer()
            
            Button(AppConstants.General.confirm) {
                saveSelection()
                dismiss()
            }
            .fontWeight(.semibold)
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
    }
    
    private var pickersView: some View {
        HStack {
            // Year Picker
            Picker(AppConstants.DateConstants.yearLabel, selection: $selectedYear) {
                ForEach(availableYears, id: \.self) { year in
                    Text(String(format: "%d%@", year, AppConstants.DateConstants.yearSuffix))
                        .tag(year)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            
            // Month Picker
            Picker(AppConstants.DateConstants.monthLabel, selection: $selectedMonth) {
                ForEach(availableMonths, id: \.self) { month in
                    Text(monthString(for: month))
                        .tag(month)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
    
    // MARK: - Logic
    
    private func monthString(for month: Int) -> String {
        if month == 0 {
            return AppConstants.DateConstants.wholeYear
        } else {
            return String(format: "%d%@", month, AppConstants.DateConstants.monthSuffix)
        }
    }
    
    private func saveSelection() {
        var components = DateComponents()
        components.year = selectedYear
        
        if selectedMonth == 0 {
            // 选择了全年
            isWholeYear = true
            components.month = 1 // 默认为1月，方便计算
            components.day = 1
        } else {
            // 选择了具体月份
            isWholeYear = false
            components.month = selectedMonth
            components.day = 1
        }
        
        if let newDate = calendar.date(from: components) {
            date = newDate
        }
    }
}