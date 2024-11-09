# BytePatcher

This Nim program allows for in-place binary patching of a specified file, enabling modifications to specific byte sequences directly within the binary. The program searches for predefined byte patterns in a binary file and replaces them with new data at matched offsets. A backup of the original file is created before any changes are made to ensure safety.

## Features

- **Pattern Matching with Wildcards**: Searches for byte patterns in the binary file, allowing wildcards within the pattern.
- **Hexadecimal Address Display**: Outputs the hexadecimal offset of each pattern match.
- **In-place Patching**: Replaces specified byte sequences at matched addresses within the binary.
- **Backup Creation**: Automatically creates a timestamped backup of the original binary file.
- **MD5 Check**: Calculates and displays the MD5 checksum of the binary before and after patching for integrity verification.
- **Color-Coded Output**: Provides color-coded terminal output to indicate success, errors, and patch locations.

## Requirements

- **Nim Compiler**: This application is written in Nim. Install Nim [here](https://nim-lang.org/install.html).
- **Permissions**: If the binary is located in a restricted directory (e.g., `/opt/`), root or elevated permissions may be required.

## Installation

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/DrunkenAlcoholic/BytePatcher.git
   cd BytePatcher
   ```

2. **Compile the Application**:
   ```bash
   nim c -d:release sublimePatch.nim
   ```

## Usage

Run the compiled program, specifying the binary file path and patches defined within the code:

```bash
./sublimePatch
```

**Note**: To ensure correct patching, review and define patches directly within the source code before running.

### Example Output

1. **Before Patching**:
   ```
   MD5 Checksum Before Patching: <checksum>
   ```

2. **Pattern Matching and Patching**:
   ```
   Backup created at: /opt/sublime_text/sublime_text_20231108-143025.backup
   Searching and Applying Patches:
   Pattern found at address: 0x1234
   Applying patch at address: 0x1234
   Patch applied successfully.
   ```

3. **After Patching**:
   ```
   MD5 Checksum After Patching: <checksum>
   ```

## Defining Patches

The patch definitions are hardcoded in `sublimePatch.nim` as a sequence of `Patch` objects. Each `Patch` object consists of:
- `pattern`: The byte sequence to search for, with support for wildcard bytes.
- `data`: The replacement byte sequence.
- `address`: Initially set to `-1` but updated with the matched offset if found.

Modify the `Patches` sequence in the code to define patterns and replacement data as needed.

Example:
```nim
var Patches: seq[Patch] = @[
  Patch(pattern: @[0x55, 0x41, 0x57, 0x41], data: @[0x90, 0x90], address: -1)
]
```

## Error Handling

- If a pattern is not found, the program will skip the patch and notify the user.
- If there are any I/O errors (e.g., file permissions), they are printed in red for visibility.
- The program outputs success messages for each patch applied.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

This application uses Nim’s standard library modules for file I/O, MD5 checksums, and error handling to implement an efficient and safe binary patching mechanism.
