import std/[os, strutils, strformat, times]
import checksums/md5 # nimble install checksums

# ANSI Color Codes
const
  bold = "\x1b[1m"
  reset = "\x1b[0m"
  yellow = "\x1b[33m"
  green = "\x1b[32m"
  red = "\x1b[31m"
  blue = "\x1b[34m"

# Path to the binary file to patch
let FilePath = "/opt/sublime_text/sublime_text"

# Define the Patch type
type Patch = object
  pattern: seq[byte]
  data: seq[byte]
  address: int

# Define the patches
var Patches = @[
  Patch(
    pattern: @[
      0xE8, 0x00, 0x00, 0x00, 0x00, 0x49, 0x8B, 0xB4, 0x24, 0x00, 0x00, 0x00, 0x00,
      0x48, 0x8D, 0x3D, 0x00, 0x00, 0x00, 0x00, 0xBA, 0x00, 0x00, 0x00, 0x00, 0xE8,
      0x00, 0x00, 0x00, 0x00, 0x4C, 0x89, 0xE7
    ],
    data: @[0x90, 0x90, 0x90, 0x90, 0x90],
    address: -1
  ),
  Patch(
    pattern: @[
      0xE8, 0x00, 0x00, 0x00, 0x00, 0x4C, 0x89, 0xE7, 0xE8, 0x00, 0x00, 0x00, 0x00,
      0xBF, 0x00, 0x00, 0x00, 0x00, 0xE8, 0x00, 0x00, 0x00, 0x00, 0x49, 0x89, 0xC7
    ],
    data: @[0x90, 0x90, 0x90, 0x90, 0x90],
    address: -1
  ),
  Patch(
    pattern: @[
      0x41, 0x57, 0x41, 0x56, 0x41, 0x54, 0x53, 0x48, 0x81, 0xEC, 0x00, 0x00, 0x00,
      0x00, 0x48, 0x89, 0xFB, 0x48, 0x8D, 0x3D, 0x00, 0x00, 0x00, 0x00
    ],
    data: @[0xC3],
    address: -1
  ),
  Patch(
    pattern: @[
      0x55, 0x41, 0x57, 0x41, 0x56, 0x41, 0x55, 0x41, 0x54, 0x53, 0x48, 0x81, 0xEC,
      0x00, 0x00, 0x00, 0x00, 0x4C, 0x89, 0x8C, 0x24, 0x00, 0x00, 0x00, 0x00, 0x4C,
      0x89, 0x84, 0x24, 0x00, 0x00, 0x00, 0x00, 0x48, 0x89, 0x8C, 0x24, 0x00, 0x00,
      0x00, 0x00, 0x48, 0x89, 0x94, 0x24
    ],
    data: @[0x48, 0xC7, 0xC0, 0x00, 0x00, 0x00, 0x00, 0xC3],
    address: -1
  ),
  Patch(
    pattern: @[0x41, 0x57, 0x41, 0x56, 0x53, 0x89, 0xF3, 0x49, 0x89, 0xFE, 0x6A, 0x00, 0x5F],
    data: @[0xC3],
    address: -1
  )
]

proc md5Checksum(filePath: string): string =
  var ctx: MD5Context
  var digest: MD5Digest
  var buffer: array[1024, byte]
  let file = open(filePath)
  defer: close(file)
  
  md5Init(ctx)
  while (let len = readBytes(file, buffer, 0, buffer.len); len > 0):
    md5Update(ctx, buffer[0 .. len - 1])
  md5Final(ctx, digest)
  return $digest

proc searchPattern(target, pattern: openArray[byte], wildcard: byte = 0x00): int =
  for i in 0 .. (target.len - pattern.len):
    block checkPattern:
      for j in 0 .. pattern.len - 1:
        if pattern[j] != wildcard and pattern[j] != target[i + j]:
          break checkPattern
      return i
  return -1

proc previewPatches(filename: string, patches: var seq[Patch]): bool =
  let binaryData = try: cast[seq[byte]](readFile(filename))
                   except IOError as e:
                     echo fmt"{red}Error reading file: {e.msg}{reset}"
                     return false

  echo fmt"""
{bold}{blue}🔎 Searching for Patch Patterns:{reset}"""

  var anyFound = false
  for patch in patches.mitems:
    patch.address = searchPattern(binaryData, patch.pattern)
    if patch.address != -1:
      echo fmt"  {green}✔{reset} Pattern found at address: {yellow}0x{patch.address:X}{reset}"
      anyFound = true
    else:
      echo fmt"  {red}✗{reset} Pattern not found. Skipping patch."
  
  return anyFound

proc applyPatchesWithBackup(filename: string, patches: var seq[Patch]) =
  let timestamp = now().format("yyyyMMdd-HHmmss")
  let backupFilename = fmt"{filename}_{timestamp}.backup"
  
  try:
    copyFile(filename, backupFilename)
    echo fmt"{bold}{green}💾 Backup created at: {backupFilename}{reset}"
  except IOError as e:
    echo fmt"{red}Failed to create backup: {e.msg}{reset}"
    return

  let binaryData = try: cast[seq[byte]](readFile(filename))
                   except IOError as e:
                     echo fmt"{red}Error reading file: {e.msg}{reset}"
                     return

  echo fmt"""
{bold}{blue}⚡ Applying Patches:{reset}"""

  for patch in patches.mitems:
    if patch.address == -1: continue
    
    echo fmt"  {green}→{reset} Applying patch at address: {yellow}0x{patch.address:X}{reset}"
    try:
      let file = open(filename, fmReadWriteExisting)
      defer: close(file)
      setFilePos(file, patch.address)
      discard file.writeBytes(patch.data, 0, patch.data.len)
      echo fmt"    {green}✔{reset} Patch applied successfully."
    except IOError as e:
      echo fmt"{red}Failed to apply patch: {e.msg}{reset}"

when isMainModule:
  try:
    let origMD5 = md5Checksum(FilePath)
    
    echo fmt"""
{bold}{blue}╔══════════════════════════════════════════════╗{reset}
{bold}{blue}║           Bytepatcher - Patch Utility        ║{reset}
{bold}{blue}╚══════════════════════════════════════════════╝{reset}

{bold}🎯 Target File:{reset} {yellow}{FilePath}{reset}
{bold}🔑 MD5 Before:{reset} {green}{origMD5}{reset}"""

    if not previewPatches(FilePath, Patches):
      echo fmt"""
{red}❌ No patch patterns found. Nothing to do.{reset}"""
      quit(0)

    stdout.write fmt"{bold}{yellow}⚡ Do you want to apply these patches? [y/N]: {reset}"
    stdout.flushFile()
    
    let answer = stdin.readLine().strip()
    if answer.len == 0 or answer[0] notin {'y', 'Y'}:
      echo fmt"""
{red}🚫 Aborted. No changes made.{reset}"""
      quit(0)

    applyPatchesWithBackup(FilePath, Patches)
    let patchedMD5 = md5Checksum(FilePath)

    echo fmt"""
{bold}{blue}╔══════════════════════════════════════════════╗{reset}
{bold}{blue}║               Patch Summary                  ║{reset}
{bold}{blue}╚══════════════════════════════════════════════╝{reset}

{bold}{green}✅ Patching completed successfully!{reset}

{bold}🔑 MD5 Before:{reset} {green}{origMD5}{reset}
{bold}🔑 MD5 After: {reset} {green}{patchedMD5}{reset}"""

  except IOError as e:
    echo fmt"{red}Error: {e.msg}{reset}"