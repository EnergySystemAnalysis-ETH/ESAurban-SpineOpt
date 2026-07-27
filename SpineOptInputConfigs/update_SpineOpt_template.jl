# Update all SpineOpt databases in the same directory of the folder

# set up working environment
cd(dirname(@__FILE__))
using Pkg; Pkg.activate(Base.current_project(pwd())) # activate the ESAurban-SpineOpt environment

using SpineInterface
using SpineOpt

for db_path in filter(f -> endswith(f, ".sqlite"), readdir(pwd(); join=true))
    db_url = "sqlite:///$db_path"
    SpineInterface.import_data(db_url, SpineOpt.template(), "Update SpineOpt template")
    @info "SpineOpt template updated for database: $(basename(db_path))"
end
