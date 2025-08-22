module OliveCollaborate
using Olive
using Olive.Toolips
using Olive.Toolips.Components
using Olive.OliveHighlighters
using Olive.ToolipsSession
using Olive: OliveExtension, Project, Cell, Environment, getname, Directory
import Olive: build, cell_bind!, cell_highlight!, build_base_input, build_tab

function build(c::Connection, om::ComponentModifier, oe::OliveExtension{:invite})
    ico = Olive.topbar_icon("sessionbttn", "send")
    on(c, ico, "click") do cm::ComponentModifier
        cells = Vector{Cell}([
        Cell("collab", " ","$(getname(c))|no|all|#e75480")])
        projdict = Dict{Symbol, Any}(:cells => cells, :env => "",
        :ishost => true, :addtype => :collablink)
        inclproj = Project{:collab}("collaborators", projdict)
        push!(c[:OliveCore].users[getname(c)].environment.projects, inclproj)
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
        connected = a("$(name)connected", href = "'https://$(get_host(c))/?key=$personkey'")
        if contains("yes", connect)
            style!(connected, "background-color" => "darkgreen", "color" => "white", "width" => 40percent, fweight ...)
            connected[:text] = "connected"
        else
            style!(connected, "background-color" => "darkred", "color" => "white", "width" => 40percent, fweight ...)
            connected[:text] = "not connected"
        end
        if perm == "all"
            style!(permtag, "background-color" => "#301934", "color" => "white", fweight ...)
        elseif perm == "askall"
            style!(permtag, "background-color" => "darkblue", "color" => "white", fweight ...)
        elseif perm == "view"
            style!(permtag, "background-color" => "darkgray", "color" => "white", fweight ...)
        elseif perm == "askswitch"
            style!(permtag, "background-color" => "darkred", "color" => "white", fweight ...)
        end
        style!(permtag, "width" => 20percent)
        if first_person && ~(ignorefirst)
            style!(nametag, "border-top-left-radius" => 5px)
            first_person = false
        end
        set_children!(personbox, [nametag, permtag, connected])
        if proj.data[:ishost]
            editbox = Olive.topbar_icon("$(name)edit", "app_registration")
            linkbox = Olive.topbar_icon("$(name)link", "link")
            on(c, linkbox, "click") do cm2::ComponentModifier
                push!(cm2.changes, "navigator.clipboard.writeText('https://$(get_host(c))/?key=$personkey');")
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
    style!(addbox, "background-color" => "darkorange", "color" => "white", "width" => 5percent, fweight ...)
    poweron = Olive.topbar_icon("collabon", "power_settings_new")
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
            Olive.close_project(c, cm2, project)
        end
        env.projects = hostprojs
        for pro in hostprojs
            Olive.open_project(c, cm2, pro, build_tab(c, pro))
        end
        push!(hostprojs, proj)
        proj.data[:host] = ToolipsSession.get_session_key(c)
        proj.data[:active] = true
        open_rpc!(c, cm2, tickrate = 120)
        Olive.olive_notify!(cm2, "collaborative session now active")
    end
    if proj[:active]
        powerbg = "lightgreen"
    else
       powerbg = "white"
    end
    style!(poweron, "background-color" => "#242526", "color" => powerbg, "width" => 5percent, fweight ...)
    add_person[:children] = [addbox, poweron]
    add_person
end

function make_collab_str(ishost::Bool, name::String, perm::Any, color::String)
    fill = "no"
    if ishost
        fill = "yes"
    end
    ";$name|$fill|$perm|$colr"
end

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

function build(c::Connection, cm::ComponentModifier, cell::Cell{:collablink}, proj::Project{<:Any})
    cellid = cell.id
    nametag = a("cell$cellid", text = "", contenteditable = true)
    style!(nametag, "background-color" => "#18191A", "color" => "white", "border-radius" => 0px, 
    "width" => 30percent, "line-clamp" =>"1", "overflow" => "hidden", "display" => "-webkit-box")
    perm_opts = Vector{Servable}([Components.option(opt, text = opt) for opt in ["all", "askall", "read only"]])
    perm_selector = Components.select("permcollab", perm_opts)
    perm_selector[:value] = "all"
    style!(perm_selector, "height" => 100percent, "width" => 100percent)
    perm_container = a("permcont", align = "center")
    style!(perm_container, "width" => 20percent,  "background-color" => "#242526")
    push!(perm_container, perm_selector)
    div("cellcontainer$cellid", children = [nametag, perm_container])
