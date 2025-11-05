"""
Created in September, 2025 by 
[chifi - an open source software dynasty.](https://github.com/orgs/ChifiSource)
- This software is MIT-licensed.
### OliveCollaborate
`OliveCollaborate` provides the `Olive` editor with *extensive* multi-user collaboration features. This 
extension allows users to connect to invite other clients to the same `Olive` session, and allows limited 
specific permissions for each one to be applied. Click the new share icon in the top right, then press the 
    power button, invite button, invite a friend, then send them the provided link. The `GLOBAL_TICKRATE` 
    variable in `OliveCollaborate`, `OliveCollaborate.GLOBAL_TICKRATE`, may be used to adjust the request 
    rate of the RPC sessions.

This extension can also be adjusted to fit other form-factors and applications by replacing this button and 
creating your own RPC project. To remove the original icon, simply set the value `collabicon` to `false` in 
your `CORE` data -- this can be done through the REPL, before saving settings, or it could more easily be done by 
editing the `Project.toml` in your `olive` directly. Note that there is no way to remove the icon in `headless` mode. 
Here is the original icon, which might be a good template to start from for adding your own:
```julia

function build(c::Connection, om::ComponentModifier, oe::OliveExtension{:invite})
    if haskey(c[:OliveCore].data,  "collabicon")
        if ~(c[:OliveCore].data["collabicon"])
            return
        end
    end
    ico = Olive.topbar_icon("sessionbttn", "send")
    on(c, ico, "click") do cm::ComponentModifier
        env = c[:OliveCore].users[getname(c)].environment
        found = findfirst(p -> typeof(p) == Project{:collab}, env.projects)
        if ~(isnothing(found))
            Olive.olive_notify!(cm, "collaborator project already open.")
            return
        end
        cells = Vector{Cell}([
        Cell("collab", " ","\$(getname(c))|no|all|#e75480")])
        # change the `:addtype` and the `:edittype` to change how users add and edit collaborators
        projdict = Dict{Symbol, Any}(:cells => cells, :env => "",
        :ishost => true, :addtype => :collablink, :open => "" => "", 
        :edittype => :collabedit)
        inclproj = Project{:collab}("collaborators", projdict)
        push!(env.projects, inclproj)
        tab = build_tab(c, inclproj)
        Olive.open_project(c, cm, inclproj, tab)
    end
    append!(om, "rightmenu", ico)
end
```
##### bindings
```julia
# Olive Collaborate:
Collaborator
AbstractCollaborator
GLOBAL_TICKRATE
make_collab_str(co::Collaborator)
get_collaborator_data(cell::Cell{<:Any}, name::AbstractString)
set_collaborator_data!(cell::Cell{<:Any}, name::AbstractString, col::Collaborator)
mutate_collab_data!(f::Function, cell::Cell{<:Any}, name::String)
get_collaborator_data(c::Connection, proj::Project{<:Any}, name::String = getname(c))
set_collaborator_data!(c::Connection, proj::Project{<:Any}, collab::Collaborator, name::String = getname(c))
build_collab_preview(c::Connection, cm::ComponentModifier, source::String, proj::Project{<:Any}, fweight ...; 
    ignorefirst::Bool = false)
build_collab_edit(c::Connection, cm::ComponentModifier, cell::Cell{:collab}, proj::Project{<:Any}, fweight ...)
make_collab_str(name::String, perm::Any, color::String)
set_rpc_cellfocus!(c::AbstractConnection, proj::Project{<:Any}, cell::Cell{<:Any}, comp::Component{<:Any})
build_base_rpc_tab(c::Connection, p::Project{<:Any}, ro::Bool = false; hidden::Bool = false)
do_inner_rpc_highlight(f::Function, c::AbstractConnection, proj::Project{<:Any}, cell::Cell{<:Any}, 
        cm::ComponentModifier, tm::Olive.Highlighter)
build_rpc_filecell(c::AbstractConnection, cell::Cell{<:Any}, dir::Directory{<:Any})

# Olive extensions:
build(c::Connection, om::ComponentModifier, oe::OliveExtension{:invite})
is_jlcell(type::Type{Cell{:collab}})
build(c::Connection, cm::ComponentModifier, cell::Cell{:collab}, proj::Project{<:Any})
is_jlcell(type::Type{Cell{:collabedit}})
is_jlcell(type::Type{Cell{:collablink}})
build(c::Connection, cm::ComponentModifier, cell::Cell{:collabedit}, proj::Project{<:Any})
build(c::Connection, cm::ComponentModifier, cell::Cell{:collablink}, proj::Project{<:Any})
build_tab(c::Connection, p::Project{:collab}; hidden::Bool = false)
build(c::AbstractConnection, cm::ComponentModifier, p::Project{:rpc})
build_tab(c::Connection, p::Project{:rpc}; hidden::Bool = false)
build_tab(c::Connection, p::Project{:rpcro}; hidden::Bool = false)
tab_controls(c::Connection, p::Project{:rpc})
style_tab_closed!(cm::ComponentModifier, proj::Project{:rpc})
cell_bind!(c::Connection, cell::Cell{<:Any}, proj::Project{:rpc})
build(c::Connection, cm::ComponentModifier, cell::Cell{:creator},
    proj::Project{:rpc})
build(c::Connection, cm::ComponentModifier, cell::Cell{:callcreator},
    proj::Project{:rpc})
is_jlcell(type::Type{Cell{:callcreator}})
cell_bind!(c::Connection, cell::Cell{:getstarted}, proj::Project{:rpc})
cell_highlight!(c::Connection, cm::ComponentModifier, cell::Cell{:code}, proj::Project{:rpc})
cell_highlight!(c::Connection, cm::ComponentModifier, cell::Cell{:markdown}, proj::Project{:rpc})
cell_highlight!(c::Connection, cm::ComponentModifier, cell::Cell{:tomlvalues}, proj::Project{:rpc})
cell_highlight!(c::Connection, cm::ComponentModifier, cell::Cell{:tomlvalues}, proj::Project{:rpcro})
cell_highlight!(c::Connection, cm::ComponentModifier, cell::Cell{:code}, proj::Project{:rpcro})
cell_highlight!(c::Connection, cm::ComponentModifier, cell::Cell{:markdown}, proj::Project{:rpcro})
cell_bind!(c::Connection, cell::Cell{<:Any}, proj::Project{:rpcro})
build(c::AbstractConnection, dir::Directory{:rpc})
build(c::Connection, cell::Cell{:rpcselector}, d::Directory{<:Any}, bind::Bool = true)
```
"""
module OliveCollaborate
using Olive
using Olive.Toolips
using Olive.Toolips.Components
using Olive.OliveHighlighters
using Olive.ToolipsSession
using Olive: OliveExtension, Project, Cell, Environment, getname, Directory
import Olive: build, cell_bind!, cell_highlight!, build_base_input, build_tab, is_jlcell, evaluate
import Olive: style_tab_closed!, tab_controls

