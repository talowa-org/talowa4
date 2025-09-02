#!/usr/bin/env python3
import re
import os

def fix_navigation_guard_file(filepath):
    """Fix navigation guard references in a single file"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Comment out the import
    content = re.sub(
        r"import '../../services/navigation/navigation_guard_service.dart';",
        r"// import '../../services/navigation/navigation_guard_service.dart';",
        content
    )
    
    # Replace NavigationGuardService.createSafePopScope wrapper
    content = re.sub(
        r'return NavigationGuardService\.createSafePopScope\(\s*context: context,\s*screenName: \'[^\']+\',\s*child: Scaffold\(',
        r'return Scaffold(',
        content,
        flags=re.MULTILINE | re.DOTALL
    )
    
    # Remove the leading IconButton with NavigationGuardService
    content = re.sub(
        r'leading: IconButton\(\s*icon: const Icon\(Icons\.arrow_back\),\s*onPressed: \(\) \{\s*NavigationGuardService\.handleAppBarBackButton\(\s*context,\s*screenName: \'[^\']+\',\s*\);\s*\},\s*\),',
        r'',
        content,
        flags=re.MULTILINE | re.DOTALL
    )
    
    # Remove extra closing parenthesis and bracket at the end
    # This is tricky, so let's be more specific
    lines = content.split('\n')
    
    # Find the last few lines and fix the structure
    for i in range(len(lines) - 1, -1, -1):
        line = lines[i].strip()
        if line == ');' and i > 0:
            # Check if the previous line is just closing brackets
            prev_line = lines[i-1].strip()
            if prev_line in [')', '},', ');']:
                # This might be the extra closing from NavigationGuardService
                # Remove this line
                lines.pop(i)
                break
    
    content = '\n'.join(lines)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Fixed {filepath}")

# Fix all the home screen files
files_to_fix = [
    'lib/screens/home/community_screen.dart',
    'lib/screens/home/land_screen.dart', 
    'lib/screens/home/payments_screen.dart',
    'lib/screens/home/profile_screen.dart'
]

for filepath in files_to_fix:
    if os.path.exists(filepath):
        fix_navigation_guard_file(filepath)
    else:
        print(f"File not found: {filepath}")

print("All files fixed!")