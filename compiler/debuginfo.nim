#
#
#           The Nim Compiler
#        (c) Copyright 2016 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## The compiler can generate debuginfo to help debuggers in translating back from C/C++/JS code
## to Nim. The data structure has been designed to produce something useful with Nim's marshal
## module.

type
  FilenameHash* = uint32
  FilenameMapping* = object
    package*, file*: string
    mangled*: FilenameHash
  EnumDesc* = object
    size*: int
    owner*: FilenameHash
    id*: int
    name*: string
    values*: seq[(string, int)]
  DebugInfo* = object
    version*: int
    files*: seq[FilenameMapping]
    enums*: seq[EnumDesc]
    conflicts*: bool

proc sdbmHash(hash: FilenameHash, c: char): FilenameHash {.inline.} =
  return FilenameHash(c) + (hash shl 6) + (hash shl 16) - hash

proc sdbmHash(package, file: string): FilenameHash =
  template `&=`(x, c) = x = sdbmHash(x, c)
  result = 0
  for i in 0..<package.len:
    result &= package[i]
  result &= '.'
  for i in 0..<file.len:
    result &= file[i]

proc register*(self: var DebugInfo; package, file: string): FilenameHash =
  result = sdbmHash(package, file)
  for f in self.files:
    if f.mangled == result:
      if f.package == package and f.file == file: return
      self.conflicts = true
      break
  self.files.add(FilenameMapping(package: package, file: file, mangled: result))

proc hasEnum*(self: DebugInfo; ename: string; id: int; owner: FilenameHash): bool =
  for en in self.enums:
    if en.owner == owner and en.name == ename and en.id == id: return true

proc registerEnum*(self: var DebugInfo; ed: EnumDesc) =
  self.enums.add ed

proc init*(self: var DebugInfo) =
  self.version = 1
  self.files = @[]
  self.enums = @[]

var gDebugInfo*: DebugInfo
debuginfo.init gDebugInfo

import marshal, streams

proc writeDebugInfo*(self: var DebugInfo; file: string) =
  let s = newFileStream(file, fmWrite)
  store(s, self)
  s.close

proc writeDebugInfo*(file: string) = writeDebugInfo(gDebugInfo, file)

proc loadDebugInfo*(self: var DebugInfo; file: string) =
  let s = newFileStream(file, fmRead)
  load(s, self)
  s.close

proc loadDebugInfo*(file: string) = loadDebugInfo(gDebugInfo, file)