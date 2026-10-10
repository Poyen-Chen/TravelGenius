import Foundation
import SwiftData
@main struct Golden {
 static func main() throws {
  var rows:[[String]]=[]
  for country in ["JP","KR","US"] { for month in [1,6,10] { for days in [1,5,12] { for style in PackingStyle.allCases { for activities in [[],PackingActivity.allCases,Array(PackingActivity.allCases.reversed())] as [[PackingActivity]] { for laundry in PackingLaundryPlan.allCases {
   let start=Calendar.current.date(from:DateComponents(year:2026,month:month,day:1))!
   let trip=Trip(name:"Golden",countryCode:country,startDate:start,endDate:Calendar.current.date(byAdding:.day,value:days-1,to:start)!,homeCurrencyCode:"TWD",localCurrencyCode:"JPY",totalBudget:0,tripType:.leisure)
   let prefs=UserPreferences(packingStyle:style,devices:PersonalPackingOptions.devices.map(\.id),needs:PersonalPackingOptions.needs.map(\.id))
   for weather in [Set<String>(),["hot"],["cold","rain"],["mild","rain"]] as [Set<String>] {
    let items=PackingListGenerator.generate(for:trip,preferences:prefs,packingContext:TripPackingContext(activities:activities,stays:[.hostel],laundry:laundry),weatherTags:weather)
    rows.append(items.map{"\($0.id)|\($0.name)|\($0.category.rawValue)|\($0.quantity)|\($0.reason)|\($0.sortIndex)"})
   }
  }}}}}}
  let data=try JSONEncoder().encode(rows);try data.write(to:URL(fileURLWithPath:CommandLine.arguments[1]));print("Golden scenarios: \(rows.count)")
 }
}
