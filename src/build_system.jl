"""
build_system(
    category::Type{<:SystemCategory},
    name::String,
    print_stat::Bool = false;
    kwargs...,
)

Accepted Key Words:
- `add_forecasts::Bool`: Default is `true`
- `add_reserves::Bool`: Default is `false`
- `force_build::Bool`: `true` runs entire build process, `false` (Default) uses deserializiation if possible
- `skip_serialization::Bool`: Default is `false`
- `system_catelog::SystemCatalog`
- `assign_new_uuids::Bool`: Assign new UUIDs to the system and all components if
   deserialization is used. Default is `true`.
"""
function build_system(
    category::Type{<:SystemCategory},
    name::String,
    print_stat::Bool = false;
    assign_new_uuids = true,
    kwargs...,
)
    add_forecasts = get(kwargs, :add_forecasts, true)
    add_reserves = get(kwargs, :add_reserves, false)
    force_build = get(kwargs, :force_build, false)
    skip_serialization = get(kwargs, :skip_serialization, false)
    system_catelog = get(kwargs, :system_catelog, SystemCatalog(SYSTEM_CATELOG))
    sys_descriptor = get_system_descriptor(category, system_catelog, name)
    if !is_serialized(name, add_forecasts, add_reserves) || force_build
        check_serialized_storage()
        download_function = get_download_function(sys_descriptor)
        if !isnothing(download_function)
            filepath = download_function(; kwargs...)
            set_raw_data!(sys_descriptor, filepath)
        end
        @info "Building new system $(sys_descriptor.name) from raw data" sys_descriptor.raw_data
        build_func = get_build_function(sys_descriptor)
        start = time()
        sys = build_func(; raw_data = sys_descriptor.raw_data, kwargs...)
        construct_time = time() - start
        serialized_filepath = get_serialized_filepath(name, add_forecasts, add_reserves)
        start = time()
        if !skip_serialization
            PSY.to_json(sys, serialized_filepath; force = true)
            serialize_time = time() - start
        end
        # set_stats!(sys_descriptor, SystemBuildStats(construct_time, serialize_time))
    else
        @debug "Deserialize system from file" sys_descriptor.name
        start = time()
        # time_series_in_memory = get(kwargs, :time_series_in_memory, false)
        sys_kwargs = filter_kwargs(; kwargs...)
        file_path = get_serialized_filepath(name, add_forecasts, add_reserves)
        sys = PSY.System(file_path; assign_new_uuids = assign_new_uuids, sys_kwargs...)
        @show PSY.get_runchecks(sys)
        # update_stats!(sys_descriptor, time() - start)
    end
    # print_stat ? print_stats(sys_descriptor) : nothing
    return sys
end
