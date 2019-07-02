//
//  PhoneFormattedTextField.swift
//  PhoneNumberFormatter
//
//  Created by Sergey Shatunov on 8/20/17.
//  Copyright © 2017 SHS. All rights reserved.
//

import UIKit

/**
 UITextField subclass to handle phone numbers formats
*/
public class PhoneFormattedTextField: UITextField {

    private let formatProxy: FormattedTextFieldDelegate
    private let formatter: STPhoneFormatter

    /**
     Use is to configure format properties
     */
    public let config: STPhoneConfig

    /**
     If you have a predictive input enabled.
     Default is true.
     */
    public var hasPredictiveInput: Bool {
        set {
            formatProxy.hasPredictiveInput = newValue
        }
        get {
            return formatProxy.hasPredictiveInput
        }
    }

    /**
     Prefix for all formats
     */
    public var prefix: String? {
        set {
            formatProxy.prefix = newValue
            self.text = newValue
        }
        get {
            return formatProxy.prefix
        }
    }

    public override init(frame: CGRect) {
        config =  STPhoneConfig()
        formatter = STPhoneFormatter(config: config)
        formatProxy = FormattedTextFieldDelegate(formatter: formatter)
        super.init(frame: frame)

        super.delegate = formatProxy
        self.keyboardType = .numberPad
    }

    public required init?(coder aDecoder: NSCoder) {
        config =  STPhoneConfig()
        formatter = STPhoneFormatter(config: config)
        formatProxy = FormattedTextFieldDelegate(formatter: formatter)
        super.init(coder: aDecoder)

        super.delegate = formatProxy
        self.keyboardType = .numberPad
    }

    override public var delegate: UITextFieldDelegate? {
        get {
            return formatProxy.userDelegate
        }
        set {
            formatProxy.userDelegate = newValue
        }
    }

    /**
     Block is called on text change
     */
    public var textDidChangeBlock:((_ textField: UITextField?) -> Void)? {
        get {
            return formatProxy.textDidChangeBlock
        }
        set {
            formatProxy.textDidChangeBlock = newValue
        }
    }

    /**
     Return phone number without format. Ex: 89201235678
     */
    public func phoneNumber() -> String? {
        return formatter.digitOnlyString(text: self.text)
    }

    /**
     Return phone number without format and prefix
     */
    public func phoneNumberWithoutPrefix() -> String? {
        if var current = self.text, let prefixString = self.prefix, current.hasPrefix(prefixString) {
            current.removeFirst(prefixString.count)
            return formatter.digitOnlyString(text: current)
        } else {
            return formatter.digitOnlyString(text: self.text)
        }
    }

    public var formattedText: String? {
        get {
            return self.text
        }

        set {
            if let value = newValue {
                let result = formatter.formatText(text: value, prefix: prefix)
                self.text = result.text
            } else {
                self.text = ""
            }

            self.textDidChangeBlock?(self)
            self.sendActions(for: .valueChanged)
        }
    }
}

public struct STPhoneFormat {
    public let phoneFormat: String
    public let regexp: String
    
    public init(defaultPhoneFormat: String) {
        self.phoneFormat = defaultPhoneFormat
        self.regexp = "*"
    }
    public init(phoneFormat: String, regexp: String) {
        self.phoneFormat = phoneFormat
        self.regexp = regexp
    }
}

final public class STPhoneConfig{
    
    private var customConfigs: [STPhoneFormat] = []
    public var defaultConfig: STPhoneFormat = STPhoneFormat(defaultPhoneFormat: "#############")
    
    init() {}
    
    init(defaultFormat: STPhoneFormat) {
        self.defaultConfig = defaultFormat
    }
    
    func getDefaultConfig() -> STPhoneFormat {
        return defaultConfig
    }
    
    func getUserConfigs() -> [STPhoneFormat] {
        return customConfigs
    }
    
    public func add(format: STPhoneFormat) {
        customConfigs.append(format)
    }
}

struct STPhoneFormatterResult {
    let text: String
    init(text: String) {
        self.text = text
    }
}

final class STPhoneFormatter {
    
    let config: STPhoneConfig
    init(config: STPhoneConfig) {
        self.config = config
    }
    
    private let patternSymbol: Character = "#"
    private func isRequireSubstitute(char: Character) -> Bool {
        return patternSymbol == char
    }
    
    private let valuableChars: [Character] = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
    func isValuableChar(char: Character) -> Bool {
        return valuableChars.contains(char) ? true : false
    }
    
    func digitOnlyString(text: String?) -> String? {
        guard let text = text else {
            return nil
        }
        
        if let regex = try? NSRegularExpression(pattern: "\\D",
                                                options: [NSRegularExpression.Options.caseInsensitive]) {
            let range = NSRange(location: 0, length: text.count)
            return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        }
        return nil
    }
    
    private func isMatched(text: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        
        let range = NSRange(location: 0, length: text.count)
        let match = regex.firstMatch(in: text, options: [], range: range)
        if let matchObject = match, matchObject.range.location != NSNotFound {
            return true
        } else {
            return false
        }
    }
    
