function get_collaborator_data(c::Connection, proj::Project{:rpc})
    projs = c[:OliveCore].users[proj[:host]].environment.projects
    pf = findfirst(p -> typeof(p) == Project{:collab}, projs)
    rpcinfo_proj = projs[pf]
    allinfo = rpcinfo_proj[:cells][1].outputs
    splitinfo = split(allinfo, ";")
    just_me = findfirst(s -> contains(split(s, "|")[1], getname(c)), splitinfo)
    split(splitinfo[just_me], "|")::Vector{SubString{String}}
end

function get_collaborator_data(c::Connection, name::String, proj::Project{:rpc})
    projs = c[:OliveCore].users[proj[:host]].environment.projects
    pf = findfirst(p -> typeof(p) == Project{:collab}, projs)
    rpcinfo_proj = projs[pf]
    allinfo = rpcinfo_proj[:cells][1].outputs
    splitinfo = split(allinfo, ";")
    just_me = findfirst(s -> contains(split(s, "|")[1], name), splitinfo)
    split(splitinfo[just_me], "|")::Vector{SubString{String}}
end

function set_rpc_cellfocus!(c::AbstractConnection, proj::Project{<:Any}, cell::Cell{<:Any}, comp::Component{<:Any})
    cellid = cell.id
    childs = comp[:children]
    if "cellinterior$cellid" in childs
       interior = comp[:children, "cellinterior$cellid"]
       intchildren = interior[:children]
       if "cellinput$cellid" in intchildren
            comp = interior[:children, "cellinput$cellid"][:children, "cell$cellid"]
       end
    elseif "cell$cellid" in childs
        comp = comp[:children, "cell$cellid"]
    end
    on(c, comp, "focus") do cm::ComponentModifier
        color = get_collaborator_data(c, cell.outputs, proj)[4]
        style!(cm, "cellcontainer$cellid", "border" => "2px solid $color", 
            "border-radius" => 3px)
        cm["cell$cellid"] = "contenteditable" => "false"
        call!(c, cm)
    end
    on(c, comp, "focusout") do cm::ComponentModifier
        style!(cm, "cellcontainer$cellid", "border" => "0px")
        cm["cell$cellid"] = "contenteditable" => "true"
        call!(c, cm)
    end
    nothing::Nothing
end

function build(c::AbstractConnection, cm::ComponentModifier, p::Project{:rpc})
    frstcells::Vector{Cell} = p[:cells]
    retvs = Vector{Servable}([begin
       built = CORE.olmod.build(c, cm, cell, p)
       set_rpc_cellfocus!(c, p, cell, built)
       built::Component{<:Any}
    end for cell in frstcells])
    div(p.id, children = retvs, class = "projectwindow")::Component{:div}
end

