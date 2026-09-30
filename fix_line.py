#!/usr/bin/env python
with open('lib/screens/finalizar_notificacion_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Current state: line 402 (index 401) is '    ),\n' 
#                line 403 (index 402) is '  }\n'  (closes method)
# Need to change so return SizedBox closes properly.
# The correct structure has ');' after the ), before the method closing }

# Let's just replace line 403 (index 402) from '  }\n' to '  );\n  }\n'
# This adds the ');' to close SizedBox and keeps the '}' for method

if len(lines) > 402:
    # Replace the closing line
    old = lines[402]  # should be '  }\n'
    new = '  );\n  }\n'
    if old.strip() == '}':
        lines[402] = new
        print(f"Replaced line 403: {old!r} -> {new!r}")
    else:
        print(f"Line 403 was: {old!r}, expected '}'")
        
with open('lib/screens/finalizar_notificacion_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("Done")