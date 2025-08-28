function build(c::AbstractConnection, dir::Directory{:rpc})
    env = c[:OliveCore].users[getname(c)].environment
    collab_proj = findfirst(p -> typeof(p) == Project{:collab}, env.projects)
    dirid, diruri = if ~(contains(dir.uri, "!;"))
        dirid = Toolips.gen_ref(5)
        diruri = dir.uri
        dir.uri = dirid * "!;" * dir.uri
        (dirid, diruri)
    else
        splts = split(dir.uri, "!;")
        (splts[1], splts[2])
    end
    newcells = Olive.directory_cells(diruri, wdtype = :rpcselector)
    childs = Vector{Servable}([begin
        build_rpc_filecell(c, mcell, dir)
    end for mcell in newcells])
    selectionbox = div("selbox$dirid", children = childs, ex = "0")
    style!(selectionbox, "height" => 0percent, "overflow" => "hidden", "opacity" => 0percent)
    lblbox = div("main$dirid", children = [a(text = diruri, style = "color:#ffc494;")])
    style!(lblbox, "cursor" => "pointer")
    dirbox = div("seldir$dirid", children = [lblbox, selectionbox])
    on(c, lblbox, "click") do cm::ComponentModifier
        selboxn = "selbox$dirid"
        if cm[selboxn]["ex"] == "0"
            style!(cm, selboxn, "height" => "auto", "opacity" => 100percent)
            cm[selboxn] = "ex" => "1"
            return
        end
        style!(cm, selboxn, "height" => 0percent, "opacity" => 0percent)
        cm[selboxn] = "ex" => "0"
    end
    style!(dirbox, "background-color" => "#752835", "overflow" => "hidden", "border-radius" => 0px)
    dirbox::Component{:div}
end

function build(c::Connection, cell::Cell{:rpcselector}, d::Directory{<:Any}, bind::Bool = true)
    filecell::Component{<:Any} = Olive.build_base_cell(c, cell, d, binding = false)
    filecell[:children] = Vector{AbstractComponent}([filecell[:children]["cell$(cell.id)label"]])
    style!(filecell, "background-color" => "#221440")
    on(c, filecell, "click") do cm::ComponentModifier
        path = cell.outputs * "/" * cell.source
        newcells = Olive.directory_cells(path, wdtype = :rpcselector)
        dir = Directory(path)
        childs = Vector{Servable}([begin
            build_rpc_filecell(c, mcell, dir)
        end for mcell in newcells])
        dirid = split(d.uri, "!;")[1]
        returner = Olive.build_any_returner(build_readonly_filecell, c, path, "selbox$dirid", d.uri, :roselector)
        set_children!(cm, "selbox$dirid", [returner, childs ...])
    end
    filecell::Component{<:Any}
end


function build_rpc_filecell(c::AbstractConnection, cell::Cell{<:Any}, dir::Directory{<:Any})
    maincell = Olive.build_selector_cell(c, cell, dir, false)
    on(c, maincell, "dblclick") do cm::ComponentModifier
        cells = Olive.olive_read(cell)
        oluser_name = getname(c)
        projdata::Dict{Symbol, Any} = Dict{Symbol, Any}(:cells => cells,
            :path => cell.outputs, :pane => "one", :host => oluser_name)
        newproj = Project{:rpc}(cell.source, projdata)
        env = c[:OliveCore].users[oluser_name].environment
        # TODO loop clients, add new projects to their environment...
        #   build hidden tabs INDIVIDUALLY (unfortunately).
        host_event = ToolipsSession.find_host(c)
        for client in host_event.clients
            
            tempdata = Dict{Symbol, Any}(:Session => session, :OliveCore => c[:OliveCore], :SESSIONKEY => client)
            newcon = Connection(c.stream, tempdata, Vector{Toolips.Route}(), get_ip(c))
            client_tab = build_tab(newcon, newproj, hidden = true)
            append!(cm, "pane_one_tabs", client_tab)
            call!(c, cm, client)
        end
        Olive.olive_notify!(cm, "$(getname(c)) added $(newproj.name) to the session")
        call!(c, cm)
        push!(env.projects, newproj)
        tab::Component{:div} = build_tab(c, newproj, hidden = true)
        append!(cm, "pane_one_tabs", tab)
        on(cm, 100) do cl::Components.ClientModifier
            trigger!(cl, "tab" * newproj.id)
        end
    end
    maincell
end