GLOBAL_TICKRATE::Int64 = 100

"""
```julia
abstract AbstractCollaborator <: Any
```
A `Collaborator` is a simple structure that holds collaborator details, such as their permissions, name, 
whether or not they are connected, and their color. This makes them easier and less confusing to work with.
```julia
# consistencies
    name::Any
    connected::Any
    perm::Any
    color::Any
```
- See also: `Collaborator`, `get_collaborator_data`
"""
abstract type AbstractCollaborator end

"""
```julia
mutable struct Collaborator{T <: Any} <: AbstractCollaborator
```
- `name`**::T**
- `connected`**::T**
- `perm`**::T**
- `color`**::T**

The `Collaborator` is used by `OliveCollaborate` to process intermittent user data, which is retreived from 
the `:collab` project and is stored as a `String`. This is typically returned by `get_collaborator_data`.
```julia
Collaborator(args::Vector{<:AbstractString})
```
- See also: `get_collaborator_data`, `set_collaborator_data!`, `mutate_collab_data!`, `AbstractCollaborator`
"""
mutable struct Collaborator{T} <: AbstractCollaborator
    name::T
    connected::T
    perm::T
    color::T
    Collaborator(args::Vector{<:AbstractString}) = begin
        T::Type{<:AbstractString} = typeof(args[1])
        new{T}(args ...)::Collaborator{T}
    end
