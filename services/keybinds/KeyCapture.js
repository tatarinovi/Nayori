.pragma library

// Qt's logical key follows the configured layout. Do not pretend a scancode
// is an XKB name; unsupported symbols can be entered explicitly in the field.
function chord(event) {
    const modifiers = []
    if (event.modifiers & Qt.MetaModifier) modifiers.push("Super")
    if (event.modifiers & Qt.ControlModifier) modifiers.push("Ctrl")
    if (event.modifiers & Qt.AltModifier) modifiers.push("Alt")
    if (event.modifiers & Qt.ShiftModifier) modifiers.push("Shift")
    if (event.modifiers & Qt.GroupSwitchModifier) modifiers.push("Mod5")
    if ([Qt.Key_Meta, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Shift, Qt.Key_AltGr].indexOf(event.key) >= 0)
        return {keys: "", forming: modifiers.join(" + ")}
    let key = ""
    if (event.modifiers & Qt.KeypadModifier) {
        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) key = "KP_" + String.fromCharCode(event.key)
        const keypad = {}
        keypad[Qt.Key_Enter] = "KP_Enter"; keypad[Qt.Key_Return] = "KP_Enter"
        keypad[Qt.Key_Plus] = "KP_Add"; keypad[Qt.Key_Minus] = "KP_Subtract"
        keypad[Qt.Key_Asterisk] = "KP_Multiply"; keypad[Qt.Key_Slash] = "KP_Divide"
        keypad[Qt.Key_Period] = "KP_Decimal"; keypad[Qt.Key_Comma] = "KP_Decimal"
        keypad[Qt.Key_Home] = "KP_Home"; keypad[Qt.Key_End] = "KP_End"
        keypad[Qt.Key_Left] = "KP_Left"; keypad[Qt.Key_Right] = "KP_Right"
        keypad[Qt.Key_Up] = "KP_Up"; keypad[Qt.Key_Down] = "KP_Down"
        keypad[Qt.Key_Insert] = "KP_Insert"; keypad[Qt.Key_Delete] = "KP_Delete"
        key = keypad[event.key] || key
    }
    if (!key && event.key >= Qt.Key_A && event.key <= Qt.Key_Z) key = String.fromCharCode(event.key)
    if (!key && event.key >= Qt.Key_0 && event.key <= Qt.Key_9) key = String.fromCharCode(event.key)
    if (!key && event.key >= Qt.Key_F1 && event.key <= Qt.Key_F35) key = "F" + (event.key - Qt.Key_F1 + 1)
    const names = {}
    names[Qt.Key_Return] = "Return"; names[Qt.Key_Enter] = "Return"; names[Qt.Key_Space] = "Space"
    names[Qt.Key_Escape] = "Escape"; names[Qt.Key_Tab] = "Tab"; names[Qt.Key_Backtab] = "Tab"
    names[Qt.Key_Left] = "Left"; names[Qt.Key_Right] = "Right"; names[Qt.Key_Up] = "Up"; names[Qt.Key_Down] = "Down"
    names[Qt.Key_Backspace] = "BackSpace"; names[Qt.Key_Delete] = "Delete"; names[Qt.Key_Insert] = "Insert"
    names[Qt.Key_Home] = "Home"; names[Qt.Key_End] = "End"; names[Qt.Key_PageUp] = "Prior"; names[Qt.Key_PageDown] = "Next"
    names[Qt.Key_Print] = "Print"; names[Qt.Key_Minus] = "minus"; names[Qt.Key_Equal] = "equal"
    names[Qt.Key_Plus] = "plus"; names[Qt.Key_Comma] = "comma"; names[Qt.Key_Period] = "period"
    names[Qt.Key_Slash] = "slash"; names[Qt.Key_Backslash] = "backslash"; names[Qt.Key_Semicolon] = "semicolon"
    names[Qt.Key_Apostrophe] = "apostrophe"; names[Qt.Key_BracketLeft] = "bracketleft"; names[Qt.Key_BracketRight] = "bracketright"
    names[Qt.Key_QuoteLeft] = "grave"; names[Qt.Key_VolumeUp] = "XF86AudioRaiseVolume"; names[Qt.Key_VolumeDown] = "XF86AudioLowerVolume"
    names[Qt.Key_VolumeMute] = "XF86AudioMute"; names[Qt.Key_MediaPlay] = "XF86AudioPlay"; names[Qt.Key_MediaPause] = "XF86AudioPause"
    names[Qt.Key_MediaNext] = "XF86AudioNext"; names[Qt.Key_MediaPrevious] = "XF86AudioPrev"
    names[Qt.Key_MonBrightnessUp] = "XF86MonBrightnessUp"; names[Qt.Key_MonBrightnessDown] = "XF86MonBrightnessDown"
    const punctuation = {33: "exclam", 34: "quotedbl", 35: "numbersign", 36: "dollar", 37: "percent",
        38: "ampersand", 40: "parenleft", 41: "parenright", 42: "asterisk", 58: "colon", 60: "less",
        62: "greater", 63: "question", 64: "at", 94: "asciicircum", 95: "underscore", 123: "braceleft",
        124: "bar", 125: "braceright", 126: "asciitilde"}
    key = key || names[event.key] || punctuation[event.key] || ""
    if (!key && event.text && Array.from(event.text).length === 1) {
        const point = event.text.codePointAt(0)
        if (point > 127) key = "U" + point.toString(16).padStart(4, "0")
    }
    return {keys: key ? modifiers.concat([key]).join("+") : "", forming: modifiers.join(" + ")}
}
