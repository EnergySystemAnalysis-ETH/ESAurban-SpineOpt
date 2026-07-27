# Create a SpineOpt input DB with only the template.

# set up working environment
cd(dirname(@__FILE__))
using Pkg; Pkg.activate(Base.current_project(pwd())) # activate the ESAurban-SpineOpt environment

using SpineInterface
using SpineOpt

# initialise the SpineOpt database

## whether to overwrite the existing database
overwrite = false
db_name = "InputSpineOpt"

## determine the database path
db_path = overwrite ? 
    joinpath(pwd(), "$(db_name).sqlite") : 
    joinpath(pwd(), "$(db_name)_new.sqlite")

## remove the existing database if overwrite is true
overwrite && rm(db_path; force=true)

## construct the database URL
db_url = "sqlite:///$db_path"

## import the template data into the database
import_data(db_url, SpineOpt.template(), "Add SpineOpt template")

# access entities in the database and 

## access the data as convenient functions
SpineInterface.using_spinedb(db_url)
## (optional) export the data in the database to a dictionary
# SpineInterface.export_data(db_url)

# add data (entities, and parameter values) to the database as needed