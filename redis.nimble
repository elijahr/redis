# Package

version       = "0.5.0"
author        = "Dominik Picheta"
description   = "Official redis client for Nim"
license       = "MIT"

srcDir = "src"

# Dependencies

requires "nim >= 0.11.0"

import os, strutils, algorithm

task docs, "Build documentation":
  exec "nim doc --index:on -o:docs/redis.html src/redis.nim"

task test, "Run tests":
  var testFiles: seq[string] = @[]
  for f in walkDirRec("tests"):
    if f.endsWith(".nim") and not f.endsWith("tawaitorder.nim"):
      testFiles.add(f)
  testFiles.sort()

  for threadFlag in ["", "--threads:on"]:
    for file in testFiles:
      exec "nim c -r " & (if threadFlag.len > 0: threadFlag & " " else: "") & file
