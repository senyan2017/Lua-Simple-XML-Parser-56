---
-- Regression test suite for xmlSimple.lua
-- Covers: loadFile in pure Lua, properties() correctness, duplicate attributes,
--         error handling, full pipeline integrity.
--
-- Run:  lua test_regression.lua
--

local passed = 0
local failed = 0
local errors = {}

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  [PASS] " .. name)
    else
        failed = failed + 1
        table.insert(errors, name .. ": " .. tostring(err))
        print("  [FAIL] " .. name .. " -- " .. tostring(err))
    end
end

local function assertEq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s",
            msg or "assertion", tostring(expected), tostring(actual)), 2)
    end
end

local function assertTrue(cond, msg)
    if not cond then
        error(msg or "expected true", 2)
    end
end

-- =========================================================================
print("=== xmlSimple.lua Regression Tests ===\n")

-- Load the module
local xmlModule = require("xmlSimple")
local xml = xmlModule.newParser()

-- =========================================================================
print("--- 1. ParseXmlText basic parsing (string input) ---")

local xmlString = '<root attr1="val1"><child attr2="val2">text</child></root>'
local parsed = xml:ParseXmlText(xmlString)

test("ParseXmlText returns a table", function()
    assertTrue(type(parsed) == "table", "parsed result should be a table")
end)

test("Root child node accessible", function()
    assertTrue(parsed.root ~= nil, "root node should exist")
    assertEq(parsed.root:name(), "root", "root name")
end)

test("Simple attribute via @attr access", function()
    assertEq(parsed.root["@attr1"], "val1", "root @attr1")
end)

test("Child node value", function()
    assertEq(parsed.root.child:value(), "text", "child value")
end)

test("Child attribute via @attr access", function()
    assertEq(parsed.root.child["@attr2"], "val2", "child @attr2")
end)

-- =========================================================================
print("\n--- 2. properties() metadata correctness ---")

