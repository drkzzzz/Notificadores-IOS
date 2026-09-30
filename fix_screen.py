#!/usr/bin/env python3
import sys

with open('lib/screens/finalizar_notificacion_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Fix line 402 (index 401): change the ; after label to ), 
# and ensure the return SizedBox closes properly
# The broken lines around 400-404:
# return SizedBox(
#   width: double.infinity,
#   height: 44,
#   child: OutlinedButton.icon(
#     onPressed: onTomar,
#     icon: const Icon(Icons.photo_camera_outlined),
#     label: Text(titulo),
#   ;
# }
# 
# Need to make it:
# return SizedBox(
#   width: double.infinity,
#   height: 44,
#   child: OutlinedButton.icon(
#     onPressed: onTomar,
#     icon: const Icon(Icons.photo_camera_outlined),
#     label: Text(titulo),
#   ),
# );
# );

# Find the index of the line with "label: Text(titulo)," and fix surrounding
for i, line in enumerate(lines):
    if 'label: Text(titulo),' in line and i > 390 and i < 410:
        # This is the problematic line - need to change the next line's ; to ),
        # and possibly adjust the line after
        # Let's look at the next line
        if i+1 < len(lines) and ';' in lines[i+1]:
            # Replace the ; on the next line with ),
            lines[i+1] = lines[i+1].replace(';', '),')
            print(f"Fixed line {i+2}: replaced ; with ),")
        break

# Also fix the _buildUbicacion method's return SizedBox closing
# The last part of the method has:
# : OutlinedButton.icon(
#   onPressed: _obtenerUbicacion,
#   icon: const Icon(Icons.my_location),
#   label: const Text('Obtener ubicación GPS'),
# ),
# Need to ensure it ends with ); to close the ternary and the method

# Find the line with "label: const Text('Obtener ubicación GPS')," and ensure closing
for i, line in enumerate(lines):
    if "label: const Text('Obtener ubicación GPS')," in line and i > 440:
        # The next line should be ")," closing OutlinedButton.icon
        # and then ");" closing the SizedBox and ternary
        # Check the line after
        if i+1 < len(lines):
            next_line = lines[i+1].strip()
            # If next line is just "}" or something wrong, fix it
            if next_line == '}' or not next_line.endswith(');'):
                # Insert proper closing
                lines[i+1] = ');\n'
                print(f"Fixed line {i+2} closing")
        break

# Also ensure the class has proper closing - check last lines
# The file should end with } for the state class
# Check if last line is }
last_idx = len(lines) - 1
last_line = lines[last_idx].strip()
if last_line == '}':
    # Check if there's already a closing for the widget
    # Actually the _buildUbicacion method } was already there,
    # but the _FinalizarNotificacionScreenState class needs its }
    # Let's add it if missing
    # Look two lines before last
    if last_idx >= 2 and lines[last_idx - 1].strip() != '}':
        # Possibly need another }
        pass  # assume it's already there

with open('lib/screens/finalizar_notificacion_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("Script completed")