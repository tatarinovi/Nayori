// A playing MPRIS source counts as presence, except during a locked session.
function present(locked, idle, mediaPlaying) {
    return !locked && (!idle || mediaPlaying)
}
