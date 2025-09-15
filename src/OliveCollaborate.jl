"""
Created in September, 2025 by 
[chifi - an open source software dynasty.](https://github.com/orgs/ChifiSource)
- This software is MIT-licensed.
### OliveCollaborate

##### bindings
```julia

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

abstract type AbstractCollaborator end

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

make_collab_str(co::Collaborator) = "$(co.name)|$(co.connected)|$(co.perm)|$(co.color)"

function get_collaborator_data(cell::Cell{<:Any}, name::AbstractString)
    splitinfo = split(cell.outputs, ";")
    just_me = findfirst(s -> split(s, "|")[1] == name, splitinfo)
    if isnothing(just_me)
        @warn name
        @warn splitinfo
        throw("could not get name: $name")
    end
    Collaborator(split(splitinfo[just_me], "|"))::Collaborator
end

function set_collaborator_data!(cell::Cell{<:Any}, name::AbstractString, col::Collaborator)
    splitinfo = split(cell.outputs, ";")
    just_me = findfirst(s -> split(s, "|")[1] == name, splitinfo)
    splitinfo[just_me] = make_collab_str(col)
    cell.outputs = join(splitinfo, ";")
    nothing::Nothing
end

mutate_collab_data!(f::Function, cell::Cell{<:Any}, name::String) = begin
    splitinfo = split(cell.outputs, ";")
    just_me = findfirst(s -> split(s, "|")[1] == name, splitinfo)
    col = Collaborator(split(splitinfo[just_me], "|"))
    f(col)
    splitinfo[just_me] = make_collab_str(col)
    cell.outputs = join(splitinfo, ";")
end

function get_collaborator_data(c::Connection, proj::Project{:rpc}, name::String = getname(c))
    projs = c[:OliveCore].users[proj[:host]].environment.projects
    pf = findfirst(p -> typeof(p) == Project{:collab}, projs)
    rpcinfo_proj = projs[pf]
    get_collaborator_data(rpcinfo_proj[:cells][1], name)::Collaborator
end

function set_collaborator_data!(c::Connection, proj::Project{:rpc}, collab::Collaborator, name::String = getname(c))
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
                newcell = Cell{:collabedit}(name)
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
        for p in filter(d -> ~(d.id == proj.id), projs)
            np = Project{:rpc}(p.name)
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