function build_tab(c::Connection, p::Project{:rpc}; hidden::Bool = false)
    fname::String = p.id
    tabbody::Component{:div} = div("tab$(fname)", class = "tabopen")
    if(hidden)
        tabbody[:class]::String = "tabclosed"
    end
    tablabel::Component{:a} = a("tablabel$(fname)", text = p.name, class = "tablabel")
    push!(tabbody, tablabel)
    on(c, tabbody, "click") do cm::ComponentModifier
        if p.id in cm
            return
        end
        projects::Vector{Project{<:Any}} = CORE.users[Olive.getname(c)].environment.projects
        collab_proj = findfirst(p -> typeof(p) == Project{:collab}, projects)
        collab_proj = projects[collab_proj]
        if ~(collab_proj[:ishost])
            # is client; ensure the host has project open
            host_env = c[:OliveCore].users[p.data[:host]].environment
            projpos = findfirst(p -> typeof(p) == Project{:collab}, host_env.projects)
            hostcol = host_env.projects[projpos]
            selected_projects = hostcol[:open]
            if ~(p.id in selected_projects)
                return
            end
        else
            # trigger for client from host:
            if p[:pane] == "one"
                collab_proj.data[:open] = fname => collab_proj[:open][2]
            else
                collab_proj.data[:open] = collab_proj[:open][1] => fname
            end
            trigger!(cm, "tab$fname")
            style!(cm, "tab$fname", "border-bottom" => "2px solid green")
            call!(c, cm)
        end
        inpane = findall(proj::Project{<:Any} -> proj[:pane] == p[:pane], projects)
        for e in inpane
            if projects[e].id != p.id 
                style_tab_closed!(cm, projects[e])
            end
            nothing
        end
        projbuild::Component{:div} = build(c, cm, p)
        set_children!(cm, "pane_$(p[:pane])", [projbuild])
        cm["tab$(fname)"] = :class => "tabopen"
        if length(p.data[:cells]) > 0
            focus!(cm, "cell$(p[:cells][1].id)")
        end
    end
    on(c, tabbody, "dblclick") do cm::ComponentModifier
        if "$(fname)dec" in cm
            return
        end
        c_projects = c[:OliveCore].users[getname(c)].environment.projects
        collabproj = findfirst(proj -> typeof(proj) == Project{:collab}, c_projects)
        ishost = c_projects[collabproj][:ishost]
        if ~(ishost)
            return
        end
        decollapse_button::Component{:span} = span("$(fname)dec", text = "arrow_left", class = "tablabel")
        controls::Vector{<:AbstractComponent} = if ishost
            Olive.tab_controls(c, p)
        else
            on(c, decollapse_button, "click") do cm2::ComponentModifier
                remove!(cm2, "$(fname)close")
                remove!(cm2, "$(fname)switch")
                remove!(cm2, "$(fname)dec")
            end
            Olive.tab_controls(c, p)[end - 1:end]
        end
        style!(decollapse_button, "color" => "blue")
        insert!(controls, 1, decollapse_button)
        for serv in controls
            append!(cm, tabbody, serv)
        end
        nothing::Nothing
    end
    tabbody::Component{:div}
end

function style_tab_closed!(cm::ComponentModifier, proj::Project{:rpc})
    cm["tab$(proj.id)"] = "class" => "tabclosed"
    style!(cm, "tab$(proj.id)", "border-bottom" => 0px)
end

function cell_bind!(c::Connection, cell::Cell{<:Any}, proj::Project{:rpc})
    keybindings = c[:OliveCore].users[Olive.getname(c)].data["keybindings"]
    km = ToolipsSession.KeyMap()
    cells = proj[:cells]
    ToolipsSession.bind(km, keybindings["save"], prevent_default = true) do cm::ComponentModifier
        Olive.save_project(c, cm, proj)
        rpc!(c, cm)
    end
    ToolipsSession.bind(km, keybindings["up"]) do cm2::ComponentModifier
        Olive.cell_up!(c, cm2, cell, proj, false)
        rpc!(c, cm2)
        focus!(cm2, "cell$(cell.id)")
    end
    ToolipsSession.bind(km, keybindings["down"]) do cm2::ComponentModifier
        Olive.cell_down!(c, cm2, cell, proj, false)
        rpc!(c, cm2)
        focus!(cm2, "cell$(cell.id)")
    end
    ToolipsSession.bind(km, keybindings["delete"]) do cm2::ComponentModifier
        Olive.cell_delete!(c, cm2, cell, cells)
        rpc!(c, cm2)
    end
    ToolipsSession.bind(km, keybindings["new"]) do cm2::ComponentModifier
        pos = findfirst(lcell -> lcell.id == cell.id, cells)
        creator_cell = Cell{:creator}()
        if pos == length(cells)
            push!(cells, creator_cell)
        else
            insert!(cells, pos + 1, creator_cell)
        end
        callcell = Cell{:callcreator}(Olive.getname(c), id = creator_cell.id)
        insert!(cm2, proj.id, pos + 1, build(c, cm2, callcell, proj))
        call!(c, cm2)
        insert!(cm2, proj.id, pos + 1, build(c, cm2, creator_cell, proj))
        focus!(cm2, "cell$(creator_cell.id)")
    end
    ToolipsSession.bind(km, keybindings["evaluate"]) do cm2::ComponentModifier
        cellid::String = cell.id
        if "load$(cellid)" in cm2
            return
        end
        icon = Olive.olive_loadicon()
        icon.name = "load$cellid"
        icon["width"] = "16"
        proj.data[:mod].WD = CORE.users[getname(c)].environment.pwd
        append!(cm2, "cellside$(cellid)", icon)
        on(c, cm2, 100) do cm2::ComponentModifier
            Olive.evaluate(c, cm2, cell, proj)
            remove!(cm2, "load$cellid")
            rpc!(c, cm2)
        end
        rpc!(c, cm2)
    end

    ToolipsSession.bind(km, keybindings["focusup"]) do cm::ComponentModifier
        Olive.focus_up!(c, cm, cell, proj)
    end
    ToolipsSession.bind(km, keybindings["focusdown"]) do cm::ComponentModifier
        Olive.focus_down!(c, cm, cell, proj)
    end
    km::ToolipsSession.KeyMap
