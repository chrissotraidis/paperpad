#pragma once

// Decides whether the drawn gameplay controls are live. The utility menu button
// stays reachable in every state, so hidden controls can always be restored.
struct PaperPadTouchVisibility {
    bool enabled = true;           // the player's manual Touch Controls choice
    bool autoHide = true;          // "Auto-hide Touch Controls with Controller"
    bool controllerReady = false;  // a usable physical controller owns Player 1

    bool gameplayVisible() const { return enabled && !(autoHide && controllerReady); }

    // "Show Touch Controls" works with the controller still connected: it clears
    // a manual hide and keeps auto-hide off until the player turns it back on.
    void show() {
        enabled = true;
        autoHide = false;
    }
};

// Auto-hide starts on only for players who never chose; saved choices persist.
inline bool PaperPadSavedAutoHide(bool hasSavedChoice, bool savedChoice) {
    return hasSavedChoice ? savedChoice : true;
}
