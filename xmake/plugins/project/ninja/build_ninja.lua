--!A cross-platform build utility based on Lua
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- Copyright (C) 2015-2020, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        build_ninja.lua
--

-- imports
import("core.project.config")
import("core.project.project")
import("core.platform.platform")
import("core.language.language")
import("core.tool.linker")
import("core.tool.compiler")
import("lib.detect.find_tool")

-- add header
function _add_header(ninjafile)
    ninjafile:print([[# this is the build file for project %s
# it is autogenerated by the xmake build system.
# do not edit by hand.
]], project.name() or "")
    ninjafile:print("ninja_required_version = 1.5.1")
    ninjafile:print("")
end

-- add rules for generator
function _add_rules_for_generator(ninjafile)
    ninjafile:print("rule gen")
    ninjafile:print(" command = xmake project -k ninja")
    ninjafile:print(" description = regenerating ninja files")
    ninjafile:print("")
end

-- add rules for complier (gcc)
function _add_rules_for_compiler_gcc(ninjafile, sourcekind, program)
    local ccache = config.get("ccache") ~= false and find_tool("ccache")
    ninjafile:print("rule %s", sourcekind)
    ninjafile:print(" command = %s%s $ARGS -MMD -MF $out.d -o $out -c $in", ccache and (ccache.program .. " ") or "", program)
    ninjafile:print(" deps = gcc")
    ninjafile:print(" depfile = $out.d")
    ninjafile:print(" description = %scompiling.%s $in", ccache and "ccache " or "", config.mode())
    ninjafile:print("")
end

-- add rules for complier (clang)
function _add_rules_for_compiler_clang(ninjafile, sourcekind, program)
    return _add_rules_for_compiler_gcc(ninjafile, sourcekind, program)
end

-- add rules for complier (msvc/cl)
function _add_rules_for_compiler_msvc_cl(ninjafile, sourcekind, program)
    ninjafile:print("rule %s", sourcekind)
    ninjafile:print(" command = %s -showIncludes -c $ARGS $in -Fo$out", program)
    ninjafile:print(" deps = msvc")
    ninjafile:print(" description = compiling.%s $in", config.mode())
    ninjafile:print("")
end

-- add rules for complier (msvc/ml)
function _add_rules_for_compiler_msvc_ml(ninjafile, sourcekind, program)
    ninjafile:print("rule %s", sourcekind)
    ninjafile:print(" command = %s -c $ARGS -Fo$out $in", program)
    ninjafile:print(" deps = msvc")
    ninjafile:print(" description = compiling.%s $in", config.mode())
    ninjafile:print("")
end

-- add rules for resource complier (msvc/rc)
function _add_rules_for_compiler_msvc_rc(ninjafile, sourcekind, program)
    ninjafile:print("rule %s", sourcekind)
    ninjafile:print(" command = %s $ARGS -Fo$out $in", program)
    ninjafile:print(" deps = msvc")
    ninjafile:print(" description = compiling.%s $in", config.mode())
    ninjafile:print("")
end

-- add rules for complier
function _add_rules_for_compiler(ninjafile)
    ninjafile:print("# rules for compiler")
    if is_plat("windows") then
        ninjafile:print("msvc_deps_prefix = Note: including file:")
    end
    local add_compiler_rules =
    {
        gcc     = _add_rules_for_compiler_gcc,
        gxx     = _add_rules_for_compiler_gcc,
        clang   = _add_rules_for_compiler_clang,
        clangxx = _add_rules_for_compiler_clang,
        cl      = _add_rules_for_compiler_msvc_cl,
        ml      = _add_rules_for_compiler_msvc_ml,
        ml64    = _add_rules_for_compiler_msvc_ml,
        rc      = _add_rules_for_compiler_msvc_rc
    }
    for sourcekind, _ in pairs(language.sourcekinds()) do
        local program, toolname = platform.tool(sourcekind)
        if program and toolname then
            local add_rule = add_compiler_rules[toolname]
            if add_rule then
                add_rule(ninjafile, sourcekind, program)
            end
        end
    end
    ninjafile:print("")
end

-- add rules for linker (ar)
function _add_rules_for_linker_ar(ninjafile, linkerkind, program)
    ninjafile:print("rule %s", linkerkind)
    ninjafile:print(" command = %s $ARGS $out $in", program)
    ninjafile:print(" description = archiving.%s $out", config.mode())
    ninjafile:print("")
end

-- add rules for linker (gcc)
function _add_rules_for_linker_gcc(ninjafile, linkerkind, program)
    ninjafile:print("rule %s", linkerkind)
    ninjafile:print(" command = %s -o $out $in $ARGS", program)
    ninjafile:print(" description = linking.%s $out", config.mode())
    ninjafile:print("")
end

-- add rules for linker (clang)
function _add_rules_for_linker_clang(ninjafile, linkerkind, program)
    return _add_rules_for_linker_gcc(ninjafile, linkerkind, program)
end

-- add rules for linker (msvc)
function _add_rules_for_linker_msvc(ninjafile, linkerkind, program)
    ninjafile:print("rule %s", linkerkind)
    ninjafile:print(" command = %s $ARGS -out:$out $in", program)
    ninjafile:print(" description = linking.%s $out", config.mode())
    ninjafile:print("")
end

