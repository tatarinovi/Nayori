import QtQuick
import "."
pragma Singleton
pragma ComponentBehavior: Bound




QtObject {
    readonly property var choices: [
        { value: "Circle", label: "Circle", shape: MaterialShape.Shape.Circle },
        { value: "Square", label: "Square", shape: MaterialShape.Shape.Square },
        { value: "Slanted", label: "Slanted", shape: MaterialShape.Shape.Slanted },
        { value: "Arch", label: "Arch", shape: MaterialShape.Shape.Arch },
        { value: "Fan", label: "Fan", shape: MaterialShape.Shape.Fan },
        { value: "Arrow", label: "Arrow", shape: MaterialShape.Shape.Arrow },
        { value: "SemiCircle", label: "Semi Circle", shape: MaterialShape.Shape.SemiCircle },
        { value: "Oval", label: "Oval", shape: MaterialShape.Shape.Oval },
        { value: "Pill", label: "Pill", shape: MaterialShape.Shape.Pill },
        { value: "Triangle", label: "Triangle", shape: MaterialShape.Shape.Triangle },
        { value: "Diamond", label: "Diamond", shape: MaterialShape.Shape.Diamond },
        { value: "ClamShell", label: "Clam Shell", shape: MaterialShape.Shape.ClamShell },
        { value: "Pentagon", label: "Pentagon", shape: MaterialShape.Shape.Pentagon },
        { value: "Gem", label: "Gem", shape: MaterialShape.Shape.Gem },
        { value: "Sunny", label: "Sunny", shape: MaterialShape.Shape.Sunny },
        { value: "VerySunny", label: "Very Sunny", shape: MaterialShape.Shape.VerySunny },
        { value: "Cookie4Sided", label: "Cookie4 Sided", shape: MaterialShape.Shape.Cookie4Sided },
        { value: "Cookie6Sided", label: "Cookie6 Sided", shape: MaterialShape.Shape.Cookie6Sided },
        { value: "Cookie7Sided", label: "Cookie7 Sided", shape: MaterialShape.Shape.Cookie7Sided },
        { value: "Cookie9Sided", label: "Cookie9 Sided", shape: MaterialShape.Shape.Cookie9Sided },
        { value: "Cookie12Sided", label: "Cookie12 Sided", shape: MaterialShape.Shape.Cookie12Sided },
        { value: "Ghostish", label: "Ghostish", shape: MaterialShape.Shape.Ghostish },
        { value: "Clover4Leaf", label: "Clover4 Leaf", shape: MaterialShape.Shape.Clover4Leaf },
        { value: "Clover8Leaf", label: "Clover8 Leaf", shape: MaterialShape.Shape.Clover8Leaf },
        { value: "Burst", label: "Burst", shape: MaterialShape.Shape.Burst },
        { value: "SoftBurst", label: "Soft Burst", shape: MaterialShape.Shape.SoftBurst },
        { value: "Boom", label: "Boom", shape: MaterialShape.Shape.Boom },
        { value: "SoftBoom", label: "Soft Boom", shape: MaterialShape.Shape.SoftBoom },
        { value: "Flower", label: "Flower", shape: MaterialShape.Shape.Flower },
        { value: "Puffy", label: "Puffy", shape: MaterialShape.Shape.Puffy },
        { value: "PuffyDiamond", label: "Puffy Diamond", shape: MaterialShape.Shape.PuffyDiamond },
        { value: "PixelCircle", label: "Pixel Circle", shape: MaterialShape.Shape.PixelCircle },
        { value: "PixelTriangle", label: "Pixel Triangle", shape: MaterialShape.Shape.PixelTriangle },
        { value: "Bun", label: "Bun", shape: MaterialShape.Shape.Bun },
        { value: "Heart", label: "Heart", shape: MaterialShape.Shape.Heart },
    ]

    function shapeForName(name: string): int {
        return choices.find(choice => choice.value === name)?.shape ?? MaterialShape.Shape.Cookie4Sided;
    }
}