end

function build(c::Connection, cm::ComponentModifier, cell::Cell{:creator},
    proj::Project{:rpc})
    cells = proj[:cells]
    windowname::String = proj.id
    creatorkeys = CORE.users[getname(c)]["creatorkeys"]
    cbox = Components.textdiv("cell$(cell.id)", text = "")
    style!(cbox, "outline" => "transparent", "color" => "white")
    key = ToolipsSession.get_session_key(c)
    on(c, cbox, "input") do cm2::ComponentModifier
        txt = cm2[cbox]["text"]
        if txt in keys(creatorkeys)
            pos = findfirst(lcell -> lcell.id == cell.id, cells)
            cellt = creatorkeys[txt]
            new_cell = Cell(string(cellt), "")
            session = Olive.SES
            mock_ses = ToolipsSession.MockSession(session)
            host_id, host_event = ToolipsSession.find_host(c, true)
            for client in (host_id, host_event.clients ...)
                if client == key
                    continue
                end
                tempdata = Dict{Symbol, Any}(:Session => session, :OliveCore => c[:OliveCore], :SESSIONKEY => client)
                newcon = Connection(c.stream, tempdata, Vector{Toolips.Route}(), get_ip(c))
                client_cell = build(newcon, cm2, new_cell, proj)
                set_rpc_cellfocus!(newcon, proj, new_cell, client_cell)
                insert!(cm2, windowname, pos, client_cell)
                remove!(cm2, buttonbox)
                call!(c, cm2, client)
            end
            remove!(cm2, buttonbox)
            deleteat!(cells, pos)
            insert!(cells, pos, new_cell)
            client_cell = build(c, cm2, new_cell, proj)
            set_rpc_cellfocus!(c, proj, new_cell, client_cell)
            insert!(cm2, windowname, pos, client_cell)
            focus!(cm2, "cell$(new_cell.id)")
            # finished func!
         elseif txt != ""
             Olive.olive_notify!(cm2, "$txt is not a recognized cell hotkey", color = "red")
             set_text!(cm2, cbox, "")
        end
    end
    km = cell_bind!(c, cell, proj)
    ToolipsSession.bind(c, cm, cbox, km)
    olmod = CORE.olmod
     buttonbox = div("cellcontainer$(cell.id)")
     push!(buttonbox, cbox)
     push!(buttonbox, h3("spawn$(cell.id)", text = "new cell"))
     group_excluded_sigs = Olive.get_group(c).cells
     for m in methods(Olive.build, [Toolips.AbstractConnection, Toolips.Modifier, Olive.IPyCells.AbstractCell, Project{<:Any}])
        sig = m.sig.parameters[4]
         if sig == Cell{<:Any}
             continue
         end
         if ~(is_jlcell(sig))
            continue
         end
         signature::Symbol = sig.parameters[1]
         if sig in group_excluded_sigs
            continue
         end
         b = button("$(sig)butt", text = string(signature))
         on(c, b, "click") do cm2::ComponentModifier
             pos = findfirst(lcell -> lcell.id == cell.id, cells)
             remove!(cm2, buttonbox)
             new_cell = Cell(string(signature), "")
             deleteat!(cells, pos)
             insert!(cells, pos, new_cell)
             insert!(cm2, windowname, pos, build(c, cm2, new_cell,
              proj))
         end
         push!(buttonbox, b)
     end
     buttonbox
end