-- add rules for linker
function _add_rules_for_linker(ninjafile)
    ninjafile:print("# rules for linker")
    local linkerkinds = {}
    for _, _linkerkinds in pairs(language.targetkinds()) do
        table.join2(linkerkinds, _linkerkinds)
    end
    local add_linker_rules =
    {
        ar      = _add_rules_for_linker_ar,
        gcc     = _add_rules_for_linker_gcc,
        gxx     = _add_rules_for_linker_gcc,
        clang   = _add_rules_for_linker_clang,
        clangxx = _add_rules_for_linker_clang,
        link    = _add_rules_for_linker_msvc
    }
    for _, linkerkind in ipairs(table.unique(linkerkinds)) do
        local program, toolname = platform.tool(linkerkind)
        if program and toolname then
            local add_rule = add_linker_rules[toolname]
            if add_rule then
                add_rule(ninjafile, linkerkind, program)
            end
        end
    end
    ninjafile:print("")
end

-- add rules
function _add_rules(ninjafile)

    -- add rules for generator
    _add_rules_for_generator(ninjafile)

    -- add rules for complier
    _add_rules_for_compiler(ninjafile)

    -- add rules for linker
    _add_rules_for_linker(ninjafile)
end

-- add build rule for phony
function _add_build_for_phony(ninjafile, target)
    ninjafile:print("build %s: phony", target:name())
end

-- add build rule for object
function _add_build_for_object(ninjafile, target, sourcekind, sourcefile, objectfile)
    ninjafile:print("build %s: %s %s", objectfile, sourcekind, sourcefile)
    ninjafile:print(" ARGS = %s", os.args(compiler.compflags(sourcefile, {target = target})))
    ninjafile:print("")
end

-- add build rule for objects
function _add_build_for_objects(ninjafile, target, sourcebatch)
    for index, objectfile in ipairs(sourcebatch.objectfiles) do
        _add_build_for_object(ninjafile, target,  sourcebatch.sourcekind, sourcebatch.sourcefiles[index], objectfile)
    end
end

-- add build rule for target
function _add_build_for_target(ninjafile, target)

    -- is phony target?
    if target:isphony() then
        return _add_build_for_phony(ninjafile, target)
    end

    -- build target
    ninjafile:print("# build target: %s", target:name())
    local targetfile = target:targetfile()
    ninjafile:print("build %s: phony %s", target:name(), targetfile)

    -- build target file
    ninjafile:printf("build %s: %s", targetfile, target:linker():kind())
    local objectfiles = target:objectfiles()
    for _, objectfile in ipairs(objectfiles) do
        ninjafile:write(" " .. objectfile)
    end
    -- merge objects with rule("utils.merge.object")
    for _, sourcebatch in pairs(target:sourcebatches()) do
        if sourcebatch.rulename == "utils.merge.object" then
            ninjafile:write(" " .. table.concat(sourcebatch.sourcefiles, " "))
        end
    end
    local deps = target:get("deps")
    if deps then
        ninjafile:print(" || $")
        ninjafile:write("  ")
        for _, dep in ipairs(deps) do
            ninjafile:write(" " .. project.target(dep):targetfile())
        end
    end
    ninjafile:print("")
    ninjafile:print(" ARGS = %s", os.args(target:linkflags()))
    ninjafile:print("")

    -- build target objects
    for _, sourcebatch in pairs(target:sourcebatches()) do
        if sourcebatch.sourcekind then
            _add_build_for_objects(ninjafile, target, sourcebatch)
        end
    end
end

-- add build rule for generator
function _add_build_for_generator(ninjafile)
    ninjafile:print("# build build.ninja")
    ninjafile:print("build build.ninja: gen $")
    local allfiles = project.allfiles()
    for idx, projectfile in ipairs(allfiles) do
        if not path.is_absolute(projectfile) or projectfile:startswith(os.projectdir()) then
            ninjafile:print("  %s %s", os.args(path.relative(path.absolute(projectfile))), idx < #allfiles and "$" or "")
        end
    end
    ninjafile:print("")
end

-- add build rule for targets
function _add_build_for_targets(ninjafile)

    -- begin
    ninjafile:print("# build targets\n")

    -- add build rule for generator
    _add_build_for_generator(ninjafile)

    -- TODO
    -- disable precompiled header first
    for _, target in pairs(project.targets()) do
        target:set("pcheader", nil)
        target:set("pcxxheader", nil)
    end

    -- build targets
    for _, target in pairs(project.targets()) do
        _add_build_for_target(ninjafile, target)
    end

    -- build default
    local default = ""
    for targetname, target in pairs(project.targets()) do
        local isdefault = target:get("default")
        if isdefault == nil or isdefault == true then
            default = default .. " " .. targetname
        end
    end
    ninjafile:print("build default: phony%s", default)

    -- build all
    local all = ""
    for targetname, _ in pairs(project.targets()) do
        all = all .. " " .. targetname
    end
    ninjafile:print("build all: phony%s\n", all)

    -- end
    ninjafile:print("default default\n")
end

-- make
function make(outputdir)

    -- enter project directory
    local oldir = os.cd(os.projectdir())

    -- open the build.ninja file
    local ninjafile = io.open(path.join(outputdir, "build.ninja"), "w")

    -- add header
    _add_header(ninjafile)

    -- add rules
    _add_rules(ninjafile)

    -- add build rules for targets
    _add_build_for_targets(ninjafile)

    -- close the ninjafile
    ninjafile:close()

    -- leave project directory
    os.cd(oldir)
end
