# Hotkeys And Paste Manual Verification

1. Launch ChainCopy and open Settings > Shortcuts.
2. Confirm the default shortcuts register or show a conflict/unavailable status:
   - Toggle Capture: Ctrl+Cmd+A
   - Copy Chain: Ctrl+Cmd+Shift+V
   - Paste Chain: Ctrl+Cmd+V
   - Show Composer: Ctrl+Cmd+O
   - Clear Chain: Ctrl+Cmd+X
3. Change one shortcut, confirm the status updates, then use Reset Shortcuts.
4. With Accessibility not granted, trigger Paste Chain from a text field in another app. The chain should be copied to the clipboard, no synthetic paste should occur, and ChainCopy should show the manual paste fallback.
5. Use Settings > Automation > Enable Accessibility or Open System Settings, grant ChainCopy Accessibility access, then click Check Again.
6. With Accessibility granted, trigger Paste Chain from a text field in another app. ChainCopy should copy the composed chain and send Cmd+V to the active app.
7. Confirm no logs or UI surfaces reveal full clipboard contents outside the existing chain/composer views.