end

"""
```julia
make_collab_str(args ...) -> ::String
```
Makes a collaborator string from collaborator details provided as either a `String` or a full 
constructed `Collaborator`.
```julia
make_collab_str(co::Collaborator)
make_collab_str(name::String, perm::Any, color::String)
```
- See also: `get_collaborator_data`, `set_collaborator_data!`, `Collaborator`
"""
make_collab_str(co::Collaborator) = "$(co.name)|$(co.connected)|$(co.perm)|$(co.color)"

"""
```julia
get_collaborator_data(args ...) -> ::Collaborator
```
Gets the collaborator's data, as a `Collaborator`, from the cell's outputs -- this cell will be the first 
cell in the `:collab` project. We can get the `Collaborator` data directly from that cell, or by by providing 
the `Connection`, `Project`,  and `name` -- which will get the data for a specific person automatically. 
The second `Method` below **calls the first** and acts as a more convenient access for the first.
```julia
get_collaborator_data(cell::Cell{<:Any}, name::AbstractString)
get_collaborator_data(c::Connection, proj::Project{<:Any}, name::String = getname(c))
```
- See also: `set_collaborator_data!`, `Collaborator`, `mutate_collab_data!`
"""
function get_collaborator_data(cell::Cell{<:Any}, name::AbstractString)
    splitinfo = split(cell.outputs, ";")
    just_me = findfirst(s -> split(s, "|")[1] == name, splitinfo)
    if isnothing(just_me)
        throw("could not get name: $name")
    end
    Collaborator(split(splitinfo[just_me], "|"))::Collaborator
end

"""
```julia
set_collaborator_data!(args ...) -> ::
```
Sets the `Collaborator` data using a `Collaborator` struct. Can be done from the project or directly from the `:collab` project's 
first cell. The second dispatch, like the case of `get_collaborator_data`, calls the first dispatch.
```julia
set_collaborator_data!(cell::Cell{<:Any}, name::AbstractString, col::Collaborator)
set_collaborator_data!(c::Connection, proj::Project{<:Any}, collab::Collaborator, name::String = getname(c))
```
- See also: `get_collaborator_data`, `Collaborator`
"""
function set_collaborator_data!(cell::Cell{<:Any}, name::AbstractString, col::Collaborator)
    splitinfo = split(cell.outputs, ";")
    just_me = findfirst(s -> split(s, "|")[1] == name, splitinfo)
    splitinfo[just_me] = make_collab_str(col)
    cell.outputs = join(splitinfo, ";")
    nothing::Nothing
end


"""
```julia
mutate_collab_data!(args ...) -> ::Nothing
```
A shorthand for get/set collaborator data which will get and set automatically. This would be equivalent to 
    pulling the collaborator with `get_collaborator_data` and then updating it with `set_collaborator_data!`, 
    only this function performs that operation more efficiently.
```julia
set_collaborator_data!(cell::Cell{<:Any}, name::AbstractString, col::Collaborator)
set_collaborator_data!(c::Connection, proj::Project{<:Any}, collab::Collaborator, name::String = getname(c))
```
- See also: `get_collaborator_data`, `Collaborator`, `set_collaborator_data!`
"""
mutate_collab_data!(f::Function, cell::Cell{<:Any}, name::String) = begin
    splitinfo = split(cell.outputs, ";")
    just_me = findfirst(s -> split(s, "|")[1] == name, splitinfo)
    col = Collaborator(split(splitinfo[just_me], "|"))
    f(col)
    splitinfo[just_me] = make_collab_str(col)
    cell.outputs = join(splitinfo, ";")
    nothing::Nothing
