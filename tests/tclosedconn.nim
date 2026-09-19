# This test suite uses an in-process mock that accepts a connection, 
# reads one command and closes the socket without replying. Each 
# command below should raise RedisError; today they all return
# dummy values, so every test fails.

import asyncnet, asyncdispatch, strutils, unittest, redis

const mockPort = 5314.Port

var mockServer: AsyncSocket

proc mockDroppingServer() {.async.} =
  mockServer = newAsyncSocket()
  mockServer.setSockOpt(OptReuseAddr, true)
  mockServer.bindAddr(mockPort)
  mockServer.listen()

  while not mockServer.isClosed():
    let c = try:
      await mockServer.accept()
    except CatchableError:
      break
    # Read one complete RESP request, whatever the command or arity:
    # "*<argc>" followed by argc bulk strings of two lines each
    # ("$<len>", payload). Draining the full request before closing
    # makes the close a clean EOF for the client rather than a reset.
    let header = try:
      await c.recvLine()
    except CatchableError:
      c.close()
      continue
    if header.len > 1 and header[0] == '*':
      try:
        for _ in 1 .. 2 * parseInt(header.substr(1)):
          discard await c.recvLine()
      except CatchableError:
        discard
    c.close()

suite "closed connection handling":
  asyncCheck mockDroppingServer()

  test "get raises on closed connection instead of returning \"\"":
    proc run() {.async.} =
      let r = await openAsync("localhost", mockPort)
      expect RedisError:
        discard await r.get("some:key")
    waitFor run()

  test "exists raises on closed connection instead of returning false":
    proc run() {.async.} =
      let r = await openAsync("localhost", mockPort)
      expect RedisError:
        discard await r.exists("some:key")
    waitFor run()

  test "ttl raises on closed connection instead of returning -1":
    # The worst case: -1 is also a legitimate TTL reply (no expiration),
    # so the old dummy value was indistinguishable from real data.
    proc run() {.async.} =
      let r = await openAsync("localhost", mockPort)
      expect RedisError:
        discard await r.ttl("some:key")
    waitFor run()

  test "keys raises on closed connection instead of returning @[]":
    proc run() {.async.} =
      let r = await openAsync("localhost", mockPort)
      expect RedisError:
        discard await r.keys("*")
    waitFor run()

  test "setk raises on closed connection instead of succeeding":
    proc run() {.async.} =
      let r = await openAsync("localhost", mockPort)
      expect RedisError:
        await r.setk("some:key", "value")
    waitFor run()

if mockServer != nil and not mockServer.isClosed():
  mockServer.close()
