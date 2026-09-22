# redis [![CI](https://github.com/nim-lang/redis/actions/workflows/ci.yml/badge.svg)](https://github.com/nim-lang/redis/actions/workflows/ci.yml)

A Redis and Valkey client for Nim.

## Compatibility

Tested and verified against:
* **Redis**: 5.0, 6.0, 6.2, 7.0, 7.2+
* **Valkey**: 7.2, 8.0+
* **Nim**: 2.0.x, 2.2.x, and nightly `devel`

## Installation

Add the following to your `.nimble` file:

```
# Dependencies

requires "redis >= 0.2.0"
```

Or, to install globally to your Nimble cache run the following command:

```
nimble install redis
```

## Usage

```nim
import redis, asyncdispatch

proc main() {.async.} =
  ## Open a connection to Redis running on localhost on the default port (6379)
  let redisClient = await openAsync()

  ## Set the key `nim_redis:test` to the value `Hello, World`
  await redisClient.setk("nim_redis:test", "Hello, World")

  ## Get the value of the key `nim_redis:test`
  let value = await redisClient.get("nim_redis:test")

  assert(value == "Hello, World")

waitFor main()
```

There is also a synchronous version of the client, that can be created using the `open()` procedure rather than `openAsync()`.

## License

Copyright (C) 2015, 2017 Dominik Picheta and contributors. All rights reserved.
