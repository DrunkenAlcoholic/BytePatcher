import std/[os, strutils, strformat, times]
import checksums/md5

# ANSI Color Codes
const
  bold = "\x1b[1m"
  reset = "\x1b[0m"
  yellow = "\x1b[33m"
  green = "\x1b[32m"
  red = "\x1b[31m"
  blue = "\x1b[34m"   # Added blue color code

# Define the Patch type
type
  Patch = object
    pattern: seq[byte]  # Byte sequence pattern with possible wildcards
    data: seq[byte]     # Replacement data
    address: int        # Address where the pattern is found (-1 if not found)

# Path to the binary file to patch
let FilePath: string = "/opt/sublime_text/sublime_text"

# Define the patches
var Patches: seq[Patch] = @[
  Patch(pattern: @[0x55, 0x41, 0x57, 0x41, 0x56, 0x41, 0x55, 0x41, 0x54, 0x53, 0x48, 0x81, 0xEC, 0x00, 0x00, 0x00, 0x00, 0x4C, 0x89, 0x8C, 0x24, 0x00, 0x00, 0x00, 0x00, 0x4C, 0x89, 0xC3, 0x48, 0x89, 0x8C, 0x24, 0x00, 0x00, 0x00, 0x00], data: @[0x48, 0xC7, 0xC0, 0x00, 0x00, 0x00, 0x00, 0xC3], address: -1),
  Patch(pattern: @[0xE8, 0x00, 0x00, 0x00, 0x00, 0x48, 0x8B, 0xB3, 0x00, 0x00, 0x00, 0x00, 0x48, 0x8D, 0x3D, 0x00, 0x00, 0x00, 0x00, 0xBA, 0x00, 0x00, 0x00, 0x00, 0xE8, 0x00, 0x00, 0x00, 0x00, 0x48, 0x89, 0xDF], data: @[0x90, 0x90, 0x90, 0x90, 0x90], address: -1),
  Patch(pattern: @[0xE8, 0x00, 0x00, 0x00, 0x00, 0x48, 0x89, 0xDF, 0xE8, 0x00, 0x00, 0x00, 0x00, 0xBF, 0x00, 0x00, 0x00, 0x00, 0xE8, 0x00, 0x00, 0x00, 0x00, 0x49, 0x89, 0xC7], data: @[0x90, 0x90, 0x90, 0x90, 0x90], address: -1),
  Patch(pattern: @[0xFF, 0x8B, 0x77, 0x20], data: @[0xFF, 0x90, 0x90, 0x90], address: -1),
  Patch(pattern: @[0x41, 0x57, 0x41, 0x56, 0x41, 0x54, 0x53, 0x48, 0x81, 0xEC, 0x00, 0x00, 0x00, 0x00, 0x48, 0x89, 0xFB, 0x48, 0x8D, 0x3D, 0x00, 0x00, 0x00, 0x00], data: @[0xC3], address: -1)
  # Additional patches here...
]

# MD5 Checksum Function
proc md5Checksum(filePath: string): string =
  var ctx: MD5Context
  var digest: MD5Digest
  let file = open(filePath)
  var buffer: array[1024, byte]
  md5Init(ctx)
  while (let len = readBytes(file, buffer, 0, buffer.len); len > 0):
    md5Update(ctx, buffer[0..len-1])
  md5Final(ctx, digest)
  close(file)
  return fmt"{digest} {filePath}"

# Pattern Search with Wildcard Support
proc searchPattern(pTarget, pPattern: openArray[byte], wildcard: byte = 0x00): int =
  for i in 0 .. (pTarget.len - pPattern.len):
    var found = true
    for j in 0 .. pPattern.len - 1:
      if not (pPattern[j] == wildcard or pPattern[j] == pTarget[i + j]):
        found = false
        break
    if found:
      return i
  return -1

# Apply patches with colorized output and formatted messages
proc applyPatchesWithSearch(filename: string, patches: var seq[Patch], wildcard: byte = 0x00) =
  # Backup File Creation
  let timestamp = now().format("yyyyMMdd-HHmmss")  # Adjusted format to use '-' instead of '_'
  let backupFilename = filename & "_" & timestamp & ".backup"
  try:
    copyFile(filename, backupFilename)
    echo bold & green & "Backup created at: " & backupFilename & reset
  except IOError as e:
    echo red & "Failed to create backup: ", e.msg & reset
    return

  # Read Binary File
  var binaryData: seq[byte]
  try:
    binaryData = cast[seq[byte]](readFile(filename))
  except IOError as e:
    echo red & "Error reading file: " & e.msg & reset
    return

  # Search and Apply Patches
  echo bold & blue & "\nSearching and Applying Patches:" & reset
  for patch in patches.mitems:
    patch.address = searchPattern(binaryData, patch.pattern, wildcard)
    if patch.address != -1:
      echo yellow & fmt"Pattern found at address: 0x{patch.address:X}" & reset
    else:
      echo red & "Pattern not found. Skipping patch." & reset
      continue

    # Apply Patch
    echo green & fmt"Applying patch at address: 0x{patch.address:X}" & reset
    try:
      var file = open(filename, fmReadWriteExisting)
      defer: close(file)
      setFilePos(file, patch.address)
      discard file.writeBytes(patch.data, 0, patch.data.len)  # Discard the return value
      echo green & "Patch applied successfully." & reset
    except IOError as e:
      echo red & "Failed to apply patch: ", e.msg & reset


# Main Block with Colorized MD5 Output
when isMainModule:
  try:
    echo bold & "MD5 Checksum Before Patching:" & reset, md5Checksum(FilePath)
    applyPatchesWithSearch(FilePath, Patches)
    echo bold & "MD5 Checksum After Patching:" & reset, md5Checksum(FilePath)
  except IOError as e:
    echo red & "Error: ", e.msg & reset
