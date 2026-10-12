# Update all SpineOpt databases w/o `output` entities in the same directory of the folder

# set up working environment
cd(@__DIR__)
import Pkg; Pkg.activate(Base.current_project(pwd())) # activate the ESAurban-SpineOpt environment

using SpineInterface
using SpineOpt

for db_path in filter(f -> endswith(f, ".sqlite"), readdir(pwd()))   # no join=true
    db_url = "sqlite:///$db_path"                                    # relative to pwd()
    original_template = SpineOpt.template()
    filtered_template = filter(p -> p.first != "objects" && p.first != "object_parameter_values", original_template)
    filtered_template["objects"] = filter(obj -> !("output" in obj), original_template["objects"])
    filtered_template["object_parameter_values"] = filter(obj -> !("output" in obj), original_template["object_parameter_values"])
    SpineInterface.import_data(db_url, filtered_template, "Update SpineOpt template")
    @info "SpineOpt template updated for database: $(basename(db_path))"
end
