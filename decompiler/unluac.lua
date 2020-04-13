local changes = {}
protos = {}
local registers = {} -- Registers act like their own independent variable.
--[[
    registers = {
        { -- RA "0"
            game
        }
    }

    for getglobal game 0
]]

-- 1st thing is the number of total protos (like robloxs bytecode format)
-- if nprotos != 0:
-- 1st part of each proto will be its number (0 -> nprotos)
-- 2nd part will be the AOB of the proto
-- 3rd part will be the body of the proto
-- ending part will be --endproto

function getargs(inst)
    args = {}
    for arg in inst:gmatch("%w+") do table.insert(args, arg) end
    return args
end

local lastProtoPosition = 0
local tempInstructions = {}
for s in script:gmatch("[^\r\n]+") do
    table.insert(tempInstructions, s)
end

for i,v in pairs(tempInstructions) do
    if v:match("pcall") and tempInstructions[i + 1]:match("tforloop") then -- c++ was just like nä
        local oldforlooop = getargs(tempInstructions[i+1])
        local pcallinfo = getargs(v)
        tempInstructions[i] = "tforloop "..pcallinfo[2].." "..pcallinfo[3].." "..pcallinfo[4].." "..oldforlooop[2]
        tempInstructions[i+1] = "0"
    end
end

--[[
protos are ordered like fuckin uh
function y() -- 2nd proto, has reference to 1st
	function z() -- 1st proto
		print(y())
	end
	return z()
end
y() -- reference to 2nd

]]

insideProto = false
dInstruction = 0

forloop_I = 0
forloop_V = 0
indent = 0

local nprotos = tonumber(tempInstructions[1])
--print("total protos: "..nprotos)

local nestedProtos = {}
for i= 1,nprotos do
    local proto = {
        ["code"] = {},
        ["protos"] = {},
        ["registers"] = {},
        ["source"] = "",
        ["lineinfo"] = {}, -- no cap is just for indentation
        ["vararg"] = false,
        ["locals"] = {},
        ["calls"] = {},
    }
    for i,v in pairs(tempInstructions) do
        if (nprotos > 0) then
        if v == "--endproto" then
            --print"found end of proto"
            nprotos = nprotos - 1
            table.insert(protos, proto)
            proto = {
                ["code"] = {},
                ["protos"] = {},
                ["registers"] = {},
                ["source"] = "",
                ["lineinfo"] = {}, -- no cap is just for indentation
                ["vararg"] = false,
                ["locals"] = {},
                ["calls"] = {},
            }
    else
        if (v == "vararg") then 
            proto.vararg = true
        else
            table.insert(proto.code, v)
        end
        --print"coding proto"
        end
    end

    end
end

local inside_mainproto = false
local mainProto =  {
    ["code"] = {},
    ["protos"] = {},
    ["registers"] = {},
    ["source"] = "",
    ["lineinfo"] = {},
    ["vararg"] = false,
    ["locals"] = {},
    ["calls"] = {},
}

for i,v in pairs(tempInstructions) do
    if (v == "--mainproto") then
        inside_mainproto = true
    else
        if (inside_mainproto) then
            table.insert(mainProto.code, v)
        end
    end
end
table.insert(protos, mainProto)

function makeRegister()
    local reg = {}
    setmetatable(reg, {
        __newindex = function(t,k,v)

        end
    })
end

local finalScript = ""

function scr(x,p)
    local toindent = " "
    toindent = toindent:rep(indent * 5)
    table.insert(p.lineinfo, indent)
    p.source = p.source..toindent..tostring(x)
end