test("properties() returns correct name and value for single attribute", function()
    local props = parsed.root:properties()
    assertEq(#props, 1, "root should have 1 property")
    assertEq(props[1].name, "attr1", "property name")
    assertEq(props[1].value, "val1", "property value")
end)

test("properties() returns correct name and value for child attribute", function()
    local props = parsed.root.child:properties()
    assertEq(#props, 1, "child should have 1 property")
    assertEq(props[1].name, "attr2", "property name")
    assertEq(props[1].value, "val2", "property value")
end)

test("properties() with multiple distinct attributes", function()
    local p = xml:ParseXmlText('<node a="1" b="2" c="3"/>')
    local props = p.node:properties()
    assertEq(#props, 3, "should have 3 properties")
    assertEq(props[1].name, "a", "first prop name")
    assertEq(props[1].value, "1", "first prop value")
    assertEq(props[2].name, "b", "second prop name")
    assertEq(props[2].value, "2", "second prop value")
    assertEq(props[3].name, "c", "third prop name")
    assertEq(props[3].value, "3", "third prop value")
end)

-- =========================================================================
print("\n--- 3. Duplicate attribute handling ---")

local dupXml = '<item tag="first" tag="second" tag="third"/>'
local dupParsed = xml:ParseXmlText(dupXml)

test("Duplicate attributes accessible as array via @attr", function()
    local tags = dupParsed.item["@tag"]
    assertTrue(type(tags) == "table", "@tag should be a table for duplicates")
    assertEq(tags[1], "first", "first duplicate")
    assertEq(tags[2], "second", "second duplicate")
    assertEq(tags[3], "third", "third duplicate")
end)

test("Duplicate attributes all appear in properties()", function()
    local props = dupParsed.item:properties()
    assertEq(#props, 3, "should have 3 property entries")
    assertEq(props[1].name, "tag", "first prop name")
    assertEq(props[1].value, "first", "first prop value")
    assertEq(props[2].name, "tag", "second prop name")
    assertEq(props[2].value, "second", "second prop value")
    assertEq(props[3].name, "tag", "third prop name")
    assertEq(props[3].value, "third", "third prop value")
end)

test("numProperties counts all entries including duplicates", function()
    assertEq(dupParsed.item:numProperties(), 3, "numProperties should be 3")
end)

-- Two duplicate attributes (the README example)
local dupXml2 = '<three four="five" four="six"/>'
local dupParsed2 = xml:ParseXmlText(dupXml2)

test("Two duplicate attributes: @attr[1] and @attr[2]", function()
    assertEq(dupParsed2.three["@four"][1], "five", "first dup")
    assertEq(dupParsed2.three["@four"][2], "six", "second dup")
end)

test("Two duplicate attributes in properties()", function()
    local props = dupParsed2.three:properties()
    assertEq(#props, 2, "should have 2 property entries")
    assertEq(props[1].name, "four", "first prop name")
    assertEq(props[1].value, "five", "first prop value")
    assertEq(props[2].name, "four", "second prop name")
    assertEq(props[2].value, "six", "second prop value")
end)

-- =========================================================================
print("\n--- 4. loadFile in pure Lua environment ---")

test("loadFile reads XML file without Corona system module", function()
    local result, err = xml:loadFile("test_sample.xml")
    assertTrue(result ~= nil, "loadFile should return parsed result, err=" .. tostring(err))
    assertTrue(err == nil, "err should be nil on success")
end)

test("loadFile parsed result has correct structure", function()
    local result, err = xml:loadFile("test_sample.xml")
    assertTrue(result ~= nil, "result should not be nil")
    assertTrue(result.test ~= nil, "test node should exist")
    assertEq(result.test["@one"], "two", "test @one attribute")
end)

test("loadFile: child nodes and duplicate attrs from file", function()
    local result = xml:loadFile("test_sample.xml")
    -- <three four="five" four="six"/> is the first <three>
    local firstThree = result.test.three[1]
    assertEq(firstThree["@four"][1], "five", "first four attr")
    assertEq(firstThree["@four"][2], "six", "second four attr")
    -- <three>eight</three> is the second <three>
    local secondThree = result.test.three[2]
    assertEq(secondThree:value(), "eight", "second three value")
end)

test("loadFile: properties() correct for file-loaded nodes", function()
    local result = xml:loadFile("test_sample.xml")
    local props = result.test:properties()
    assertEq(#props, 1, "test node should have 1 property")
    assertEq(props[1].name, "one", "property name from file")
    assertEq(props[1].value, "two", "property value from file")
end)

-- =========================================================================
print("\n--- 5. Error handling for file loading ---")

test("loadFile returns nil and error message for missing file", function()
    local result, err = xml:loadFile("nonexistent_file.xml")
    assertTrue(result == nil, "result should be nil for missing file")
    assertTrue(err ~= nil, "error message should not be nil")
    assertTrue(type(err) == "string", "error should be a string")
    assertTrue(#err > 0, "error message should not be empty")
end)

test("loadFile error message is usable by caller", function()
    local result, err = xml:loadFile("/no/such/path/file.xml")
    assertTrue(result == nil, "result should be nil")
    assertTrue(err ~= nil, "err should be set")
    -- The error message should contain something useful
    assertTrue(type(err) == "string" and #err > 0, "err should be a non-empty string")
end)

-- =========================================================================
print("\n--- 6. Full pipeline: file -> parse -> node structure -> attributes ---")

test("End-to-end: file load through node traversal", function()
    local result, err = xml:loadFile("test_sample.xml")
    assertTrue(result ~= nil, "loadFile should succeed")

    -- Traverse the full tree
    local testNode = result.test
    assertEq(testNode:name(), "test", "root node name")
    assertEq(testNode["@one"], "two", "root attribute")

    -- Children accessible by name
    assertTrue(testNode.three ~= nil, "three nodes should exist")
    assertTrue(testNode.nine ~= nil, "nine node should exist")

    -- nine node
    assertEq(testNode.nine["@ten"], "eleven", "nine @ten")
    assertEq(testNode.nine:value(), "twelve", "nine value")

    -- children() array
    local children = testNode:children()
    assertTrue(#children >= 3, "test should have at least 3 children")
end)

-- =========================================================================
print("\n--- 7. newNode API backward compatibility ---")

test("newNode basic API", function()
    local node = xmlModule.newNode("testName")
    assertEq(node:name(), "testName", "node name")
    node:setName("newName")
    assertEq(node:name(), "newName", "renamed node")
    node:setValue("myValue")
    assertEq(node:value(), "myValue", "node value")
end)

test("newNode addProperty and properties()", function()
    local node = xmlModule.newNode("n")
    node:addProperty("key", "val")
    assertEq(node["@key"], "val", "@key shortcut")
    local props = node:properties()
    assertEq(#props, 1, "one property")
    assertEq(props[1].name, "key", "prop name")
    assertEq(props[1].value, "val", "prop value")
    assertEq(node:numProperties(), 1, "numProperties")
end)

test("newNode addChild and children()", function()
    local parent = xmlModule.newNode("parent")
    local child = xmlModule.newNode("child")
    parent:addChild(child)
    assertEq(#parent:children(), 1, "one child")
    assertEq(parent:numChildren(), 1, "numChildren")
    assertTrue(parent.child ~= nil, "child accessible by name")
end)

-- =========================================================================
print("\n--- 8. XML entity decoding ---")

test("FromXmlString decodes standard entities", function()
    local p = xml:ParseXmlText('<n a="&amp;&lt;&gt;&quot;"/>')
    assertEq(p.n["@a"], '&<>"', "entity decoding")
end)

-- =========================================================================
-- Summary
print("\n========================================")
print(string.format("Results: %d passed, %d failed, %d total",
    passed, failed, passed + failed))

if failed > 0 then
    print("\nFailed tests:")
    for _, e in ipairs(errors) do
        print("  - " .. e)
    end
    os.exit(1)
else
    print("\nAll tests passed!")
    os.exit(0)
end
