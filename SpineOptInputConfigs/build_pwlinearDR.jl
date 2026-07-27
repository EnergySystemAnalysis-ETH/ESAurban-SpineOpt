# Build demand response profile for a given a SpineOpt input DB.

"""
# To run this script in julia REPL under the ESAurban-SpineOpt directory:
julia> include("./SpineOptInputConfigs/build_pwlinearDR.jl")

# To check the added data after the script execution: 
julia> using_spinedb(db_url)
"""

using Pkg; Pkg.activate(Base.current_project(pwd())) # activate the ESAurban-SpineOpt environment

using SpineInterface
using Dates

begin_time = now()

# initialize database
db_name = "Extra-DemandElastic"
db_path = joinpath(dirname(pwd()), "database\\$db_name.sqlite")

db_url = "sqlite:///$db_path"

SpineInterface.using_spinedb(db_url)
SpineInterface.export_data(db_url)

ratio_DRup = ratio_DRdown = 0.3
DRdown_ref_price = 0.1      # kCHF/MWh
DRup_ref_price = -0.02      # kCHF/MWh
pwl_DR_segment_points = [0.5, 0.8, 1.0] # starting point 0 is given by default
pwl_DRdown_prices = [1.0, 1.2, 1.8]
pwl_DRup_prices = [1.0, 0.6, 0.5]

ref_price_node_name = "DR_ref_price"
DR_alternative = "ElasticDemand30"

# prepare
DR_node_unit = map(n -> (
        string(n.name), 
        string(n.name)[1:length("Electricity")]
        * "DR"
        * string(n.name)[length("Electricity_"):end]
    ), 
    # filter(n -> occursin("Electricity", string(n.name)), node())
    filter(n -> !ismissing(demand(node=n, _default=missing)), node())
)

# basic pwl DR setup
DR_entities_obj = [
    ["node", ref_price_node_name],
    map(n_u -> ["unit", n_u[2]], DR_node_unit)...
]
DR_ref_price_node_obj_val = [
    ["node", ref_price_node_name, "balance_type", "balance_type_none", DR_alternative]
]
DR_entities_obj_alt = [
    map(item -> [item..., DR_alternative, true], DR_entities_obj)...,
    map(item -> [item..., "Basic", false], DR_entities_obj)...,
]
DR_pwl_entities_rel = map(item -> 
    ["unit__node__node", [item[2], ref_price_node_name, item[1]]], 
    DR_node_unit
)

data_pwl_DR = Dict(
    :alternatives => [DR_alternative, "Basic"],
    :objects => DR_entities_obj,
    :object_parameter_values => DR_ref_price_node_obj_val,
    :entity_alternatives => DR_entities_obj_alt,
    :relationships => DR_pwl_entities_rel,
)
import_data(db_url, data_pwl_DR, "Basic pwl DR setup"; upgrade=true)


# Setup for downward DR
DRdown_entities_rel = [
    map(n_u -> ["unit__from_node", [n_u[2], "DR_ref_price"]], DR_node_unit)...,
    map(n_u -> ["unit__to_node", [n_u[2], n_u[1]]], DR_node_unit)...,
]
DRdown_capacity_rel_val = map(rel ->
    [
        rel..., "unit_capacity", 
        unparse_db_value(ratio_DRdown * demand(node=node(rel[2][2]))), 
        DR_alternative
    ],
    filter(rel -> occursin("to_node", rel[1]), DRdown_entities_rel)
)
DRdown_ref_price_rel_val = map(rel ->
    [
        rel..., "vom_cost", 
        DRdown_ref_price, 
        DR_alternative
    ],
    filter(rel -> occursin("from_node", rel[1]), DRdown_entities_rel)
)
_pwl_DR_segment_points = Dict(
    "type" => "array",
    "value_type" => "float",
    "data" => pwl_DR_segment_points
)
_pwl_DRdown_prices = Dict(
    "type" => "array",
    "value_type" => "float",
    "data" => pwl_DRdown_prices
)
DRdown_pwl_rel_val = [
    map(rel ->
        [rel..., "operating_points", _pwl_DR_segment_points, DR_alternative],
        filter(rel -> occursin("to_node", rel[1]), DRdown_entities_rel)
    )...,
    map(rel -> 
        [rel..., "fix_ratio_in_out_unit_flow", _pwl_DRdown_prices, DR_alternative], 
        DR_pwl_entities_rel
    )...,
]

data_DRdown_str = Dict(
    :relationships => DRdown_entities_rel,
)
data_DRdown_vals = Dict(
    :relationship_parameter_values => vcat(DRdown_capacity_rel_val, DRdown_ref_price_rel_val, DRdown_pwl_rel_val)
)
import_data(db_url, merge(data_DRdown_str, data_DRdown_vals), "Downward pwl DR setup"; upgrade=true)


# Setup for upward DR
DRup_entities_rel = [
    map(n_u -> ["unit__to_node", [n_u[2], "DR_ref_price"]], DR_node_unit)...,
    map(n_u -> ["unit__from_node", [n_u[2], n_u[1]]], DR_node_unit)...
]
DRup_capacity_rel_val = map(rel ->
    [
        rel..., "unit_capacity", 
        unparse_db_value(ratio_DRup * demand(node=node(rel[2][2]))), 
        DR_alternative
    ],
    filter(rel -> occursin("from_node", rel[1]), DRup_entities_rel)
)
DRup_ref_price_rel_val = map(rel ->
    [
        rel..., "vom_cost", 
        DRup_ref_price, 
        DR_alternative
    ],
    filter(rel -> occursin("to_node", rel[1]), DRup_entities_rel)
)
_pwl_DR_segment_points = Dict(
    "type" => "array",
    "value_type" => "float",
    "data" => pwl_DR_segment_points
)
_pwl_DRup_prices = Dict(
    "type" => "array",
    "value_type" => "float",
    "data" => pwl_DRup_prices
)
DRup_pwl_rel_val = [
    map(rel ->
        [rel..., "operating_points", _pwl_DR_segment_points, DR_alternative],
        filter(rel -> occursin("from_node", rel[1]), DRup_entities_rel)
    )...,
    map(rel -> 
        [rel..., "fix_ratio_out_in_unit_flow", _pwl_DRup_prices, DR_alternative], 
        DR_pwl_entities_rel
    )...,
]

data_DRup_str = Dict(
    :relationships => DRup_entities_rel,
)
data_DRup_vals = Dict(
    :relationship_parameter_values => vcat(DRup_capacity_rel_val, DRup_ref_price_rel_val, DRup_pwl_rel_val)
)
import_data(db_url, merge(data_DRup_str, data_DRup_vals), "Upward pwl DR setup"; upgrade=true)
    
elapsed_time = now() - begin_time
println("Elapsed time for building pwl DR: $elapsed_time")