import std/[os, strutils, strformat]
import checksums/md5

########################
# Define the Patch type 
########################
type
  Patch = object
    pattern: seq[byte]  # Byte sequence pattern with possible wildcards
    data: seq[byte]     # Replacement data
    address: int        # Address where the pattern is found (-1 if not found)

###################################
# Path to the binary file to patch
###################################
let FilePath: string = "/opt/sublime_text/sublime_text"

######################################################################################
# Define the patches: patterns to search and data to replace (initial address is -1)
######################################################################################
var Patches: seq[Patch] = @[
  Patch(pattern: @[0x55, 0x41, 0x57, 0x41, 0x56, 0x41, 0x55, 0x41, 0x54, 0x53, 0x48, 0x81, 0xEC, 0x00, 0x00, 0x00, 0x00, 0x4C, 0x89, 0x8C, 0x24, 0x00, 0x00, 0x00, 0x00, 0x4C, 0x89, 0xC3, 0x48, 0x89, 0x8C, 0x24, 0x00, 0x00, 0x00, 0x00], data: @[0x48, 0xC7, 0xC0, 0x00, 0x00, 0x00, 0x00, 0xC3], address: -1),
  Patch(pattern: @[0xE8, 0x00, 0x00, 0x00, 0x00, 0x48, 0x8B, 0xB3, 0x00, 0x00, 0x00, 0x00, 0x48, 0x8D, 0x3D, 0x00, 0x00, 0x00, 0x00, 0xBA, 0x00, 0x00, 0x00, 0x00, 0xE8, 0x00, 0x00, 0x00, 0x00, 0x48, 0x89, 0xDF], data: @[0x90, 0x90, 0x90, 0x90, 0x90], address: -1),
  Patch(pattern: @[0xE8, 0x00, 0x00, 0x00, 0x00, 0x48, 0x89, 0xDF, 0xE8, 0x00, 0x00, 0x00, 0x00, 0xBF, 0x00, 0x00, 0x00, 0x00, 0xE8, 0x00, 0x00, 0x00, 0x00, 0x49, 0x89, 0xC7], data: @[0x90, 0x90, 0x90, 0x90, 0x90], address: -1),
  Patch(pattern: @[0xFF, 0x8B, 0x77, 0x20], data: @[0x00, 0x90, 0x90, 0x90], address: -1),
  Patch(pattern: @[0x41, 0x57, 0x41, 0x56, 0x41, 0x54, 0x53, 0x48, 0x81, 0xEC, 0x00, 0x00, 0x00, 0x00, 0x48, 0x89, 0xFB, 0x48, 0x8D, 0x3D, 0x00, 0x00, 0x00, 0x00], data: @[0xC3], address: -1)
]

#############
# MD5 Check
#############
proc md5Checksum(filePath: string): string =
  var
    ctx: MD5Context
    digest: MD5Digest
    file = open(filePath)
    buff: array[1024, uint8]
  md5Init(ctx)
  while (let len = readBytes(file, buff, 0, buff.len); len > 0):
    md5Update(ctx, toOpenArray(buff, 0, len-1))
  md5Final(ctx, digest)
  close(file)
  return fmt"{digest} {filePath}"


####################################
# Search proc with wildcard support
####################################
proc searchPattern(pTarget, pPattern: openArray[byte], wildcard: byte = 0x00): int =
  let iTargetLen = pTarget.len
  let iPatternLen = pPattern.len
  if iTargetLen == 0 or iPatternLen == 0:
    return -1

  #####################################################
  # Iterate over the target to find a matching pattern
  #####################################################
  for i in 0 .. (iTargetLen - iPatternLen):
    var found = true
    for j in 0 .. iPatternLen - 1:
      if not (pPattern[j] == wildcard or pPattern[j] == pTarget[i + j]):
        found = false
        break
    if found:
      return i  # Return the starting index of the found pattern

  return -1  # Pattern not found


#############################################################################
# Proc to apply patches by searching patterns dynamically in the binary file
#############################################################################
proc applyPatchesWithSearch(filename: string, patches: var seq[Patch], wildcard: byte = 0x00) =
  
  ########################################
  # Create a backup of the original file
  ########################################
  var file: File
  var backupFilename = filename & ".backup"

  try:
    copyFile(filename, backupFilename)
  except IOError as e:
    echo "Failed to create backup:", e.msg

  # Read the binary file
  var binaryData: seq[byte]
  try:
    if not open(file, filename, fmReadWriteExisting):
      raise newException(IOError, "Unable to open file: " & filename)
    defer: close(file)


    let fileContent = file.readAll()
    binaryData = cast[seq[byte]](fileContent)  # Cast string to seq[byte]
  except IOError as e:
    echo "Error reading file: ", e.msg


  ############################################
  # Search for patterns and update addresses
  ############################################
  for patch in patches.mitems:  # Use mutable iterator `mitems`
    let address = searchPattern(binaryData, patch.pattern, wildcard)
    patch.address = address


  # Display all found addresses for testing
  echo "\nTest Result: Address list"
  for patch in patches:
    if patch.address != -1:
      echo fmt"Pattern found at address: {patch.address:#X}"
    else:
      echo fmt"Pattern: {patch.pattern} not found"


  ###############################################
  # apply patches after confirmation or testing
  ###############################################
  echo "\nApplying patches..."
  for patch in patches:
    if patch.address == -1:
      echo "Skipping patch as pattern not found."
      continue

    # Open the file for writing and apply the patch
    try:
      if not open(file, filename, fmReadWriteExisting):
        raise newException(IOError, "Unable to open file for writing: " & filename)

      defer: close(file)
      setFilePos(file, patch.address)
      let bytesWritten = file.writeBytes(patch.data, 0, patch.data.len)
      if bytesWritten != patch.data.len:
        raise newException(IOError, fmt"Failed to write all bytes at address {patch.address:#X}")
      else:
        echo fmt"Successfully patched at address: {patch.address:#X}"
    except IOError as e:
      echo "Write Error: ", e.msg


###############################################################################
# Main block to execute the patching process with address display for testing
###############################################################################
when isMainModule:
  try:
    echo ("Before Patching: ", md5Checksum(FilePath)) # Check md5 before
    applyPatchesWithSearch(FilePath, Patches)  # Patches
    echo ("After Patching: ", md5Checksum(FilePath)) # Check md5 after
  except IOError as e:
    echo "Write Error: ", e.msg






