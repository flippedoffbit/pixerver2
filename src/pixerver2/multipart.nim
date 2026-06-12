## Multipart/form-data parser.
## Handles both regular fields and file uploads.

import strutils, tables
import types

proc getBoundary*(contentType: string): string =
  for part in contentType.split(';'):
    let p = part.strip()
    if p.startsWith("boundary="):
      return p[9..^1].strip(chars = {'"', ' ', '\''})

proc parseContentDisposition(header: string): tuple[name, filename: string] =
  result = ("", "")
  for part in header.split(';'):
    let p = part.strip()
    if p.startsWith("name="):
      result.name = p[5..^1].strip(chars = {'"', '\''})
    elif p.startsWith("filename="):
      result.filename = p[9..^1].strip(chars = {'"', '\''})

proc parseMultipart*(body, contentType: string): (Table[string, seq[string]], Table[string, seq[UploadedFile]]) =
  var fields = initTable[string, seq[string]]()
  var files  = initTable[string, seq[UploadedFile]]()

  let boundary = getBoundary(contentType)
  if boundary.len == 0:
    return (fields, files)

  let delimiter = "--" & boundary
  let parts = body.split(delimiter)

  # parts[0] is the preamble (empty), parts[^1] is "--\r\n" or "--"
  for i in 1 ..< parts.len - 1:
    var part = parts[i]

    # Strip leading CRLF
    if part.startsWith("\r\n"):
      part = part[2 .. ^1]
    elif part.startsWith("\n"):
      part = part[1 .. ^1]

    # Find header / body separator
    var sepLen = 4
    var sepIdx = part.find("\r\n\r\n")
    if sepIdx < 0:
      sepLen = 2
      sepIdx = part.find("\n\n")
    if sepIdx < 0:
      continue

    let headerStr = part[0 ..< sepIdx]
    var partBody  = part[sepIdx + sepLen .. ^1]

    # Strip trailing CRLF added by the boundary split
    if partBody.endsWith("\r\n"):
      partBody = partBody[0 .. ^3]
    elif partBody.endsWith("\n"):
      partBody = partBody[0 .. ^2]

    # Parse part headers
    var disposition    = ""
    var partCT         = "application/octet-stream"
    var partName       = ""
    var partFilename   = ""

    for line in headerStr.split("\r\n"):
      if line.len == 0: continue
      let lower = line.toLowerAscii()
      if lower.startsWith("content-disposition:"):
        disposition = line[20 .. ^1].strip()
        let (n, f) = parseContentDisposition(disposition)
        partName     = n
        partFilename = f
      elif lower.startsWith("content-type:"):
        partCT = line[13 .. ^1].strip()

    if partName.len == 0:
      continue

    if partFilename.len > 0:
      let f = UploadedFile(
        fieldName:   partName,
        filename:    partFilename,
        contentType: partCT,
        size:        partBody.len,
        data:        partBody
      )
      if partName notin files:
        files[partName] = @[]
      files[partName].add(f)
    else:
      if partName notin fields:
        fields[partName] = @[]
      fields[partName].add(partBody)

  return (fields, files)