end

function get_collaborator_data(c::Connection, proj::Project{<:Any}, name::String = getname(c))
    projs = c[:OliveCore].users[proj[:host]].environment.projects
    pf = findfirst(p -> typeof(p) == Project{:collab}, projs)
    rpcinfo_proj = projs[pf]
    get_collaborator_data(rpcinfo_proj[:cells][1], name)::Collaborator
end

function set_collaborator_data!(c::Connection, proj::Project{<:Any}, collab::Collaborator, name::String = getname(c))
    projs = c[:OliveCore].users[proj[:host]].environment.projects
    pf = findfirst(p -> typeof(p) == Project{:collab}, projs)
    rpcinfo_proj = projs[pf]
    cell = rpcinfo_proj[:cells][1]
    set_collaborator_data!(cell, name, col)::Nothing
end

function build(c::Connection, om::ComponentModifier, oe::OliveExtension{:invite})
    if haskey(c[:OliveCore].data,  "collabicon")
        if ~(c[:OliveCore].data["collabicon"])
            return
        end
    end
    ico = Olive.topbar_icon("sessionbttn", "send")
    on(c, ico, "click") do cm::ComponentModifier
        env = c[:OliveCore].users[getname(c)].environment
        found = findfirst(p -> typeof(p) == Project{:collab}, env.projects)
        if ~(isnothing(found))
            Olive.olive_notify!(cm, "collaborator project already open.")
            return
        end
        cells = Vector{Cell}([
        Cell("collab", " ","$(getname(c))|no|all|#e75480")])
        projdict = Dict{Symbol, Any}(:cells => cells, :env => "",
        :ishost => true, :addtype => :collablink, :open => "" => "", 
        :edittype => :collabedit)
        inclproj = Project{:collab}("collaborators", projdict)
        push!(env.projects, inclproj)
        tab = build_tab(c, inclproj)
        Olive.open_project(c, cm, inclproj, tab)
    end
    append!(om, "rightmenu", ico)
end
#==
rpcinfo
==#
"""
```julia
build_collab_preview(c::Connection, cm::ComponentModifier, source::String, proj::Project{<:Any}, fweight ...; 
    ignorefirst::Bool = false) -> ::Vector{Component{:div}}
```
Builds collaborator box to present current collaborators in a `:collab` `Project`. This is used to build 
the interior of the `:collab` cell within that project.
- See also: `Collaborator`, `build_collab_edit`
"""
function build_collab_preview(c::Connection, cm::ComponentModifier, source::String, proj::Project{<:Any}, fweight ...; 
    ignorefirst::Bool = false)
    first_person::Bool = true
    [begin
        name_color_perm = split(person, "|")
        name = string(name_color_perm[1])
        connect = string(name_color_perm[2])
        perm = string(name_color_perm[3])
        color = string(name_color_perm[4])
        personbox = div("$(name)collab")
        nametag = a("$(name)tag", text = name)
        style!(nametag, "background-color" => color, "color" => "white", "border-radius" => 0px, "width" => 30percent,
            fweight ...)
        personkey = c[:OliveCore].users[name].key
        style!(personbox, "display" => "flex", "padding" => 0px, "border-radius" => 0px, 
            "min-width" => 100percent, "flex-direction" => "row", "overflow" => "hidden")
        permtag = a("$(name)permtag", text = perm)
        connected = a("$(name)connected")
        if contains("y", connect)
            style!(connected, "background-color" => "darkgreen", "color" => "white", "width" => 40percent, fweight ...)
            connected[:text] = "connected"
        else
            style!(connected, "background-color" => "darkred", "color" => "white", "width" => 40percent, fweight ...)
            connected[:text] = "not connected"
        end
        if perm == "all"
            style!(permtag, "background-color" => "#301934", "color" => "white", fweight ...)
        elseif perm == "readonly"
            style!(permtag, "background-color" => "darkgray", "color" => "white", fweight ...)
        end
        style!(permtag, "width" => 20percent)
        if first_person && ~(ignorefirst)
            style!(nametag, "border-top-left-radius" => 5px)
            first_person = false
        end
        set_children!(personbox, [nametag, permtag, connected])
        if proj.data[:ishost]
            connected[:href] = href = "'https://$(get_host(c))/key?q=$personkey'"
            editbox = Olive.topbar_icon("$(name)edit", "edit")
            on(c, editbox, "click") do cm::ComponentModifier
                if length(proj[:cells]) > 1
                    Olive.olive_notify!(cm, "Close the currently open collaborator cell to open a new one.")
                    return
                end
                newcell = Cell{proj[:edittype]}(name)
                push!(proj[:cells], newcell)
                append!(cm, proj.id, build(c, cm, newcell, proj))
            end
            linkbox = Olive.topbar_icon("$(name)link", "link")
            on(linkbox, "click") do cm2::ClientModifier
                push!(cm2.changes, "navigator.clipboard.writeText('https://$(get_host(c))/key?q=$personkey');")
                Olive.olive_notify!(cm2, "link for $name copied to clipboard", color = color)
            end
            editbox[:align], linkbox[:align] = "center", "center"
            style!(editbox, "background-color" => "darkorange", "color" => "white", "color" => "white", "width" => 5percent, 
            fweight ...)
            style!(linkbox, "background-color" => "#18191A", "color" => "white", "color" => "white", "width" => 5percent, 
            fweight ...)
            push!(personbox, editbox, linkbox)
        end
        personbox::Component{:div}
    end for person in split(source, ";")]
