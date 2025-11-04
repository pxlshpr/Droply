# Xcodebuild Hook

This directory contains a PreToolUse hook that automatically ensures all `xcodebuild` commands use the correct iOS Simulator destination.

## What it does

The hook (`xcodebuild-hook.py`) intercepts all Bash commands before they execute and:

1. **Adds missing destination**: If an xcodebuild command doesn't specify a `-destination`, it adds: `platform=iOS Simulator,name=iPhone 17 Pro`

2. **Corrects wrong destination**: If an xcodebuild command uses a different simulator, it replaces it with iPhone 17 Pro

3. **Passes through other commands**: Non-xcodebuild commands are unaffected

## Configuration

The hook is configured in `.claude/settings.local.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/pxlshpr/Developer/Droply/.claude/xcodebuild-hook.py"
          }
        ]
      }
    ]
  }
}
```

## Testing

You can test the hook manually:

```bash
# Test adding destination
echo '{"toolInput": {"command": "xcodebuild -scheme Droply clean build"}}' | ./.claude/xcodebuild-hook.py

# Test modifying destination
echo '{"toolInput": {"command": "xcodebuild -scheme Droply -destination \"platform=iOS Simulator,name=iPhone 16\" build"}}' | ./.claude/xcodebuild-hook.py

# Test non-xcodebuild command (should pass through)
echo '{"toolInput": {"command": "ls -la"}}' | ./.claude/xcodebuild-hook.py
```

## Modifying the simulator

To change which simulator is used, edit the `correct_destination` variable in `xcodebuild-hook.py`:

```python
correct_destination = "platform=iOS Simulator,name=iPhone 17 Pro"
```

## Disabling the hook

To temporarily disable the hook, either:

1. Remove the `hooks` section from `settings.local.json`
2. Comment out the hook in the settings file
3. Rename or remove `xcodebuild-hook.py`
