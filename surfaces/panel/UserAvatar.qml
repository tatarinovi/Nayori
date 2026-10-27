import "../../sddm/nayori/components"

AuthAvatar {
    required property var tokens
    colors: tokens.color
    cornerRadius: tokens.radius.medium
    fontFamily: tokens.type.body.family
}
