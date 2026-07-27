#=
modelling script under SpineOpt framework:
- Author: nnhjy
- Date: 2026-07-27
=#

# set up working environment
cd(dirname(@__FILE__))
using Pkg; Pkg.activate(Base.current_project(pwd())) # activate the ESAurban-SpineOpt environment

using JuMP, JSON
using SpineOpt
using SpineInterface

include(joinpath(dirname(Base.current_project()), "util", "spineopt_import_json.jl"))

# determine these parameters before running the script
overwrite = false
json_path = nothing

filter_dict = Dict("tool" => "object_activity_control")

input_db_name = "InputSpineOpt"
scenario_name = nothing

input_db_path = joinpath(pwd(), "$input_db_name.sqlite")
overwrite && rm(input_db_path; force=true)

# db address is relative to the working directory set when this script is run, not relative to the script location.
input_db_url = "sqlite:///$input_db_path"
output_db_url = "sqlite:///$(joinpath(dirname(Base.current_project()), "OutputDB\\Tutorial\\OutputDB.sqlite"))"

!isnothing(json_path) && import_json!(input_db_url, json_path)

# to check what is added in the `input_db`
SpineInterface.using_spinedb(input_db_url)
# # e.g. check the scenarios in the `input_db`
# scenarios = [scenario_item[1] for scenario_item in SpineInterface.export_data(input_db_url)["scenarios"]]

# check the settings in the DB
!isnothing(scenario_name) && (filter_dict["scenario"] = scenario_name)

# run SpineOpt with the input DB and output DB
m = run_spineopt(
    input_db_url, output_db_url; 
    upgrade=false,
    optimize=false,
    filters=filter_dict,
    alternative=scenario_name,
    log_level=3
)

# check the results in the `output_db` under a separate module
const OUTPUT = Bind()
SpineInterface.using_spinedb(output_db_url, OUTPUT)
## export the output data into a dictionary
SpineInterface.export_data(output_db_url)
