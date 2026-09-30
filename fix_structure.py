#!/usr/bin/env python
with open('lib/screens/finalizar_notificacion_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find the problematic lines
# Around line 404-405 there's double }}
# We need to remove one of them

# Find the line with "  }" right before "  Widget _buildUbicacion()"
for i in range(len(lines) - 1):
    if '  Widget _buildUbicacion()' in lines[i]:
        # Check previous lines
        if lines[i-1].strip() == '}' and lines[i-2].strip() == '}':
            print(f"Found double }} at lines {i-1} and {i}")
            # Remove the extra } (line i-1)
            del lines[i-1]
            print("Removed extra }")
            break

# Now check if there's exactly one } at the end to close the class
# The file should end with one } for the class
# Count braces to verify
open_braces = 0
close_braces = 0
for line in lines:
    open_braces += line.count('{')
    close_braces += line.count('}')

print(f"Open braces: {open_braces}, Close braces: {close_braces}")

with open('lib/screens/finalizar_notificacion_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("Fixed structure")