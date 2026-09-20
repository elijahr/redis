import redis, unittest, asyncdispatch, os, strutils

proc getClient(): Redis =
  redis.open(getEnv("REDIS_HOST", "localhost"), Port(parseInt(getEnv("REDIS_PORT", "6379"))))

proc getAsyncClient(): Future[AsyncRedis] {.async.} =
  await redis.openAsync(getEnv("REDIS_HOST", "localhost"), Port(parseInt(getEnv("REDIS_PORT", "6379"))))

suite "Redis Lua Scripting (Sync)":
  let r = getClient()
  discard r.flushdb()

  test "eval returning integer":
    let res = r.eval("return 42")
    check res.kind == vkInteger
    check res.intVal == 42
    check res.toInt() == 42
    check res == 42

  test "eval returning string":
    let res = r.eval("return 'hello from lua'")
    check res.kind == vkString
    check res.strVal == "hello from lua"
    check res.toStr() == "hello from lua"
    check res == "hello from lua"

  test "eval returning nil":
    let res = r.eval("return nil")
    check res.kind == vkNil
    check res.len == 0

  test "eval returning array":
    let res = r.eval("return {'foo', 'bar', 99}")
    check res.kind == vkList
    check res.len == 3
    check res[0] == "foo"
    check res[1] == "bar"
    check res[2] == 99

  test "eval with KEYS and ARGV":
    let script = "redis.call('set', KEYS[1], ARGV[1]); return redis.call('get', KEYS[1])"
    let res = r.eval(script, @["test:script:key"], @["script_value"])
    check res.kind == vkString
    check res.strVal == "script_value"
    check r.get("test:script:key") == "script_value"

  test "typed convenience helpers (evalInt, evalString, evalList)":
    check r.evalInt("return 100 + 200") == 300
    check r.evalString("return 'quick string'") == "quick string"
    let listRes = r.evalList("return {'x', 'y'}")
    check listRes.len == 2
    check listRes[0] == "x"
    check listRes[1] == "y"

  test "scriptLoad, scriptExists, evalSha, and scriptFlush":
    let script = "return 'cached sha execution'"
    let sha = r.scriptLoad(script)
    check sha.len == 40

    let exists = r.scriptExists(@[sha, "0000000000000000000000000000000000000000"])
    check exists == @[true, false]

    let res = r.evalSha(sha)
    check res.kind == vkString
    check res.strVal == "cached sha execution"

    check r.scriptFlush() == "OK"
    let existsAfterFlush = r.scriptExists(@[sha])
    check existsAfterFlush == @[false]

  test "eval raises on Lua syntax or runtime error":
    expect RedisError:
      discard r.eval("this is not valid lua code !!!")

    expect RedisError:
      discard r.eval("return redis.call('unknown_cmd')")

  discard r.flushdb()
  r.quit()

suite "Redis Lua Scripting (Async)":
  proc runAsyncTests() {.async.} =
    let r = await getAsyncClient()
    discard await r.flushdb()

    # Async eval integer
    let intRes = await r.eval("return 77")
    check intRes.kind == vkInteger
    check intRes.intVal == 77

    # Async eval string
    let strRes = await r.eval("return 'async lua'")
    check strRes.kind == vkString
    check strRes.strVal == "async lua"

    # Async eval with KEYS and ARGS
    let script = "redis.call('set', KEYS[1], ARGV[1]); return redis.call('get', KEYS[1])"
    let setGetRes = await r.eval(script, @["test:async:key"], @["async_val"])
    check setGetRes.strVal == "async_val"

    # Async scriptLoad & evalSha
    let sha = await r.scriptLoad("return 'async sha'")
    check sha.len == 40
    let shaRes = await r.evalSha(sha)
    check shaRes.strVal == "async sha"

    discard await r.flushdb()
    await r.quit()

  waitFor runAsyncTests()