    private func getAppropriateConfig(text: String, in repo: STPhoneConfig) -> STPhoneFormat {
        for item in config.getUserConfigs() {
            if isMatched(text: text, pattern: item.regexp) {
                return item
            }
        }
        return repo.getDefaultConfig()
    }
    
    func formatText(text: String, prefix: String? = nil) -> STPhoneFormatterResult {
        let lastPossibleFormat = getAppropriateConfig(text: text, in: config)
        
        let cleanNumber = removeFormatFrom(text: text, format: lastPossibleFormat, prefix: prefix) ?? ""
        
        let appropriateConfig = getAppropriateConfig(text: cleanNumber, in: config)
        let result = applyFormat(text: cleanNumber, format: appropriateConfig, prefix: prefix)
        return STPhoneFormatterResult(text: result)
    }
    
    func formattedRemove(text: String, range: NSRange) -> String {
        var possibleString = Array(text)
        let rangeExpressionStart = text.index(text.startIndex, offsetBy: range.location)
        let rangeExpressionEnd = text.index(text.startIndex, offsetBy: range.location + range.length)
        
        let targetSubstring = text[rangeExpressionStart..<rangeExpressionEnd]
        var removeCount = valuableCharCount(in: targetSubstring)
        if range.length == 1 {
            removeCount = 1
        }
        
        for wordCount in 0..<removeCount {
            for idx in (0...(range.location + range.length - wordCount - 1)).reversed() {
                if isValuableChar(char: possibleString[idx]) {
                    possibleString.remove(at: idx)
                    break
                }
            }
        }
        return String(possibleString)
    }
    
    private func removeFormatFrom(text: String, format: STPhoneFormat, prefix: String?) -> String? {
        var unprefixedString = text
        if let prefixString = prefix, unprefixedString.hasPrefix(prefixString) {
            unprefixedString.removeFirst(prefixString.count)
        }
        
        let phoneFormat = format.phoneFormat
        var removeRanges: [NSRange] = []
        
        let min = [text.count, format.phoneFormat.count].min() ?? 0
        for idx in 0 ..< min {
            let index = phoneFormat.index(phoneFormat.startIndex, offsetBy: idx)
            let formatChar = phoneFormat[index]
            if formatChar != text[index] {
                break
            }
            
            if isValuableChar(char: formatChar) {
                let newRange = NSRange(location: idx, length: 1)
                removeRanges.append(newRange)
            }
        }
        var resultText = unprefixedString
        for range in removeRanges.reversed() {
            let rangeExpressionStart = resultText.index(resultText.startIndex, offsetBy: range.location)
            let rangeExpressionEnd = resultText.index(resultText.startIndex, offsetBy: range.location + 1)
            resultText = resultText.replacingCharacters(in: rangeExpressionStart...rangeExpressionEnd, with: "")
        }
        
        return digitOnlyString(text: resultText)
    }
    
    func valuableCharCount(in text: String.SubSequence) -> Int {
        let count = text.reduce(0) { (result, item) -> Int in
            if isValuableChar(char: item) {
                return result + 1
            } else {
                return result
            }
        }
        return count
    }
    
    private func applyFormat(text: String, format: STPhoneFormat, prefix: String?) -> String {
        var result: [Character] = []
        
        var idx = 0
        var charIndex = 0
        let phoneFormat = format.phoneFormat
        while idx < phoneFormat.count && charIndex < text.count {
            let index = phoneFormat.index(phoneFormat.startIndex, offsetBy: idx)
            let character = phoneFormat[index]
            if isRequireSubstitute(char: character) {
                let charIndexItem = text.index(text.startIndex, offsetBy: charIndex)
                let strp = text[charIndexItem]
                charIndex += 1
                result.append(strp)
            } else {
                result.append(character)
            }
            idx += 1
        }
        return (prefix ?? "") + String(result)
    }
    
    func pushCaretPosition(text: String?, range: NSRange) -> Int {
        guard let text = text else {
            return 0
        }
        
        let index = text.index(text.startIndex, offsetBy: range.location + range.length)
        let subString = text[index...]
        return valuableCharCount(in: subString)
    }
    
    func popCaretPosition(textField: UITextField, range: NSRange, caretPosition: Int)
        -> (startPosition: UITextPosition, endPosition: UITextPosition)? {
            var currentRange: NSRange = range
            if range.length == 0 {
                currentRange.length = 1
            }
            
            let text = textField.text ?? ""
            var lasts = caretPosition
            var start = text.count
            var index = start - 1
            
            while start >= 0 && lasts > 0 {
                let indexChar = text.index(text.startIndex, offsetBy: index)
                let character = text[indexChar]
                if isValuableChar(char: character) {
                    lasts -= 1
                }
                
                if lasts <= 0 {
                    start = index
                }
                index -= 1
            }
            
            if let startPosition = textField.position(from: textField.beginningOfDocument, offset: start),
                let endPosition = textField.position(from: startPosition, offset: 0) {
                return (startPosition, endPosition)
            } else {
                return nil
            }
    }
}

