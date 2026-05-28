import SwiftUI

extension KeyPress {
    public var isPrintableCharacter: Bool {
        // Only allow no modifiers or only Shift modifier (to type uppercase letters & symbols)
        guard modifiers.subtracting(.shift).isEmpty else { return false }
        
        let chars = characters
        guard chars.count == 1, let firstChar = chars.first else { return false }
        
        return firstChar.isLetter || firstChar.isNumber || firstChar.isPunctuation || firstChar.isSymbol || firstChar == " "
    }
}