end

"""
```julia
build_collab_edit(c::Connection, cm::ComponentModifier, cell::Cell{:collab}, proj::Project{<:Any}, fweight ...) -> ::Component{:div}
```
Similar to `build_collab_preview`, only this function builds the bottom of trhe `:collab` cell, where new users are 
added and the session can be turned on.
- See also: `Collaborator`, `build_collab_preview`
"""
function build_collab_edit(c::Connection, cm::ComponentModifier, cell::Cell{:collab}, proj::Project{<:Any}, fweight ...)
    add_person = div("addcollab", align = "right")
    style!(add_person, "padding" => 0px, "border-radius" => 0px, "display" => "flex", "min-width" => 100percent, 
    "border-bottom-left-radius" => 5px, "border-bottom-right-radius" => 5px, "flex-direction" => "row", "overflow" => "hidden")
    addbox = Olive.topbar_icon("collabadder", "add_box")
    addbox[:align] = "center"
    ol_user::String = getname(c)
    on(c, addbox, "click") do cm2::ComponentModifier
        if ~(proj[:active])
            Olive.olive_notify!(cm2, "collaborative session must be active first")
            return
        elseif ~(proj[:ishost])
            return
        elseif length(proj[:cells]) > 1
            return
        end
        newcell = Cell{proj[:addtype]}("")
        push!(proj[:cells], newcell)
        append!(cm2, proj.id, build(c, cm2, newcell, proj))
    end
    style!(addbox, "background-color" => "darkorange", "color" => "white", "width" => 50percent, fweight ...)
    poweron = Olive.topbar_icon("cell$(cell.id)", "power_settings_new")
    poweron[:align] = "center"
    on(c, poweron, "click") do cm2::ComponentModifier
        if ~(proj[:ishost])
            return
        end
        if proj[:active]
            # === CLOSE THE COLLABORATIVE SESSION ===
            name = getname(c)
            proj.data[:active] = false
            users = c[:OliveCore].users
            for client in split(cell.outputs, ";")
                client_name = split(client, "|")[1]
                if client_name == name
                    continue
                end
                found = findfirst(user -> user.name == client_name, users)
                deleteat!(users, found)
            end
            redirect!(cm2, "/")
            call!(c, cm2)
            cell.outputs = make_collab_str(Collaborator([getname(c), "y", "all", "#1e1e1e"]))
            events = c[:Session].events[ToolipsSession.get_session_key(c)]
            found = findfirst(event -> typeof(event) <: ToolipsSession.RPCEvent, events)
            Olive.olive_notify!(cm2, "collaborative session closed")
            # reset styles and UI elements
            redirect!(cm2, "/")
            return
        end
        env = c[:OliveCore].users[getname(c)].environment
        hostprojs = Vector{Olive.Project{<:Any}}([begin
            np = Project{:rpc}(p.name)
            np.data = p.data
            np.data[:host] = ol_user
            np.id = p.id
            np::Project{:rpc}
        end for p in filter(d -> ~(d.id == proj.id), env.projects)])
        for project in env.projects
            if project.id == proj.id
                continue
            end
            Olive.close_project(c, cm2, project)
        end
        env.projects = hostprojs
        for pro in hostprojs
            append!(cm2, "pane_one_tabs", build_tab(c, pro))
        end
        push!(hostprojs, proj)
        proj.data[:host] = ToolipsSession.get_session_key(c)
        co = Collaborator([getname(c), "y", "all", "#1e1e1e"])
        cell.outputs = make_collab_str(co)
        # add rpc directory
        rpcdir = Directory(env.pwd, dirtype = "rpc")
        insert!(env.directories, 1, rpcdir)
        insert!(cm2, "projectexplorer", 1, build(c, rpcdir))
        proj.data[:active] = true
        open_rpc!(c, cm2, tickrate = GLOBAL_TICKRATE)
        Olive.olive_notify!(cm2, "collaborative session now active")
        Components.trigger!(cm2, "tab$(proj.id)")
        style!(cm2, "collabon", "color" => "lightgreen")
    end
    if proj[:active]
        powerbg = "lightgreen"
    else
       powerbg = "white"
    end
    style!(poweron, "background-color" => "#242526", "color" => powerbg, "width" => 50percent, fweight ...)
    add_person[:children] = [poweron, addbox]
    add_person