function argToStr(start, arg)
    local name = ""
    for i = start,#args-1 do
        name = name..tostring(args[i])
        if (i ~= #args-1) then
            name = name.." "
        end
    end

    return name
end

function countExtraInstructions(code, lowerbound, upperbound)
    local extras = 0
    for i = lowerbound,upperbound do
        local args = getargs(code[i])
        local op = args[1]
        if (op == "getglobal" or op == "setglobal" or op == "eqn" or op == "eq" or op == "lt" or op == "ltn" or op == "le" or op == "leqn" or op == "jmp") then
            extras = extras + 1
        end
    end
    return extras
end

function liCheck(proto, i)
    local nextInst = proto.code[i+1]
    local args = getargs(nextInst)
    if (op == "LINEINFO") then
        return ""
    else
        return "\n"
    end
end

function decompile(proto)
  -- for _P,proto in pairs(protos) do
        local instructions = proto.code

        local nNamecalls = 0
        
        -- PRESCAN
        local allMoves = {}
        for i,inst in pairs(instructions) do
            local args = getargs(inst)
            local op = args[1]
            if (op == "move") then
                table.insert(allMoves, inst)
            end
        end
        local identicalMoves = {}
        for i,move in pairs(allMoves) do
            local args = getargs(move)
            if (identicalMoves["_"..tostring(args[2])]) then
                table.insert(identicalMoves["_"..tostring(args[2])], move)
            else
                identicalMoves["_"..tostring(args[2])] = {move}
            end
        end
        
        for i,moveTable in pairs(identicalMoves) do
            if #moveTable > 1 then
                --scr("local v"..tostring(getargs(moveTable[1])[2]).." = nil\n", proto)
                --print("abcdd: "..tostring(moveTable[2]).."\n")
                proto.locals[moveTable[2]] = moveTable[1]
            end
        end

        for i,inst in pairs(instructions) do
           
            local args = getargs(inst)
            local op = args[1]
            local end_needed = false
            --print("instruction "..op)
            if (op == "LINEINFO") then
                local nNewLines = args[2]
                for i = 1,nNewLines do
                    scr("\n", proto)
                end
            end
            if (op == "MARKEND") then
                inst = inst:sub(8)
                args = getargs(inst)
                op = args[1]
                end_needed = true
            end
            if (op == "getglobal") then
                proto.registers["_"..args[#args]] = args[2]
            end
            if (op == "pushstring") then
                proto.registers["_"..args[#args]] = '"'..argToStr(2, args)..'"'
            end
            if (op == "pushnumber") then
                proto.registers["_"..args[#args]] = args[2]
            end
            if (op == "pushnil") then
                proto.registers["_"..args[#args]] = "nil"
            end
            if (op == "pushboolean") then
                if (tonumber(args[2]) == 1) then
                    proto.registers["_"..args[#args]] = "true"
                else
                    proto.registers["_"..args[#args]] = "false"
                end
            end
            if (op == "setglobal") then
                local oldvalue = proto.registers["_"..args[#args]]
                if (not oldvalue) then
                    oldvalue = "G1"
                end
                scr(args[2].." = "..oldvalue.."\r\n", proto)
            end
            if (op == "getfield") then
                local targetReg = proto.registers["_"..args[2]]
                proto.registers["_"..args[#args]] = targetReg.."."..args[3]
            end
            if (op == "setfield") then
                local val = proto.registers["_"..args[2]]
                scr(proto.registers["_"..args[3]].."."..argToStr(4, args).." = "..val, proto)
            end
            if (op == "addK") then
                local to = proto.registers["_"..args[2]]
                proto.registers["_"..args[#args]] = to.." + "..args[3]
            end
            if (op == "addR") then
                local to = proto.registers["_"..args[2]]
                proto.registers["_"..args[#args]] = to.." + "..proto.registers["_"..args[3]]
            end
            if (op == "subK") then
                local to = proto.registers["_"..args[2]]
                proto.registers["_"..args[#args]] = to.." - "..args[3]
            end
            if (op == "subR") then
                local to = proto.registers["_"..args[2]]
                proto.registers["_"..args[#args]] = to.." - "..proto.registers["_"..args[3]]
            end
            if (op == "mulK") then
                local to = proto.registers["_"..args[2]]
                proto.registers["_"..args[#args]] = to.." * "..args[3]
            end
            if (op == "mulR") then
                local to = proto.registers["_"..args[2]]
                proto.registers["_"..args[#args]] = to.." * "..proto.registers["_"..args[3]]
            end
            if (op == "divK") then
                local to = proto.registers["_"..args[2]]
                proto.registers["_"..args[#args]] = to.." / "..args[3]
            end
            if (op == "divR") then
                local to = proto.registers["_"..args[2]]
                proto.registers["_"..args[#args]] = to.." / "..proto.registers["_"..args[3]]
            end
            if (op == "powK") then
                local to = proto.registers["_"..args[2]]
                proto.registers["_"..args[#args]] = to.." ^ "..args[3]
            end
            if (op == "powR") then
                local to = proto.registers["_"..args[2]]
                proto.registers["_"..args[#args]] = to.." ^ "..proto.registers["_"..args[3]]
            end
            if (op == "modK") then
                local to = proto.registers["_"..args[2]]
                proto.registers["_"..args[#args]] = to.." % "..args[3]
            end
            if (op == "modR") then
                local to = proto.registers["_"..args[2]]
                proto.registers["_"..args[#args]] = to.." % "..proto.registers["_"..args[3]]
            end
            if (op == "clearstack") then
                local nparams = tonumber(args[2])
                for i = 1,nparams do
                    proto.registers["_"..i-1] = "a"..tostring(i)..", ";
                end
            end

            if (op == "closure") then
                --local closurePtr = tonumber(args[2]) + 1
                local closureAob = ""
                for a = 2,#args-1 do
                    closureAob = closureAob..args[a].."/"
                end
                --print(closureAob.." is closure aob")
                local matchingClosure = 0
                for x,p in pairs(protos) do
                    local protoAOB = p.code[3]
                    if (protoAOB == closureAob) then
                        matchingClosure = x
                    end
                end
                local closureSource = protos[matchingClosure].source
                local funcSource = "function("
                --print("1st code: "..protos[matchingClosure].code[4])
                local nargsP = getargs(protos[matchingClosure].code[4])
                if (protos[matchingClosure].vararg) then
                    funcSource = funcSource.."..."
                end
                if (nargsP[1] == "clearstack") then
                    for i = 1,tonumber(nargsP[2]) do
                        funcSource = funcSource.."a"..tostring(i)
                        if (i < tonumber(nargsP[2])) then
                            funcSource = funcSource..", "
                        end
                    end
                end
                funcSource = funcSource..")\n"..closureSource.."end\n"
                proto.registers["_"..args[#args]] = funcSource
            end
            if (op == "move") then
                proto.registers["_"..args[#args]] = proto.registers["_"..args[2]]
                for x,loc in pairs(proto.locals) do
                    if (loc == inst) then
                       proto.registers["_"..args[#args]] = "v"..args[2]
                       proto.locals[args[2]] =  proto.registers["_"..args[2]]
                    end
                end
              
            end
            if (op == "len") then
                proto.registers["_"..args[#args]] = "#"..proto.registers["_"..args[2]]
            end
            if (op == "forloop") then
                local A = tonumber(args[#args])
                local nstep = proto.registers["_"..tostring(A + 2)]
                local ninit = proto.registers["_"..tostring(A + 1)]
                local nlimit = proto.registers["_"..tostring(A)]

                proto.registers["_"..tostring(A + 2)] = "i_"..tostring(forloop_I)
                local toappend = "for i_"..tostring(forloop_I).." = "..ninit..", "..nlimit
                if (nstep ~= "1") then
                    toappend = toappend..", "..nstep
                end
                toappend = toappend.." do"..liCheck(proto, i)
                scr(toappend, proto)
                forloop_I = forloop_I + 1
                indent = indent + 1
            end
            if (op == "tforloop") then
                local A = tonumber(args[#args])
                local table = proto.registers["_"..tostring(A+1)]
                local v = tostring(forloop_V)
                local i = tostring(forloop_I)
                
                proto.registers["_"..tostring(A + 4)] = "v_"..v
                proto.registers["_"..tostring(A + 3)] = "i_"..i
                local loop = "for i_"..i..",v_"..v.." in pairs("..table..") do"..liCheck(proto, i)
                forloop_V = forloop_V + 1
                forloop_I = forloop_I + 1
                scr(loop, proto)
                indent = indent + 1
                end
            if (op == "end") then
                indent = indent - 1
                scr("end\n", proto)
            end
            if (op == "jmp") then
                
            end
            if (op == "else") then
                local jumpLength = tonumber(args[2])
                local extras = countExtraInstructions(instructions, i, i + jumpLength)
                local endInst = jumpLength - extras
                scr("else\n", proto)
                local backupinst = instructions[i + endInst]
                instructions[i + endInst] = "MARKEND " ..backupinst
            end
            if (op == "eqn" or op == "eq" or op == "lt" or op == "ltn" or op == "le" or op == "leqn") then
                local actual_operator = ""
                local jumpLength = tonumber(args[2]) - 1
                local c = tonumber(args[3])
                local b = tonumber(args[4]);

                if (op == "eq") then
                    actual_operator = "~="
                elseif (op == "eqn") then
                    actual_operator = "=="
                elseif (op == "lt") then
                    actual_operator = "<"
                elseif (op == "ltn") then
                    actual_operator = ">"
                elseif (op == "le") then
                    actual_operator = "<="
                elseif (op == "leqn") then
                    actual_operator = ">="
                end

                local extras = countExtraInstructions(instructions, i, i + jumpLength)
                scr("if ("..proto.registers["_"..tostring(b)].." "..actual_operator.." "..proto.registers["_"..tostring(c)]..") then"..liCheck(proto, i), proto)
                local tojump = jumpLength - extras
                local endInst = instructions[i+tojump]
               --[[ if (getargs(endInst)[1] == "jmp") then
                    instructions[i+tojump] = "else "..tostring(getargs(endInst)[2])
                else
                    instructions[i+tojump] = "MARKEND "..instructions[i+tojump]
                end]]
               
            end
            if (op == "testn") then
                scr("if ("..proto.registers["_"..tostring(args[#args])]..") then"..liCheck(proto, i), proto); 
            end
            if (op == "test") then
                scr("if (not "..proto.registers["_"..tostring(args[#args])]..") then"..liCheck(proto, i), proto); 
            end
            if (op == "concat") then
                local A = tonumber(args[#args])
                local B = args[2]
                local C = args[3]

                proto.registers["_"..tostring(A)] = tostring(proto.registers["_"..tostring(B)])..".."..tostring(proto.registers["_"..tostring(C)])
            end
            if (op == "vararg") then
                local A = tonumber(args[#args])
                local B = args[2]
                local C = args[3]

                proto.registers["_"..tostring(A)] = " ... "
            end
            if (op == "namecall") then
                local oldinst = inst
                local method = args[2]
                inst = instructions[i + 1]
                args = getargs(inst)
                local nargs = args[2]

                local call =  proto.registers["_"..args[#args]]..":"..method.."("

                for x = i-nargs+1,i-1 do
                    local oargs = getargs(instructions[x])
                   call = call..proto.registers["_"..oargs[#oargs]]
                   if x < i-1 then
                        call = call..", "
                   end
                end
                call = call..")"

                nNamecalls = nNamecalls + 1
                local variableName = "n"..tostring(nNamecalls)

                proto.registers["_"..args[#args]] = variableName--call
                instructions[i+1] = "0"

                table.insert(proto.calls, {nNamecalls, proto.source:len()})
                
                scr("local "..variableName.." = "..call.."\n", proto)
                -- look for if its referenced anywhere below
                -- if it's not, write it in.
                --scr(call, proto)
                --print("call: "..call)
            end
            if (op == "pcall") then
                local ptr = args[#args]
                local nargs = args[2]
                local call = proto.registers["_"..ptr].."("
                for ARG=i-nargs,i-1 do
                    local oargs = getargs(instructions[ARG])
                    call = call..proto.registers["_"..oargs[#oargs]]
                    if (ARG <= tonumber(nargs)) then
                       call = call..", " 
                    end
                end
                call = call..")\r\n"
                nNamecalls = nNamecalls + 1
                local varname = "n"..nNamecalls
                
                proto.registers["_"..args[#args]] = varname
                table.insert(proto.calls, {nNamecalls, proto.source:len()})
                scr("local "..varname.." = "..call, proto)
            end
            if (end_needed) then
                scr("end\n", proto)
            end_needed = false
            end
        end

        -- clean up unncessecary calls 
        for i,v in pairs(proto.calls) do
            local callNum = v[1]
            local callPos = v[2]

            local actualOffset = tostring(math.log10(callNum)):sub(1,1) + 1
            local oldsource = proto.source
            local varname = proto.source:sub(callPos+7, callPos + 7 + actualOffset)
            
            local remaining = proto.source:sub(callPos + 9 + actualOffset)
            if (not remaining:find(varname)) then
                local changedSource = proto.source:sub(0, callPos)
                changedSource = changedSource..(proto.source:sub(callPos+11+actualOffset))
                proto.source = changedSource
                for x=1,#proto.calls do
                    local call = proto.calls[x]
                    call[2] = call[2] - (oldsource:len()-proto.source:len())
                end
            end
        end
        
        for i,v in pairs(proto.locals) do
            
            --if (v:sub(2,2) ~= "_") then
           -- print("i: "..tostring(i))
           -- print("ton: "..tostring(tonumber(i)))
            if (tonumber(i) ~= nil) then
                local oldsrc = proto.source
                proto.source = "local v"..tostring(i).." = "..tostring(v).."\n"..oldsrc 
            end
           -- end
        end
        
        

        local sourceLines = {}
        local src = proto.source
        local newSource = ""
        for line in src:gmatch("[^\r\n]+") do
            table.insert(sourceLines, line)
        end
        
        for i,v in pairs(sourceLines) do
            if v:find("pcall") then
                local change = ""
                local pos = v:find("pcall")
                --print("POS ATG "..tostring(pos))
                local argarray = v:sub(pos+6)
                argarray = argarray:sub(0, argarray:len()-1)
                local args = {}
                for arg in argarray:gmatch('([^,]+)') do
                   table.insert(args, arg)
                end
                local func = args[1]
                change = func.."("
                for x = 2,#args do
                    change = change..args[x]:sub(2)
                    if (x > #args) then
                        change = change..", "
                    end
                end
                change = change..")"
                local toindent = " "
                --toindent = toindent:rep(proto.lineinfo[i] * 5)
                v = toindent..change
            end

            newSource = newSource..v.."\n"
        end
        proto.source = newSource

end

for i,p in pairs(protos) do
    --print("PROTO AOB: "..p.code[3])
    decompile(p)
   -- print("PROTO SOURCE: "..tostring(p.source))
   -- print("-----")
    if i == #protos then
        finalScript = p.source
    end
end
print"hi"

--print("decompiled: \r\n")
--print(finalScript)
--[[
outputfile = io.open("decompiled.lua", "w+")
io.output(outputfile)
io.write(finalScript)
io.close(outputfile)]]
print("final script: "..finalScript)
return finalScript