import Foundation
import XCTest

@testable import SeaLegs

final class AppLocalizationTests: XCTestCase {
    private static let supportedTranslationLanguages: [AppLanguage] = [
        .korean,
        .japanese,
        .chineseSimplified
    ]

    private static let printfFormatSpecifierRegex = try? NSRegularExpression(
        pattern: #"%(?:\d+\$)?[-+ #0']*(?:\*|\d+)?(?:\.(?:\*|\d+))?(?:hh|h|ll|l|j|z|t|L|q)?[@aAcCdDeEfFgGioOuUxXnNpPsS%]"#
    )

    func testCurrentAppLabelsAreLocalized() {
        XCTAssertEqual(AppLocalizer(language: .korean).string("Current App"), "현재 앱")
        XCTAssertEqual(AppLocalizer(language: .japanese).string("Current App"), "現在のアプリ")
        XCTAssertEqual(AppLocalizer(language: .chineseSimplified).string("Current App"), "当前应用")
    }

    func testEnglishUsesSourceLabels() {
        let localizer = AppLocalizer(language: .english)

        XCTAssertEqual(localizer.string("Current App"), "Current App")
        XCTAssertEqual(localizer.string("Current App: %@"), "Current App: %@")
    }

    func testSupportedTranslationTablesHaveIdenticalEnglishKeys() {
        let koreanKeys = Set(AppLocalizer.translationTable(for: .korean).keys)

        XCTAssertFalse(koreanKeys.isEmpty)

        for language in Self.supportedTranslationLanguages.dropFirst() {
            let keys = Set(AppLocalizer.translationTable(for: language).keys)

            XCTAssertEqual(
                keys,
                koreanKeys,
                "\(language.rawValue) translation keys must match Korean translation keys."
            )
        }
    }

    func testTranslationsPreservePrintfFormatSpecifiers() {
        for language in Self.supportedTranslationLanguages {
            for (englishKey, translatedValue) in AppLocalizer.translationTable(for: language) {
                XCTAssertEqual(
                    printfFormatSpecifiers(in: translatedValue),
                    printfFormatSpecifiers(in: englishKey),
                    "\(language.rawValue) translation must preserve printf format specifiers for \(englishKey.debugDescription)."
                )
            }
        }
    }

    func testVisualAnchorLabelsKeepCanonicalTitleCase() {
        let canonicalLabels = [
            "Minimal Crosshair",
            "Horizon Guide",
            "Dashboard Frame"
        ]

        for canonicalLabel in canonicalLabels {
            let caseInsensitiveSourceVariants = AppLocalizer.calibrationAnchorKeysForTesting.filter {
                $0.compare(canonicalLabel, options: .caseInsensitive) == .orderedSame
            }

            XCTAssertEqual(
                Set(caseInsensitiveSourceVariants),
                Set([canonicalLabel]),
                "Calibration UI must use \(canonicalLabel.debugDescription) exactly as its localization key."
            )
        }

        for language in Self.supportedTranslationLanguages {
            let keys = AppLocalizer.translationTable(for: language).keys

            for canonicalLabel in canonicalLabels {
                let caseInsensitiveVariants = keys.filter {
                    $0.compare(canonicalLabel, options: .caseInsensitive) == .orderedSame
                }

                XCTAssertEqual(
                    Set(caseInsensitiveVariants),
                    Set([canonicalLabel]),
                    "\(language.rawValue) must use \(canonicalLabel.debugDescription) exactly as its English key."
                )
            }
        }
    }

    private func printfFormatSpecifiers(in text: String) -> [String] {
        guard let regex = Self.printfFormatSpecifierRegex else {
            XCTFail("The printf format-specifier regex must compile.")
            return []
        }

        let fullRange = NSRange(text.startIndex..., in: text)

        return regex.matches(in: text, range: fullRange).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }
}
