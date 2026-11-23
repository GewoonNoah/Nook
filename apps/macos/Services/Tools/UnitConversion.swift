import Foundation

/// "5 km to mi", "20 c in f", "3,5 kg → lb": an amount, a unit, a word or arrow, and the unit to convert to, answered
/// offline with Foundation's `Measurement`. Units of different kinds (km to kg) do not convert. Foundation only, so it
/// is tested anywhere; the Tools tab's converter shows the answer as you type.
enum UnitConversion {
    struct Result: Equatable {
        let value: Double
        let unit: String
        /// "8.05 mi": the value rounded for reading, with its unit.
        var text: String { UnitConversion.format(value) + " " + unit }
    }

    /// Every unit by the names people type, lowercased.
    private static let units: [String: Dimension] = {
        var table: [String: Dimension] = [:]
        func add(_ unit: Dimension, _ names: String...) { for name in names { table[name] = unit } }
        // Length
        add(UnitLength.kilometers, "km", "kilometer", "kilometers", "kilometre", "kilometres")
        add(UnitLength.meters, "m", "meter", "meters", "metre", "metres")
        add(UnitLength.centimeters, "cm", "centimeter", "centimeters")
        add(UnitLength.millimeters, "mm", "millimeter", "millimeters")
        add(UnitLength.miles, "mi", "mile", "miles", "mijl")
        add(UnitLength.yards, "yd", "yard", "yards")
        add(UnitLength.feet, "ft", "foot", "feet", "voet")
        add(UnitLength.inches, "in", "inch", "inches", "\"", "duim")
        // Mass
        add(UnitMass.kilograms, "kg", "kilo", "kilos", "kilogram", "kilograms")
        add(UnitMass.grams, "g", "gram", "grams")
        add(UnitMass.milligrams, "mg", "milligram", "milligrams")
        add(UnitMass.pounds, "lb", "lbs", "pound", "pounds", "pond")
        add(UnitMass.ounces, "oz", "ounce", "ounces")
        add(UnitMass.stones, "st", "stone", "stones")
        // Temperature
        add(UnitTemperature.celsius, "c", "°c", "celsius")
        add(UnitTemperature.fahrenheit, "f", "°f", "fahrenheit")
        add(UnitTemperature.kelvin, "k", "kelvin")
        // Volume
        add(UnitVolume.liters, "l", "liter", "liters", "litre", "litres")
        add(UnitVolume.milliliters, "ml", "milliliter", "milliliters")
        add(UnitVolume.deciliters, "dl", "deciliter")
        add(UnitVolume.gallons, "gal", "gallon", "gallons")
        add(UnitVolume.cups, "cup", "cups", "kop")
        add(UnitVolume.fluidOunces, "floz", "fl oz")
        add(UnitVolume.tablespoons, "tbsp", "el", "eetlepel")
        add(UnitVolume.teaspoons, "tsp", "tl", "theelepel")
        // Speed
        add(UnitSpeed.kilometersPerHour, "km/h", "kmh", "kph")
        add(UnitSpeed.milesPerHour, "mph", "mi/h")
        add(UnitSpeed.metersPerSecond, "m/s", "mps")
        add(UnitSpeed.knots, "kn", "knot", "knots", "knoop", "knopen")
        // Duration
        add(UnitDuration.hours, "h", "hr", "hour", "hours", "uur")
        add(UnitDuration.minutes, "min", "mins", "minute", "minutes", "minuut", "minuten")
        add(UnitDuration.seconds, "s", "sec", "second", "seconds", "seconde", "seconden")
        // Data
        add(UnitInformationStorage.kilobytes, "kb")
        add(UnitInformationStorage.megabytes, "mb")
        add(UnitInformationStorage.gigabytes, "gb")
        add(UnitInformationStorage.terabytes, "tb")
        // Area
        add(UnitArea.squareMeters, "m2", "m²")
        add(UnitArea.squareKilometers, "km2", "km²")
        add(UnitArea.hectares, "ha", "hectare", "hectares")
        add(UnitArea.acres, "acre", "acres")
        add(UnitArea.squareFeet, "ft2", "ft²", "sq ft")
        return table
    }()

    /// The words between the two units: "5 km to mi", "… in …", "… naar …", "… → …", "… = …".
    private static let pattern = try? NSRegularExpression(
        pattern: #"^\s*(-?[0-9]+(?:[.,][0-9]+)?)\s*(.+?)\s+(?:to|in|into|naar|nach|en|a|→|->|=)\s+(.+?)\s*$"#,
        options: [.caseInsensitive])

    /// The answer to `text`, or nil when it is not an amount with two units of the same kind.
    static func convert(_ text: String) -> Result? {
        let range = NSRange(text.startIndex..., in: text)
        guard let pattern, let match = pattern.firstMatch(in: text, options: [], range: range),
              let amountRange = Range(match.range(at: 1), in: text),
              let fromRange = Range(match.range(at: 2), in: text),
              let toRange = Range(match.range(at: 3), in: text),
              let amount = Double(text[amountRange].replacingOccurrences(of: ",", with: ".")) else { return nil }
        let fromName = text[fromRange].lowercased(), toName = text[toRange].lowercased()
        guard let from = units[fromName], let to = units[toName], type(of: from) == type(of: to) else { return nil }
        let converted = Measurement(value: amount, unit: from).converted(to: to).value
        return Result(value: converted, unit: String(text[toRange]))
    }

    /// At most four decimals, without trailing zeros: "8.0467", "68", "0.5".
    static func format(_ value: Double) -> String {
        if value.isNaN || value.isInfinite { return String(value) }
        let rounded = (value * 10_000).rounded() / 10_000
        if rounded == rounded.rounded(), abs(rounded) < 1e15 { return String(Int(rounded)) }
        var text = String(format: "%.4f", rounded)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }
}
