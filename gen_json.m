%% Create gebco_subset.json for Plotly / Google Sites

clear
clc

file = '..\gebco_2025_n18.0_s9.0_w-122.0_e-113.0.nc';

% Lease boundary
lat_box = [11.08333 11.08333 9.89500 9.89500 11.08333];
lon_box = [-117.816670 -116.066667 -116.066667 -117.816670 -117.816670];

% Buffer around lease area
buffer = 0.2;

latlim = [9.89500 11.08333] + [-buffer buffer];
lonlim = [-117.816670 -116.066667] + [-buffer buffer];

% Read GEBCO data
lat = ncread(file, 'lat');
lon = ncread(file, 'lon');
z   = double(ncread(file, 'elevation'));

% Replace fill value
z(z == -32767) = NaN;

% Subset indices
ilat = lat >= latlim(1) & lat <= latlim(2);
ilon = lon >= lonlim(1) & lon <= lonlim(2);

lat_sub = lat(ilat);
lon_sub = lon(ilon);

% GEBCO elevation is usually ordered as elevation(lon, lat)
z_sub = z(ilon, ilat);

% Convert to Plotly shape: z must be lat x lon
Z_plot = z_sub';

% Optional downsampling for web performance
step = 3;   % increase to 5 or 10 if JSON is too large

lat_out = lat_sub(1:step:end);
lon_out = lon_sub(1:step:end);
z_out   = Z_plot(1:step:end, 1:step:end);

% Replace NaN with null-compatible values for JSON
z_cell = num2cell(z_out);
for i = 1:size(z_out, 1)
    for j = 1:size(z_out, 2)
        if isnan(z_out(i,j))
            z_cell{i,j} = [];
        end
    end
end

% Build structure
gebco.lon = lon_out(:)';
gebco.lat = lat_out(:)';
gebco.z = z_cell;

gebco.lease_lon = lon_box;
gebco.lease_lat = lat_box;
gebco.latlim = latlim;
gebco.lonlim = lonlim;

% Encode and write JSON
jsonText = jsonencode(gebco);

fid = fopen('gebco_subset.json', 'w');
fprintf(fid, '%s', jsonText);
fclose(fid);

disp('Created gebco_subset.json')
disp(['Number of longitude points: ', num2str(numel(lon_out))])
disp(['Number of latitude points: ', num2str(numel(lat_out))])
disp(['Z size: ', num2str(size(z_out,1)), ' x ', num2str(size(z_out,2))])