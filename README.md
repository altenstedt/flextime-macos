Protobuf support is from https://github.com/apple/swift-protobuf

Launchd seems to be the correct way to startup at login
https://support.apple.com/guide/terminal/script-management-with-launchd-apdc6c1077b-5d5d-4d35-9c19-60f2397b2369/mac

Logging is done with Unified System Logging
https://developer.apple.com/documentation/os/logging
https://developer.apple.com/documentation/os/logging/generating_log_messages_from_your_code

This is a working com.inhill.flextimed.plist file that can be placed
in you ~/Library/LaunchAgents/ folder.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.inhill.flextime</string>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
    <key>ProgramArguments</key>
    <array>
      <string>/Users/martin/src/flextime-macos/flextimed</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/dev/null</string>
    <key>StandardOutPath</key>
    <string>/dev/null</string>
</dict>
</plist>
```

Alfredapp is an app that needs to run in the background also.  It has
an installation process that I really liked.  Use it as inspiration.