end

function make_collab_str(name::String, perm::Any, color::String)
    "$name|no|$perm|$color"
end

is_jlcell(type::Type{Cell{:collab}}) = false

function build(c::Connection, cm::ComponentModifier, cell::Cell{:collab}, proj::Project{<:Any})
    # on initial creation, propagates this value.
    if ~(:active in keys(proj.data))
        proj.data[:active] = false
    end
    outercell::Component{:div} = div("cellcontainer$(cell.id)", align = "center")
    # move onto building the cell
    # collaborators box
    collab_status = div("colabstatus")
    style!(collab_status, "display" => "flex", "flex-direction" => "column", 
    "padding" => 0px, "border-radius" => 0px, "align-content" => "center", "width" => 50percent, 
    "height" => 40percent)
    fweight = ("font-weight" => "bold", "font-size" => 14pt, "padding" => 5px)
    people = build_collab_preview(c, cm, cell.outputs, proj, fweight ...)
    collab_status[:children] = people
    if proj.data[:ishost]
        add_person = build_collab_edit(c, cm, cell, proj, fweight ...)
        push!(collab_status, add_person)
    else
        lastch = people[length(people)]
        style!(lastch, "border-bottom-left-radius" => 5px, "border-bottom-right-radius" => 5px)
    end
    push!(outercell, collab_status)
    outercell::Component{:div}
end

is_jlcell(type::Type{Cell{:collablink}}) = false

is_jlcell(type::Type{Cell{:collabedit}}) = false