function build(c::Connection, cm::ComponentModifier, cell::Cell{:callcreator},
    proj::Project{:rpc})
    label = h3(text = cell.source * " is creating a cell")
    collabdata = get_collaborator_data(c, cell.outputs, proj)
    style!(label, "color" => collabdata[4])
    bod = div("cellcontainer$(cell.id)", children = [label])
    style!(bod, "border" => "3px solid $(collabdata[4])")
    bod::Component{:div}
end

function cell_bind!(c::Connection, cell::Cell{:getstarted}, proj::Project{:rpc})
    keybindings = c[:OliveCore].users[Olive.getname(c)].data["keybindings"]
    km = ToolipsSession.KeyMap()
    cells = proj[:cells]
    ToolipsSession.bind(km, keybindings["evaluate"]) do cm2::ComponentModifier
        Olive.evaluate(c, cm2, cell, proj)
        rpc!(c, cm2)
    end
    km::ToolipsSession.KeyMap
end

function cell_highlight!(c::Connection, cm::ComponentModifier, cell::Cell{:code}, proj::Project{:rpc})
    do_inner_rpc_highlight(OliveHighlighters.mark_julia!, c, proj, cell, cm, c[:OliveCore].users[getname(c)].data["highlighters"]["julia"])
end

function do_inner_rpc_highlight(f::Function, c::AbstractConnection, proj::Project{<:Any}, cell::Cell{<:Any}, 
        cm::ComponentModifier, tm::Olive.Highlighter)
    windowname::String = proj.id
    curr = cm["cell$(cell.id)"]["text"]
    cursorpos = parse(Int64, cm["cell$(cell.id)"]["caret"])
    cell.source = curr
    if length(cell.source) == 0
        return
    end
    set_text!(tm, curr)
    f(tm)
    set_text!(cm, "cellhighlight$(cell.id)", string(tm))
    if cursorpos == 0
        curspos = 1
    end
    n = length(curr)
    set_text!(tm, cell.source[1:cursorpos])
    OliveHighlighters.mark_julia!(tm)
    first_half = string(tm)
    set_text!(tm, cell.source[cursorpos + 1:end])
    OliveHighlighters.mark_julia!(tm)
    second_half = string(tm)
    OliveHighlighters.clear!(tm)
    collabdata = get_collaborator_data(c, proj)
    ToolipsSession.call!(c, cm) do cm2::ComponentModifier
        hltxt = first_half * "<a style='color:$(collabdata[4]);'>▆</a>" * second_half
        set_text!(cm2, "cellhighlight$(cell.id)", hltxt)
        set_text!(cm2, "cell$(cell.id)", curr)
    end
end

function cell_highlight!(c::Connection, cm::ComponentModifier, cell::Cell{:markdown}, proj::Project{:rpc})
    if cm["cell$(cell.id)"]["contenteditable"] == "false"
        return
    end
    do_inner_rpc_highlight(OliveHighlighters.mark_markdown!, c, proj, cell, cm, c[:OliveCore].users[getname(c)].data["highlighters"]["markdown"])
end

function evaluate(c::Connection, cm::ComponentModifier, cell::Cell{:markdown},
    proj::Project{:rpc})
    active_cell = cm["cell$(cell.id)"]
    if active_cell["contenteditable"] == "false"
        return
    end
    activemd = active_cell["text"]
    newtmd = tmd("cell$(cell.id)tmd", activemd)
    ToolipsServables.interpolate!(newtmd, Olive.INTERPOLATORS ...)
    newtext = replace(newtmd[:text], "`" => "\\`", "\"" => "\\\"", "''" => "\\'")
    push!(cm.changes, "document.getElementById('cell$(cell.id)').innerHTML = `$newtext`;")
    cm["cell$(cell.id)"] = "contenteditable" => "false"
    on(c, cm, 100) do cm2::ComponentModifier
        set_children!(cm2, "cellhighlight$(cell.id)", Vector{AbstractComponent}())
        rpc!(c, cm2)
    end
end

function cell_highlight!(c::Connection, cm::ComponentModifier, cell::Cell{:tomlvalues}, proj::Project{:rpc})
    do_inner_rpc_highlight(OliveHighlighters.mark_toml!, c, proj, cell, cm, c[:OliveCore].users[getname(c)].data["highlighters"]["toml"])
end