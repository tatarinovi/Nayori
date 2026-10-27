.pragma library
// Общая память движка QML: пересоздание окна/компонента не сбрасывает приветствие.
var lastGreeting = -Infinity
function canGreet(now) { return now - lastGreeting >= 2 * 60 * 60 * 1000 }
function greeted(now) { lastGreeting = now }
