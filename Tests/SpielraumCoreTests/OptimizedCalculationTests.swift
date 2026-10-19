import XCTest
@testable import SpielraumCore
final class OptimizedCalculationTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Vienna")!; return c }
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date { calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }
    func testFastScheduleCountsMatchReferenceAcrossCadencesAndMonthEnds() {
        for cadence in PaymentCadence.allCases {
            for anchor in [date(2000, 1, 31), date(2024, 2, 29)] {
                for end in [nil, Optional(date(2028, 4, 30))] {
                    var p = RecurringPayment(name: "Test", cents: 100, kind: .fixedCost, cadence: cadence, firstDue: anchor, endDate: end)
                    p.completed = 2
                    for cutoff in [date(1999, 1, 1), date(2026, 2, 28), date(2028, 2, 29), date(2030, 5, 31)] {
                        var count = 0; var index = p.completed
                        while index < 12000 && p.includesOccurrence(index, calendar: calendar) && calendar.startOfDay(for: p.dueDate(at: index, calendar: calendar)) <= calendar.startOfDay(for: cutoff) { count += 1; index += 1 }
                        XCTAssertEqual(p.outstandingCount(through: cutoff, calendar: calendar), count)
                    }
                }
            }
        }
    }
    func testFutureIncomeSkipsOldDatesAndHonorsEnd() {
        var p = RecurringPayment(name: "Gehalt", cents: 100, kind: .income, cadence: .monthly, firstDue: date(2000, 1, 31))
        XCTAssertEqual(p.nextFutureDate(after: date(2026, 10, 31), calendar: calendar), calendar.startOfDay(for: date(2026, 11, 30)))
        p.endDate = date(2026, 10, 31)
        XCTAssertNil(p.nextFutureDate(after: date(2026, 10, 31), calendar: calendar))
    }
    func testLargeHistoryStillProducesCorrectWeeklyEstimate() throws {
        var b = Budget(); b.balance = Euro.limit
        let now = date(2026, 10, 19)
        for day in 1...56 {
            for _ in 0..<100 {
                b.expenses.append(.init(title: "Alltag", cents: 1, category: "Sonstiges", date: calendar.date(byAdding: .day, value: -day, to: now)!))
            }
        }
        let a = b.assessment(now: now, calendar: calendar)
        XCTAssertEqual(a.essentialWeekly, 700); XCTAssertEqual(a.learnedSamples, 4900)
        XCTAssertEqual(b.weeklyLimit, 14500)
    }
    func testCurrencyFormatterKeepsFractionDigitsIndependent() {
        XCTAssertTrue(Euro.format(1234).contains("12,34"))
        XCTAssertFalse(Euro.format(1200).contains(",00"))
        XCTAssertTrue(Euro.format(-1234).contains("12,34"))
        XCTAssertTrue(Euro.format(1).contains("0,01"))
    }
}