end

function build_tab(c::Connection, p::Project{:collab}; hidden::Bool = false)
    fname::String = p.id
    tabbody::Component{:div} = div("tab$(fname)", class = "tabopen")
    if(hidden)
        tabbody[:class]::String = "tabclosed"
    end
    rpc_scrf = cm::ComponentModifier -> begin
        if ~(:active in keys(p.data))
            @info "canceled rpc join, no active in keys"
            return
        end
        is_active::Bool = p.data[:active]
        # check if rpc is open
        if is_active
            # if peer
            cell = p[:cells][1]
            if ~(p[:ishost])
            @warn "joining rpc"
                join_rpc!(c, cm, p.data[:host])
                splits = split(cell.outputs, ";")
                ind = findfirst(n -> split(n, "|")[1] == getname(c), splits)
                data = splits[ind]
                color = split(data, "|")[4]
                call!(c, cm) do cm2::ComponentModifier
                    Olive.olive_notify!(cm2, "$(getname(c)) has joined !", color = string(color))
                end
            # if host
            else
                @warn "rejoining host rpc"
                open_rpc!(c, cm)
                splits = split(cell.outputs, ";")
                ind = findfirst(n -> split(n, "|")[1] == getname(c), splits)
                data = splits[ind]
                color = split(data, "|")[4]
                call!(c, cm) do cm2::ComponentModifier
                    Olive.olive_notify!(cm2, "$(getname(c)) has joined !", color = string(color))
                end
            end
        else
            @info "skipped rpc join, proj not active"
        end# is active
    end
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
        [begin append!(cm, tabbody, serv); nothing end for serv in controls]
    end
    tabbody::Component{:div}
end

#==
rpc projects
==#

#== TODO
slightly redesign this -- this function will become the `collaborators` project's 
`build` function. Along with the tab below it. (this way `join/open_rpc!` only 
    gets called once.) 
==#

#==function build_tab(c::Connection, p::Project{:rpc}; hidden::Bool = false)

end==#

function cell_bind!(c::Connection, cell::Cell{<:Any}, proj::Project{:rpc})
    keybindings = c[:OliveCore].users[Olive.getname(c)].data["keybindings"]
    km = ToolipsSession.KeyMap()
    cells = proj[:cells]
    ToolipsSession.bind(km, keybindings["save"], prevent_default = true) do cm::ComponentModifier
        Olive.save_project(c, cm, proj)
        rpc!(c, cm)
    end
    ToolipsSession.bind(km, keybindings["up"]) do cm2::ComponentModifier
        Olive.cell_up!(c, cm2, cell, proj)
        rpc!(c, cm2)
    end
    ToolipsSession.bind(km, keybindings["down"]) do cm2::ComponentModifier
        Olive.cell_down!(c, cm2, cell, proj)
        rpc!(c, cm2)
    end
    ToolipsSession.bind(km, keybindings["delete"]) do cm2::ComponentModifier
        Olive.cell_delete!(c, cm2, cell, cells)
        rpc!(c, cm2)
    end
    ToolipsSession.bind(km, keybindings["evaluate"]) do cm2::ComponentModifier
        Olive.evaluate(c, cm2, cell, proj)
        rpc!(c, cm2)
    end
    ToolipsSession.bind(km, keybindings["new"]) do cm2::ComponentModifier
        Olive.cell_new!(c, cm2, cell, proj)
        call!(c, cm2) do cm3::ComponentModifier
            Olive.olive_notify!(cm3, "a user created a cell")
        end
    end
    ToolipsSession.bind(km, keybindings["focusup"]) do cm::ComponentModifier
        Olive.focus_up!(c, cm, cell, cells, proj)
    end
    ToolipsSession.bind(km, keybindings["focusdown"]) do cm::ComponentModifier
        Olive.focus_down!(c, cm, cell, cells, proj)
    end
    km::ToolipsSession.KeyMap