function build(c::Connection, cm::ComponentModifier, cell::Cell{:collabedit}, proj::Project{<:Any})
    collab = if ~(typeof(cell.outputs) <: AbstractCollaborator)
        get_collaborator_data(proj[:cells][1], cell.source)
    else
        cell.outputs
    end
    perm_opts = Vector{Servable}([Components.option(opt, text = opt) for opt in ("all", "readonly")])
    perm_selector = Components.select("permcollab", perm_opts)
    perm_selector[:value] = collab.perm
    colorbox = Components.colorinput("colcont", value = string(collab.color))
    completer = button("adduser", text = "update")
    on(c, completer, "click") do cm::ComponentModifier
        collab.color = cm["colcont"]["value"]
        collab.perm = cm["permcollab"]["value"]
        # TODO update collaborator data, update boxes with new values
        set_collaborator_data!(c, proj, collab, cell.source)
        style!(cm, cell.source * "tag", "background-color" => collab.color)
        
        Olive.cell_delete!(c, cm, cell, proj[:cells])
    end
    style!(completer, "background-color" => "white", "border" => "2px solid #1e1e1e", "color" => "#1e1e1e", 
        "border-radius" => 2px)
    perm_container = a("permcont", align = "center", children = [perm_selector])
    style!(perm_container, "width" => 20percent,  "background-color" => "#242526")
    retiv = div("cellcontainer$(cell.id)", children = [perm_container, colorbox, completer])
    style!(retiv, "display" => "flex", "width" => 70percent, "height" => 3percent)
    retiv::Component{:div}
end

function build(c::Connection, cm::ComponentModifier, cell::Cell{:collablink}, proj::Project{<:Any})
    cellid = cell.id
    nametag = a("cell$cellid", text = "", contenteditable = true, align = "left")
    style!(nametag, "background-color" => "#18191A", "color" => "white", "border-radius" => 0px, 
        "line-clamp" =>"1", "overflow" => "hidden", "display" => "-webkit-box", "padding" => 2px, "min-width" => 50percent, 
        "min-height" => 2.5percent)
    perm_opts = Vector{Servable}([Components.option(opt, text = opt) for opt in ("all", "readonly")])
    perm_selector = Components.select("permcollab", perm_opts)
    perm_selector[:value] = "all"
    style!(perm_selector, "height" => 100percent, "width" => 100percent)
    perm_container = a("permcont", align = "center")
    style!(perm_container, "width" => 20percent,  "background-color" => "#242526")
    push!(perm_container, perm_selector)
    colorbox = Components.colorinput("colcont", value = "#efe1ed")
    style!(colorbox, "background-color" => "white", "border" => "none", "height" => 100percent, "margin" => 0percent)
    completer = button("adduser", text = "add")
    style!(completer, "background-color" => "white", "border" => "2px solid #1e1e1e", "color" => "#1e1e1e", 
        "border-radius" => 2px)
    on(c, completer, "click") do cm2::ComponentModifier
        name = cm2[nametag]["text"]
        if name == ""
            Olive.olive_notify!(cm2, "you must name a new collaborator", color = "red")
            return
        elseif ~(proj[:active])
            Olive.olive_notify!(cm2, "cannot add to inactive session !", color = "red")
            return
        end
        perm = cm2[perm_selector]["value"]
        colr = cm2[colorbox]["value"]
        pers = Collaborator([name, "n", perm, colr])
        pers = make_collab_str(pers)
        infocell = proj[:cells][1]
        infocell.outputs = infocell.outputs * ";$(pers)"
        host_user = c[:OliveCore].users[Olive.getname(c)]
        projs = host_user.environment.projects
        key = ToolipsSession.gen_ref(4)
        push!(c[:OliveCore].keys, key => name)
        env::Environment = Environment("olive")
        env.pwd = host_user.environment.pwd
        env.directories = host_user.environment.directories
        host_n = host_user.name
        project_T = :rpc
        if perm != "all"
            project_T = :rpcro
        end
        for p in filter(d -> ~(d.id == proj.id), projs)
            np = Project{project_T}(p.name)
            np.data = p.data
            np.data[:host] = host_n
            np.id = p.id
            push!(env.projects, np)
        end
        newcollab = Project{:collab}(proj.name)
        newcollab.data = copy(proj.data)
        newcollab.data[:ishost] = false
        new_data = Dict{String, Any}("group" => host_user.data["group"])
        push!(env.projects, newcollab)
        newuser = Olive.OliveUser{:olive}(name, "", env, new_data)
        Olive.init_user(newuser)
        newuser.key = key
        push!(c[:OliveCore].users, newuser)
        fweight = ("font-weight" => "bold", "font-size" => 13pt)
        box = build_collab_preview(c, cm2, pers, proj, ignorefirst = true, 
            fweight ...)
        insert!(cm2, "colabstatus", 2, box[1])
        Olive.cell_delete!(c, cm2, cell, proj[:cells])
        Olive.olive_notify!(cm2, "collaborator $name added to session", color = colr)
    end
    retiv = div("cellcontainer$cellid", children = [nametag, perm_container, colorbox, completer])
    style!(retiv, "display" => "flex", "width" => 70percent, "height" => 3percent)
    retiv
