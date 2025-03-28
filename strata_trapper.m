function strata_trapped = strata_trapper(grid, sub_rock, mask, params, options, enable_waitbar, num_par_workers)
arguments
    grid            (1,1) struct
    sub_rock        (1,:) struct
    mask            (:,1) logical
    params          (1,1) Params
    options         (1,1) Options = Options();
    enable_waitbar  (1,1) logical = false;
    num_par_workers (1,1) uint32  = Inf;
end

perm_upscaled = zeros(grid.cells.num, 3);

saturations = linspace(params.sw_resid,1,options.sat_num_points);

cap_pres_upscaled = nan(grid.cells.num,length(saturations));
krw = nan(grid.cells.num,3,length(saturations));
krg = nan(grid.cells.num,3,length(saturations));

cells_num = min(length(mask),grid.cells.num);
mask = mask(1:cells_num);

wb_queue = parallel.pool.DataQueue;
if enable_waitbar
    parforWaitbar(0,sum(mask));
    afterEach(wb_queue,@parforWaitbar);
end

DR = [grid.DX,grid.DY,grid.DZ];

parfor (cell_index = 1:cells_num, num_par_workers)
    if ~mask(cell_index)
        continue;
    end

    sub_porosity = sub_rock(cell_index).poro;
    sub_permeability = sub_rock(cell_index).perm;

    [perm_upscaled_cell, pc_upscaled, krw_cell, krg_cell] = upscale(...
        DR(cell_index,:), saturations, params, options, sub_porosity, sub_permeability);

    perm_upscaled(cell_index,:) = perm_upscaled_cell;
    cap_pres_upscaled(cell_index,:) = pc_upscaled;

    krw(cell_index,:,:) = krw_cell;
    krg(cell_index,:,:) = krg_cell;

    if enable_waitbar
        send(wb_queue,cell_index);
    end
end

krw(mask,:,saturations<=params.sw_resid) = 0;
krg(krg<0) = 0;
krg(mask,:,saturations>=1)=0;

strata_trapped = struct(...
    'permeability', perm_upscaled, ...
    'saturation', saturations,...
    'capillary_pressure', cap_pres_upscaled, ...
    'rel_perm_wat', krw, ...
    'rel_perm_gas', krg ...
    );

if enable_waitbar
    parforWaitbar(0,0,'ready');
end

end

function parforWaitbar(~,max_iterations,~)
persistent state wb final_state start_time last_reported_state last_reported_time

if nargin == 2
    state = 0;
    final_state = max_iterations;
    wb = waitbar(state,sprintf('%u cells to upscale', final_state),'Name','StrataTrapper');
    start_time = tic();

    last_reported_state = state;
    last_reported_time = 0;
    return;
end

if ~isvalid(wb)
    return;
end

if nargin == 3
    elapsed = duration(seconds(toc(start_time)),'Format','hh:mm:ss');
    message = sprintf('%u cells upscaled\n in %s',final_state,elapsed);
    waitbar(1,wb,message);
    return;
end

state = state + 1;
elapsed = toc(start_time);

time_to_report = (elapsed - last_reported_time) > 1;
state_to_report = (state - last_reported_state) > final_state * 0.01;

if ~(time_to_report || state_to_report)
    return;
end

last_reported_state = state;
last_reported_time = elapsed;

pace_integral = elapsed/state;
eta_estimate = (final_state - state) * pace_integral;
eta = duration(seconds(eta_estimate),'Format','hh:mm:ss');
elapsed_str = duration(seconds(elapsed),'Format','hh:mm:ss');
message = sprintf('%u/%u cells upscaled\n passed: %s | ETA: %s',state,final_state,elapsed_str,eta);
waitbar(state/final_state,wb,message);
end