end

function cell_bind!(c::Connection, cell::Cell{:getstarted}, proj::Project{:rpc})
    keybindings = c[:OliveCore].users[Olive.getname(c)].data["keybindings"]
    km = ToolipsSession.KeyMap()
    cells = proj[:cells]
    ToolipsSession.bind(km, keybindings["save"], prevent_default = true) do cm::ComponentModifier
        Olive.save_project(c, cm, proj)
        rpc!(c, cm)
    end
    ToolipsSession.bind(km, keybindings["up"]) do cm2::ComponentModifier
        Olive.cell_up!(c, cm2, cell, proj)
        rpc!(c, cm2)
    end
    ToolipsSession.bind(km, keybindings["down"]) do cm2::ComponentModifier
        Olive.cell_down!(c, cm2, cell, proj)
        rpc!(c, cm2)
    end
    ToolipsSession.bind(km, keybindings["delete"]) do cm2::ComponentModifier
        Olive.cell_delete!(c, cm2, cell, cells)
        rpc!(c, cm2)
    end
    ToolipsSession.bind(km, keybindings["evaluate"]) do cm2::ComponentModifier
        Olive.evaluate(c, cm2, cell, proj)
        rpc!(c, cm2)
    end
    ToolipsSession.bind(km, keybindings["new"]) do cm2::ComponentModifier
        Olive.cell_new!(c, cm2, cell, proj)
    end
    ToolipsSession.bind(km, keybindings["focusup"]) do cm::ComponentModifier
        Olive.focus_up!(c, cm, cell, cells, proj)
    end
    ToolipsSession.bind(km, keybindings["focusdown"]) do cm::ComponentModifier
        Olive.focus_down!(c, cm, cell, cells, proj)
    end
    km::ToolipsSession.KeyMap
end

function get_collaborator_data(c::Connection, proj::Project{:rpc})
    projs = c[:OliveCore].users[proj[:host]].environment.projects
    pf = findfirst(p -> typeof(p) == Project{:collab}, projs)
    rpcinfo_proj = projs[pf]
    allinfo = rpcinfo_proj[:cells][1].outputs
    splitinfo = split(allinfo, ";")
    just_me = findfirst(s -> contains(split(s, "|")[1], getname(c)), splitinfo)
    split(splitinfo[just_me], "|")::Vector{SubString{String}}
end

function cell_highlight!(c::Connection, cm::ComponentModifier, cell::Cell{:code}, proj::Project{:rpc})
    windowname::String = proj.id
    curr = cm["cell$(cell.id)"]["text"]
    cursorpos = parse(Int64, cm["cell$(cell.id)"]["caret"])
    cell.source = curr
    if length(cell.source) == 0
        return
    end
    tm = c[:OliveCore].users[getname(c)].data["highlighters"]["julia"]
    tm.raw = curr
    OliveHighlighters.mark_julia!(tm)
    set_text!(cm, "cellhighlight$(cell.id)", string(tm))
    if cursorpos == 0
        curspos = 1
    end
    n = length(curr)
    tm.raw = cell.source[1:cursorpos]
    OliveHighlighters.mark_julia!(tm)
    first_half = string(tm)
    OliveHighlighters.clear!(tm)
    tm.raw = cell.source[cursorpos + 1:end]
    OliveHighlighters.mark_julia!(tm)
    second_half = string(tm)
    OliveHighlighters.clear!(tm)
    collabdata = get_collaborator_data(c, proj)
    ToolipsSession.call!(c, cm) do cm2::ComponentModifier
        hltxt = first_half * "<a style='color:$(collabdata[4]);'>▆</a>" * second_half
        set_text!(cm2, "cellhighlight$(cell.id)", hltxt)
    end
end

end # - module !