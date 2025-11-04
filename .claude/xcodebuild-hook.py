#!/usr/bin/env python3
"""
Hook to ensure xcodebuild commands always use the correct simulator destination.
"""
import json
import sys
import re

def main():
    # Read the tool call data from stdin
    hook_data = json.load(sys.stdin)

    # Get the command from the tool parameters
    command = hook_data.get("toolInput", {}).get("command", "")

    # Check if this is an xcodebuild command
    if "xcodebuild" in command:
        correct_destination = "platform=iOS Simulator,name=iPhone 17 Pro"

        # Check if the command already has a -destination flag
        if "-destination" in command:
            # Check if it's using the correct destination
            if correct_destination not in command:
                # Replace the existing destination with the correct one
                # Handle both quoted and unquoted destinations
                command = re.sub(
                    r'-destination\s+["\']?[^"\']*["\']?',
                    "-destination '" + correct_destination + "'",
                    command
                )

                # Output the modified command
                result = {
                    "permissionDecision": "allow",
                    "updatedInput": {
                        "command": command
                    },
                    "message": "✓ Modified xcodebuild to use iPhone 17 Pro simulator"
                }
                print(json.dumps(result))
                return
        else:
            # Add the destination flag if it's missing
            # Insert it after xcodebuild and any scheme flags
            if "-scheme" in command:
                # Find the -scheme argument and add destination after it
                parts = command.split()
                new_parts = []
                i = 0
                while i < len(parts):
                    new_parts.append(parts[i])
                    if parts[i] == "-scheme" and i + 1 < len(parts):
                        new_parts.append(parts[i + 1])
                        i += 1
                        # Add destination here
                        new_parts.extend(["-destination", correct_destination])
                    i += 1
                command = " ".join(new_parts)
            else:
                # Just add it after xcodebuild
                command = command.replace("xcodebuild", "xcodebuild -destination '" + correct_destination + "'", 1)

            result = {
                "permissionDecision": "allow",
                "updatedInput": {
                    "command": command
                },
                "message": "✓ Added iPhone 17 Pro simulator destination to xcodebuild"
            }
            print(json.dumps(result))
            return

    # Allow the command as-is
    result = {
        "permissionDecision": "allow"
    }
    print(json.dumps(result))

if __name__ == "__main__":
    main()
