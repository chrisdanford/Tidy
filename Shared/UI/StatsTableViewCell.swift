//
//  StatsTableViewCell.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/12/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import UIKit
import Charts

class StatusTableViewCell: UITableViewCell {
    @IBOutlet weak var pieChartView: PieChartView!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!

    func set(photosSizes: Sizes.State) {
        let chartView = pieChartView!
        set(pieChartView: chartView, sizes: photosSizes)
    }

    func set(pieChartView: PieChartView, sizes: Sizes.State) {
        if sizes.isScanning {
            activityIndicatorView.startAnimating()
        } else {
            activityIndicatorView.stopAnimating()
        }

        // Setting this through the Storyboard doesn't seem to have an effect.  Why?
        pieChartView.isUserInteractionEnabled = false

        // Hide the pie chart if there's no data because little bits of visual garbage from the legend will show in the corner.
        if sizes.photos.totalSizeBytes == 0 && sizes.videos.totalSizeBytes == 0 {
            pieChartView.isHidden = true
        } else {
            let photosCountFormatted = sizes.photos.count.formattedDecimalString
            let videoCountFormatted = sizes.videos.count.formattedDecimalString
            let entries: [PieChartDataEntry] = [
                PieChartDataEntry(value: Double(sizes.photos.totalSizeBytes), label: "Photos\n\(photosCountFormatted)", icon: nil),
                PieChartDataEntry(value: Double(sizes.videos.totalSizeBytes), label: "Videos\n\(videoCountFormatted)", icon: nil)
            ]
            
            let dataSet = PieChartDataSet(values: entries, label: "Media Files")
            setupPieChart(dataSet: dataSet)
            
            // unhide the PieChartView when we have our first estimate.  It's hidden initially in the Storyboard.
            pieChartView.isHidden = false
        }
    }
    
    private func setupPieChart(dataSet: PieChartDataSet) {
        //NSLog("pieChartView \(pieChartView)")

        let chartView = pieChartView!
        
        //chartView.usePercentValuesEnabled = true
        chartView.drawSlicesUnderHoleEnabled = false
        chartView.holeRadiusPercent = 0.8
        chartView.transparentCircleRadiusPercent = 0.61
        chartView.chartDescription?.enabled = false
        chartView.setExtraOffsets(left: 5, top: 10, right: 5, bottom: 5)
        
        //chartView.drawCenterTextEnabled = true
        
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.alignment = .center
        
//        let centerText = NSMutableAttributedString(string: "Charts\nby Daniel Cohen Gindi")
//        centerText.setAttributes([.font : UIFont(name: "HelveticaNeue-Light", size: 13)!,
//                                  .paragraphStyle : paragraphStyle], range: NSRange(location: 0, length: centerText.length))
//        centerText.addAttributes([.font : UIFont(name: "HelveticaNeue-Light", size: 11)!,
//                                  .foregroundColor : UIColor.gray], range: NSRange(location: 10, length: centerText.length - 10))
//        centerText.addAttributes([.font : UIFont(name: "HelveticaNeue-Light", size: 11)!,
//                                  .foregroundColor : UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)], range: NSRange(location: centerText.length - 19, length: 19))
//        chartView.centerAttributedText = centerText;
        
        //chartView.drawHoleEnabled = true
        chartView.rotationAngle = 0
        chartView.rotationEnabled = true
        chartView.highlightPerTapEnabled = true
        
        chartView.legend.enabled = false
//        let l = chartView.legend
//        l.horizontalAlignment = .right
//        l.verticalAlignment = .top
//        l.orientation = .vertical
//        l.drawInside = false
//        l.xEntrySpace = 7
//        l.yEntrySpace = 0
//        l.yOffset = 0

        
//        chartView.delegate = self
        
//        let l = chartView.legend
//        l.horizontalAlignment = .right
//        l.verticalAlignment = .top
//        l.orientation = .vertical
//        l.xEntrySpace = 7
//        l.yEntrySpace = 0
//        l.yOffset = 0
        //        chartView.legend = l
        
        // entry label styling
        chartView.entryLabelColor = .red
        chartView.entryLabelFont = .systemFont(ofSize: 12, weight: .light)
        
        chartView.holeColor = UIColor(white: 0, alpha: 0)
        
//        sliderX.value = 4
//        sliderY.value = 100
//        self.slidersValueChanged(nil)
//


        self.setDataCount(set: dataSet)
    }
    
    func setDataCount(set: PieChartDataSet) {
        let chartView = pieChartView!

        set.drawIconsEnabled = false
        set.sliceSpace = 2
        
        set.colors = ChartColorTemplates.vordiplom()
            + ChartColorTemplates.joyful()
            + ChartColorTemplates.colorful()
            + ChartColorTemplates.liberty()
            + ChartColorTemplates.pastel()
            + [UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)]
        
        let data = PieChartData(dataSet: set)
        
//        let pFormatter = NumberFormatter()
//        pFormatter.numberStyle = .percent
//        pFormatter.maximumFractionDigits = 1
//        pFormatter.multiplier = 1
//        pFormatter.percentSymbol = " %"
//        data.setValueFormatter(DefaultValueFormatter(formatter: pFormatter))

        class Formatter : IValueFormatter {
            func stringForValue(_ value: Double,
                                entry: ChartDataEntry,
                                dataSetIndex: Int,
                                viewPortHandler: ViewPortHandler?) -> String {
                return UInt64(value).formattedCompactByteString
            }
        }
        data.setValueFormatter(Formatter())

        data.setValueFont(.preferredFont(forTextStyle: UIFont.TextStyle.caption1))
        data.setValueTextColor(.black)
        
        chartView.data = data
        chartView.highlightValues(nil)
    }
    
    func animate() {
        let chartView = pieChartView!
        chartView.animate(xAxisDuration: 2, easingOption: .easeOutCirc)
    }
}