end

function build_tab(c::Connection, p::Project{:collab}; hidden::Bool = false)
    fname::String = p.id
    tabbody::Component{:div} = div("tab$(fname)", class = "tabopen")
    if(hidden)
        tabbody[:class]::String = "tabclosed"
    end
    rpc_scrf = cm::ComponentModifier -> begin
        if ~(:active in keys(p.data))
            return
        end
        is_active::Bool = p.data[:active]
        # check if rpc is open
        if is_active
            cell = p[:cells][1]
            if ~(p[:ishost])
                join_rpc!(c, cm, p.data[:host], tickrate = OliveCollaborate.GLOBAL_TICKRATE)
            else
                open_rpc!(c, cm, tickrate = OliveCollaborate.GLOBAL_TICKRATE)
            end
            usr_name::AbstractString = getname(c)
            collab = get_collaborator_data(cell, usr_name)
            collab.connected = "y"
            set_collaborator_data!(cell, usr_name, collab)
            call!(c, cm) do cm2::ComponentModifier
                Olive.olive_notify!(cm2, "$usr_name has joined !", color = string(collab.color))
            end
        end# is active
    end # spawn script (rpc_scrf, added to tabbody extras)
    rpc_eref = Toolips.gen_ref(6)
    ToolipsSession.register!(rpc_scrf, c, rpc_eref)
    rpc_scr = script(Toolips.gen_ref(5), text = "sendpage('$rpc_eref');")
    push!(tabbody[:extras], rpc_scr)
    tablabel::Component{:a} = a("tablabel$(fname)", text = p.name, class = "tablabel")
    push!(tabbody, tablabel)
    on(c, tabbody, "click") do cm::ComponentModifier
        if p.id in cm
            return
        end
        projects::Vector{Project{<:Any}} = CORE.users[getname(c)].environment.projects
        inpane = findall(proj::Project{<:Any} -> proj[:pane] == p[:pane], projects)
        [begin
            if projects[e].id != p.id 
                Olive.style_tab_closed!(cm, projects[e])
            end
            nothing
        end  for e in inpane]
        projbuild::Component{:div} = build(c, cm, p)
        set_children!(cm, "pane_$(p[:pane])", [projbuild])
        cm["tab$(fname)"] = :class => "tabopen"
    end
    on(c, tabbody, "dblclick") do cm::ComponentModifier
        if "$(fname)dec" in cm
            return
        end
        decollapse_button::Component{:span} = span("$(fname)dec", text = "arrow_left", class = "tablabel")
        on(c, decollapse_button, "click") do cm2::ComponentModifier
            remove!(cm2, "$(fname)close")
            remove!(cm2, "$(fname)add")
            remove!(cm2, "$(fname)restart")
            remove!(cm2, "$(fname)run")
            remove!(cm2, "$(fname)switch")
            remove!(cm2, "$(fname)dec")
        end
        style!(decollapse_button, "color" => "blue")
        controls::Vector{<:AbstractComponent} = tab_controls(c, p)
        insert!(controls, 1, decollapse_button)
        for serv in controls
            append!(cm, tabbody, serv) 
        end
    end
    tabbody::Component{:div}
end

#==
rpc projects
==#

include("RPCProjects.jl")
include("RPCDirectories.jl")
end # - module !