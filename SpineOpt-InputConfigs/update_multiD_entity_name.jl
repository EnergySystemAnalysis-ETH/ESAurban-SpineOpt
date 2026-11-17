# Identify (and rename) multi-dimensional entities whose name does not match the names of their elements,
# for all SpineOpt databases (*.sqlite) in the same directory as this script.
#
# The expected name follows the Spine default: element names joined by "__"
# (e.g. `unit__to_node` entity of (`u1`, `n1`) -> "u1__n1"; a 1-D multi-dimensional entity gets a trailing "__").
#
# Usage:
#   julia update_multiD_entity_name.jl              # report and rename
#   julia update_multiD_entity_name.jl --dry-run    # report only
# or run in the REPL ("Julia: Execute active file in REPL"); set `DRY_RUN` below to report only.

# set up working environment
cd(@__DIR__)
import Pkg; Pkg.activate(Base.current_project(pwd())) # activate the ESAurban-SpineOpt environment

using SpineInterface

const DRY_RUN = "--dry-run" in ARGS || false   # set to `true` to only report mismatches without renaming

"""
    find_misnamed_entities(db_url)

Return a vector of named tuples `(id, class, name, expected)` for every multi-dimensional entity
whose name differs from the name composed of its elements' (expected) names.
"""
function find_misnamed_entities(db_url)
    r = SpineInterface.run_request(db_url, "query", ("entity_sq", "entity_element_sq", "entity_class_sq"))
    entities = Dict(e["id"] => e for e in r["entity_sq"])
    class_names = Dict(c["id"] => c["name"] for c in r["entity_class_sq"])
    elements = Dict{Int,Vector{Tuple{Int,Int}}}()  # entity_id => [(position, element_id), ...]
    for ee in r["entity_element_sq"]
        push!(get!(elements, ee["entity_id"], Tuple{Int,Int}[]), (ee["position"], ee["element_id"]))
    end
    # expected name, resolved recursively so that nested multi-D elements use their own corrected names
    expected = Dict{Int,String}()
    function expected_name(id)
        haskey(expected, id) && return expected[id]
        els = get(elements, id, nothing)
        expected[id] = if els === nothing
            entities[id]["name"]  # 0-D (object) entity: name is authoritative
        else
            el_names = [expected_name(el_id) for (_, el_id) in sort(els)]
            length(el_names) == 1 ? el_names[1] * "__" : join(el_names, "__")
        end
    end
    misnamed = [
        (id=id, class=class_names[entities[id]["class_id"]], name=entities[id]["name"], expected=expected_name(id))
        for id in keys(elements) if entities[id]["name"] != expected_name(id)
    ]
    sort!(misnamed; by=x -> (x.class, x.name))
    return misnamed, entities
end

"""
    rename_entities!(db_url, misnamed, entities)

Rename the given entities to their expected names and commit. Entities whose expected name is already
taken by another entity of the same class (that is not itself being renamed) are skipped.
Returns the renamed subset.
"""
function rename_entities!(db_url, misnamed, entities)
    renamed_ids = Set(x.id for x in misnamed)
    taken = Set((e["class_id"], e["name"]) for (id, e) in entities if !(id in renamed_ids))
    to_rename = filter(misnamed) do x
        clash = (entities[x.id]["class_id"], x.expected) in taken
        clash && @warn "Skipped: expected name already used by another entity in class `$(x.class)`" x.name x.expected
        !clash
    end
    isempty(to_rename) && return to_rename
    # if a target name is currently held by another entity being renamed (e.g. a swap), go via temporary names
    current = Set((entities[x.id]["class_id"], x.name) for x in to_rename)
    needs_tmp = any((entities[x.id]["class_id"], x.expected) in current for x in to_rename)
    SpineInterface.open_connection(db_url)
    try
        if needs_tmp
            _update_names(db_url, [Dict("id" => x.id, "name" => "$(x.name)__tmp_rename_$(x.id)") for x in to_rename])
        end
        _update_names(db_url, [Dict("id" => x.id, "name" => x.expected) for x in to_rename])
        res = SpineInterface.run_request(db_url, "call_method", ("commit_session", "Rename multi-D entities after their elements"))
        res isa AbstractDict && haskey(res, "error") && error("commit failed: $(res["error"])")
    finally
        SpineInterface.close_connection(db_url)
    end
    return to_rename
end

function _update_names(db_url, items)
    res = SpineInterface.run_request(db_url, "call_method", ("update_items", "entity", items...), Dict("check" => true))
    res isa AbstractDict && haskey(res, "error") && error("update failed: $(res["error"])")
    errors = filter(!isnothing, res[2])
    isempty(errors) || error("update failed: $(join(errors, "; "))")
end

for db_path in filter(f -> endswith(f, ".sqlite"), readdir(pwd()))   # no join=true
    db_url = "sqlite:///$db_path"                                    # relative to pwd()
    misnamed, entities = find_misnamed_entities(db_url)
    if isempty(misnamed)
        @info "$(db_path): all multi-D entity names consistent"
        continue
    end
    report = join(["  [$(x.class)] $(x.name)  =>  $(x.expected)" for x in misnamed], "\n")
    @info "$(db_path): $(length(misnamed)) multi-D entity name(s) inconsistent with their elements\n$report"
    DRY_RUN && continue
    renamed = rename_entities!(db_url, misnamed, entities)
    @info "$(db_path): renamed $(length(renamed)) of $(length(misnamed)) entities"
end
