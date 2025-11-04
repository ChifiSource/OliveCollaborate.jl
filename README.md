<div align="center"><img width="250" src="https://github.com/ChifiSource/image_dump/raw/main/olive/0.1/extensions/olivecollaborate.png">
</img></div>

- **collaborative sessions for olive!**
- [documentation](https://chifidocs.com/olive/OliveCollaborate.jl)
`OliveCollaborate` provides *multi-user RPC sessions* for `Olive` notebooks. This functionality gives users connected to the same server the ability to share their sessions actively -- as one user modifies the project, the project updates for everyone else viewing the project. This project is still in *relatively early* development, but is coming surprisingly soon!
##### notes
- This extension will only allow you to share with other users via LAN or your own networking.
- You can remove the `collaborate` icon  by adding `collabicon = false` to your `OliveCore`. The user addition system is slightly mutable, as we can change how users are added by creating our user-addition own cell type and path to adding the collaborate project. More information in [adding users](#adding-users).
- Cell compatibility *is* limited, but this is *mainly* just the case for highlighting and filling. Highlight bindings have to be specifically tailored for RPC -- this project only binds the 'CORE' `Olive` cells -- `:code`, `:tomlvalues`, and `:markdown`. This could easily be expanded with extensions.
##### adding
`OliveCollaborate` is added like any other `Olive` extension. In order to load the extension, either add `using OliveCollaborate` to your `olive.jl` or call `using OliveCollaborate` *before* starting `Olive`. Make sure the package is in your `olive` or global environment, as well, by adding it:
```julia
using Pkg; Pkg.add("OliveCollaborate")
```
##### configuration
The `GLOBAL_TICKRATE` 
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
        Cell("collab", " ","$(getname(c))|no|all|#e75480")])
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
