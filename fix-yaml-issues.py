#!/usr/bin/env python3
"""
Script to fix common YAML linting issues in GitOps manifests
"""
import os
import re
from pathlib import Path

def fix_yaml_file(file_path):
    """Fix common YAML issues in a file"""
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Skip if already has document start
    if content.startswith('---'):
        pass
    elif content.startswith('# '):
        # If starts with comment, add document start after comments
        lines = content.split('\n')
        comment_lines = []
        content_lines = []
        
        for i, line in enumerate(lines):
            if line.startswith('#') or line.strip() == '':
                comment_lines.append(line)
            else:
                content_lines = lines[i:]
                break
        
        content = '\n'.join(comment_lines + ['---'] + content_lines)
    else:
        # Add document start at beginning
        content = '---\n' + content
    
    # Remove trailing spaces
    content = re.sub(r'[ \t]+$', '', content, flags=re.MULTILINE)
    
    # Ensure file ends with newline
    if not content.endswith('\n'):
        content += '\n'
    
    with open(file_path, 'w') as f:
        f.write(content)
    
    print(f"Fixed: {file_path}")

def main():
    """Main function to fix all YAML files in GitOps directory"""
    gitops_dir = Path('./gitops')
    
    # Find all YAML files
    yaml_files = []
    for pattern in ['**/*.yaml', '**/*.yml']:
        yaml_files.extend(gitops_dir.glob(pattern))
    
    for yaml_file in yaml_files:
        try:
            fix_yaml_file(yaml_file)
        except Exception as e:
            print(f"Error fixing {yaml_file}: {e}")

if __name__ == '__main__':
    main()