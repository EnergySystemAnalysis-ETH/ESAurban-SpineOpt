using SpineInterface, JSON

function import_json!(db_url::String, json_path::String)
    json_input_data = JSON.parsefile(json_path, use_mmap=false)
    SpineInterface.close_connection(db_url)
    SpineInterface.open_connection(db_url)
    SpineInterface.import_data(db_url, json_input_data, "Data from $file_name.json")
end