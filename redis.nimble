# Package

version       = "0.5.0"
author        = "Dominik Picheta"
description   = "Official redis client for Nim"
license       = "MIT"

srcDir = "src"

# Dependencies

requires "nim >= 0.11.0"

task docs, "Build documentation":
  exec "nim doc --index:on -o:docs/redis.html src/redis.nim"

task test, "Run tests":
  exec "nim c -r tests/main.nim"
  exec "nim c -r --threads:on tests/main.nim"
  exec "nim c -r tests/tclosedconn.nim"
  exec "nim c -r tests/tscripting.nim"

task test_matrix, "Run tests against Redis 5, 6, 7 matrix locally":
  exec "bash tests/run_matrix.sh"
