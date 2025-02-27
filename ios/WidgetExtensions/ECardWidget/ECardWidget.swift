//
//  ECardWidget.swift
//  WidgetExtensions
//
//  Created by 施子捷 on 2024/7/8.
//

import SwiftUI
import WidgetKit

struct ECardEntry: TimelineEntry {
    let date: Date
    let balance: Int
}

struct ECardWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ECardEntry {
        ECardEntry(date: Date(), balance: 1897)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ECardEntry) -> Void) {
        completion(ECardEntry(date: Date(), balance: 1897))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    #if DEBUG
        let accessGroup = "group.top.celechron.celechron.debug"
    #else
        let accessGroup = "group.top.celechron.celechron"
    #endif
        let keychainQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrAccount: "synjonesAuth",
            kSecAttrAccessGroup: accessGroup,
            kSecAttrService: "Celechron",
            kSecAttrSynchronizable: false,
            kSecReturnData: true,
        ]
        var ref: AnyObject?
        let status = SecItemCopyMatching(
            keychainQuery as CFDictionary,
            &ref
        )
        if (status == errSecItemNotFound) {
            completion(Timeline(entries: [ECardEntry(date: Date(), balance: -1)], policy: .after(Date(timeIntervalSinceNow: 1800))))
            return
        }
        
        var value: String? = nil
        if (status == noErr) {
            value = String(data: ref as! Data, encoding: .utf8)
        }
        
        if(value == nil) {
            completion(Timeline(entries: [ECardEntry(date: Date(), balance: -1)], policy: .after(Date(timeIntervalSinceNow: 1800))))
            return
        }
        
        var request = URLRequest(url: URL(string: "https://ecard.zju.edu.cn/berserker-app/ykt/tsm/getCampusCards")!)
        request.httpMethod = "GET"
        request.addValue("Bearer " + value!, forHTTPHeaderField: "Synjones-Auth")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0", forHTTPHeaderField: "User-Agent")

        let semaphore = DispatchSemaphore(value: 0)
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 10
        let sessionWithDelegate = URLSession(configuration: sessionConfig, delegate:nil , delegateQueue:nil )

        var responseData : Data?
        var responseError : Error?
        sessionWithDelegate.dataTask(with: request) { (data, response, error) in
            responseData=data
            responseError=error
            semaphore.signal()
        }.resume()

        semaphore.wait()

        // Check for errors and process data or handle any errors
        if responseError != nil {
            return
        } else if let data=responseData {
            do {
                if let jsonDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    let data = jsonDict["data"] as? [String: Any]
                    if(data == nil) { return }
                    let cardList = data!["card"] as? [[String: Any]]
                    if(cardList == nil) { return }
                    let balanceList = cardList!.map { card in card["db_balance"] as! Int }
                    let balance = balanceList.max()
                    if(balance == nil) { return }
                    completion(Timeline(entries: [ECardEntry(date: Date(), balance: balance!)], policy: .after(Date(timeIntervalSinceNow: 1800))))
                } else {
                    return
                }
            } catch {
                return
            }
        }
    }
}

struct ECardWidget: Widget {
    let kind: String = "ECardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ECardWidgetProvider()) { entry in
            ECardWidgetView(entry: entry)
                .widgetBackground(Color(UIColor.tertiarySystemFill))
        }.supportedFamilies([.systemSmall])
    }
}

struct ECardWidgetView: View {
    let entry: ECardWidgetProvider.Entry
    
    var body: some View {
        let balanceString = entry.balance > 0 ? 
                                entry.balance < 10000 ?
        String(format: "%d.%d%d元", arguments: [entry.balance / 100, entry.balance % 100 / 10, entry.balance % 10])
                                  : String(format: "%d.%d元", arguments: [entry.balance / 100, entry.balance % 100 / 10])
                            : "待刷新"
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "creditcard")
                Spacer().frame(width: 4)
                Text("校园卡余额")
                    .font(.footnote).bold()
            }
            
            Spacer().frame(height: 8)
            
            if #available(iOSApplicationExtension 16.1, *) {
                Text(balanceString).font(.title).bold()
                    .fontDesign(.rounded)
            } else {
                Text(balanceString).font(.title.bold())
            }
            
            Spacer().frame(height: 16)
            
            
            HStack(alignment:.top) {
                Text("更新时间: " + entry.date.HHmm()).font(.caption2).foregroundColor(.secondary)
                Spacer()
                Image(systemName: "qrcode").foregroundColor(/*@START_MENU_TOKEN@*/.blue/*@END_MENU_TOKEN@*/).font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
            }
        }.widgetURL(URL(string: "celechron://ecardpaypage"))
    }
}

extension Date {
    func HHmm(withFormat format: String = "HH:mm") -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
    }
}

@available(iOS 18.0, *)
#Preview(as: .systemSmall) {
    ECardWidget()
} timeline: {
    ECardEntry(date: Date(), balance: 1888)
}
