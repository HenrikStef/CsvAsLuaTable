require("csv")

local csvPath = "./test.csv"
local hasHeader = true
local key = "Language"

csv1 = Csv:new(csvPath, key, hasHeader)
csv1:load()
csv1:parse()
csv1:tprint()
